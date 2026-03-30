import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expert.dart';
import '../models/chat_model.dart';
import '../services/intervention_service.dart';
import '../screens/chat/chat_screen.dart';

// ─── Color constants ────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF3D5A99);
const _kBg      = Color(0xFFF9F8FE);

/// Multi-step bottom sheet that guides the client through:
///   0. Checking for an existing open chat
///   1. Service selection          (skipped if [preSelectedService] is given)
///   2. Task selection
///   3. Address selection / creation
///   → Creates Intervention (EN_ATTENTE) + Chat → opens ChatScreen
class StartChatSheet extends StatefulWidget {
  final Expert expert;
  final String clientId;          // Firebase Auth UID
  final String? preSelectedService; // service name — skips step 1 when set
  final String? preSelectedTask;    // task name — skips step 2 when set

  const StartChatSheet._({
    required this.expert,
    required this.clientId,
    this.preSelectedService,
    this.preSelectedTask,
  });

  /// Entry point — call this from any widget.
  static Future<void> show(
    BuildContext context, {
    required Expert expert,
    String? preSelectedService,
    String? preSelectedTask,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StartChatSheet._(
        expert: expert,
        clientId: uid,
        preSelectedService: preSelectedService,
        preSelectedTask: preSelectedTask,
      ),
    );
  }

  @override
  State<StartChatSheet> createState() => _StartChatSheetState();
}

// ─── Steps enum ─────────────────────────────────────────────────────────────
enum _Step { loading, existingChat, selectService, selectTask, selectAddress, creating }

class _StartChatSheetState extends State<StartChatSheet> {
  final InterventionService _svc = InterventionService();

  _Step _step = _Step.loading;

  // Existing-chat data
  List<ChatModel> _allOpenChats = [];
  List<ChatModel> _existingChats = [];

  // Selection state
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _tasks    = [];
  List<Map<String, dynamic>> _addresses = [];

  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedTask;

  // Add-address form
  bool _showAddressForm = false;
  final _rueCtrl        = TextEditingController();
  final _numCtrl        = TextEditingController();
  final _quartierCtrl   = TextEditingController();
  final _villeCtrl      = TextEditingController();
  final _cpCtrl         = TextEditingController();
  final _paysCtrl       = TextEditingController(text: 'Morocco');
  String? _addressFormError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _rueCtrl.dispose(); _numCtrl.dispose(); _quartierCtrl.dispose();
    _villeCtrl.dispose(); _cpCtrl.dispose(); _paysCtrl.dispose();
    super.dispose();
  }

  // ─── Init / flow logic ───────────────────────────────────────────────────

  Future<void> _init() async {
    // Step 0: check existing open chats
    final openChats = await _svc.checkOpenChat(widget.clientId, widget.expert.id);

    if (!mounted) return;
    
    _allOpenChats = openChats;

    if (openChats.isNotEmpty) {
      List<ChatModel> filtered = openChats;
      
      if (widget.preSelectedService != null) {
         filtered = openChats.where((c) {
           if (c.tacheSnapshot == null) return false;
           final sName = c.tacheSnapshot!['serviceNom']?.toString().toLowerCase();
           final tName = c.tacheSnapshot!['nom']?.toString().toLowerCase();
           
           if (widget.preSelectedTask != null) {
             return sName == widget.preSelectedService!.toLowerCase() && tName == widget.preSelectedTask!.toLowerCase();
           } else {
             return sName == widget.preSelectedService!.toLowerCase();
           }
         }).toList();
      }

      if (filtered.isNotEmpty) {
        setState(() { _existingChats = filtered; _step = _Step.existingChat; });
        return;
      }
    }

    // No existing chat — go to service selection (or skip if pre-selected)
    if (widget.preSelectedService != null) {
      await _loadServicesAndSkipSteps(widget.preSelectedService!, widget.preSelectedTask);
    } else {
      await _loadServices();
    }
  }

  Future<void> _loadServices() async {
    final services = await _svc.getExpertServices(widget.expert.id);
    if (!mounted) return;
    setState(() { _services = services; _step = _Step.selectService; });
  }

  Future<void> _loadServicesAndSkipSteps(String serviceName, String? taskName) async {
    final services = await _svc.getExpertServices(widget.expert.id);
    if (!mounted) return;

    // Find the service whose name matches the pre-selected one
    final match = services.firstWhere(
      (s) => (s['nom'] as String).toLowerCase() == serviceName.toLowerCase(),
      orElse: () => services.isNotEmpty ? services.first : <String, dynamic>{},
    );

    if (match.isEmpty) {
      setState(() { _services = services; _step = _Step.selectService; });
      return;
    }

    setState(() {
      _services = services;
      _selectedService = match;
      _step = _Step.loading;
    });
    
    final tasks = await _svc.getExpertTasksForService(widget.expert.id, match['id'] as String);
    if (!mounted) return;

    if (taskName != null && taskName.isNotEmpty) {
      final taskMatch = tasks.firstWhere(
        (t) => (t['nom'] as String).toLowerCase() == taskName.toLowerCase(),
        orElse: () => tasks.isNotEmpty ? tasks.first : <String, dynamic>{},
      );
      if (taskMatch.isNotEmpty) {
        setState(() {
          _tasks = tasks;
          _selectedTask = taskMatch;
        });
        await _onTaskSelected(taskMatch);
        return;
      }
    }

    setState(() { _tasks = tasks; _step = _Step.selectTask; });
  }

  Future<void> _onServiceSelected(Map<String, dynamic> service) async {
    setState(() { _selectedService = service; _step = _Step.loading; });
    final tasks = await _svc.getExpertTasksForService(widget.expert.id, service['id'] as String);
    if (!mounted) return;
    setState(() { _tasks = tasks; _step = _Step.selectTask; });
  }

  Future<void> _onTaskSelected(Map<String, dynamic> task) async {
    // Check if an existing open chat matches this specific service & task
    try {
      final existingMatch = _allOpenChats.firstWhere((c) =>
          c.tacheSnapshot != null &&
          c.tacheSnapshot!['serviceNom']?.toString().toLowerCase() == _selectedService!['nom'].toString().toLowerCase() &&
          c.tacheSnapshot!['nom']?.toString().toLowerCase() == task['nom'].toString().toLowerCase());
          
      // We found a match! Show the existing chat panel for this specific chat
      setState(() {
        _existingChats = [existingMatch];
        _step = _Step.existingChat;
      });
      return;
    } catch (_) {
      // No match, continue normally
    }

    setState(() { _selectedTask = task; _step = _Step.loading; });
    final addresses = await _svc.getClientAddresses(widget.clientId);
    if (!mounted) return;
    setState(() { _addresses = addresses; _step = _Step.selectAddress; });
  }

  Future<void> _onAddressConfirmed(Map<String, dynamic> address, String addressId) async {
    setState(() { _step = _Step.creating; });

    try {
      final clientSnap = await _svc.getClientSnapshot(widget.clientId);

      final result = await _svc.createInterventionAndChat(
        clientId:       widget.clientId,
        expertId:       widget.expert.id,
        idTacheExpert:  _selectedTask!['id'] as String,
        idAdresse:      addressId,
        serviceNom:     _selectedService!['nom'] as String,
        taskNom:        _selectedTask!['nom'] as String,
        clientSnapshot: clientSnap,
        expertSnapshot: {'nom': widget.expert.nom, 'photo': widget.expert.photo},
        adresseSnapshot: {
          'Rue':        address['Rue'],
          'NumBatiment':address['NumBatiment'],
          'Quartier':   address['Quartier'],
          'Ville':      address['Ville'],
          'CodePostal': address['CodePostal'],
          'Pays':       address['Pays'],
        },
      );

      final chatId = result['chatId']!;
      final interventionId = result['interventionId']!;

      // Fetch the fresh ChatModel
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!mounted) return;

      Navigator.pop(context); // close sheet

      final now  = Timestamp.now();
      final chat = chatDoc.exists
          ? ChatModel.fromDoc(chatDoc)
          : ChatModel(
              chatId:           chatId,
              idClient:         widget.clientId,
              idExpert:         widget.expert.id,
              idIntervention:   interventionId,
              estOuvert:        true,
              unreadCountClient: 0,
              unreadCountExpert: 0,
              createdAt:        now,
              updatedAt:        now,
              clientSnapshot:   UserSnapshot(nom: clientSnap['nom'] ?? 'Client', photo: clientSnap['photo'] ?? ''),
              expertSnapshot:   UserSnapshot(nom: widget.expert.nom,  photo: widget.expert.photo),
            );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chat: chat, currentUserRole: 'client'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _step = _Step.selectAddress);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveNewAddress() async {
    final rue      = _rueCtrl.text.trim();
    final num      = _numCtrl.text.trim();
    final quartier = _quartierCtrl.text.trim();
    final ville    = _villeCtrl.text.trim();
    final cp       = _cpCtrl.text.trim();
    final pays     = _paysCtrl.text.trim();

    if (rue.isEmpty || ville.isEmpty) {
      setState(() => _addressFormError = 'Street and City are required.');
      return;
    }

    setState(() { _addressFormError = null; _step = _Step.creating; });

    try {
      final newId = await _svc.createAddress(
        clientUserId: widget.clientId,
        rue:          rue,
        numBatiment:  num,
        quartier:     quartier,
        ville:        ville,
        codePostal:   cp,
        pays:         pays,
      );
      await _onAddressConfirmed({
        'Rue': rue, 'NumBatiment': num, 'Quartier': quartier,
        'Ville': ville, 'CodePostal': cp, 'Pays': pays,
      }, newId);
    } catch (e) {
      if (!mounted) return;
      setState(() { _step = _Step.selectAddress; _addressFormError = 'Error during saving.'; });
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            _buildHeader(),
            const Divider(height: 1),
            // Body
            Expanded(child: _buildBody(scrollCtrl)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = {
      _Step.loading:       'Loading...',
      _Step.creating:      'Creating...',
      _Step.existingChat:  'Active Chat',
      _Step.selectService: 'Choose a service',
      _Step.selectTask:    'Choose a task',
      _Step.selectAddress: 'Choose an address',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          // Back button (not on loading/creating/initial)
          if (_step == _Step.selectTask || _step == _Step.selectAddress)
            GestureDetector(
              onTap: () {
                if (_step == _Step.selectTask) {
                  setState(() { _step = _Step.selectService; });
                } else if (_step == _Step.selectAddress) {
                  setState(() { _step = _Step.selectTask; });
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: _kPrimary),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_step] ?? '',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kPrimary),
                ),
                Text(
                  widget.expert.nom,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Progress dots
          _StepDots(currentStep: _step),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController scrollCtrl) {
    switch (_step) {
      case _Step.loading:
      case _Step.creating:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: _kPrimary),
              const SizedBox(height: 16),
              Text(
                _step == _Step.creating ? 'Creating your request...' : 'Checking...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );

      case _Step.existingChat:
        if (_existingChats.length == 1) { // Removed preSelectedTask constraint so it kicks in during _onTaskSelected too!
          return _ExistingChatPanel(
            chat: _existingChats.first,
            expertName: widget.expert.nom,
            title: 'You already have an active chat for this task',
            onContinue: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(chat: _existingChats.first, currentUserRole: 'client'),
                ),
              );
            },
            onNewChat: () async {
              setState(() { _existingChats = []; });
              if (widget.preSelectedService != null) {
                await _loadServicesAndSkipSteps(widget.preSelectedService!, widget.preSelectedTask);
              } else {
                await _loadServices();
              }
            },
          );
        } else {
          return _ExistingChatsListPanel(
            chats: _existingChats,
            expertName: widget.expert.nom,
            onSelect: (chat) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(chat: chat, currentUserRole: 'client'),
                ),
              );
            },
            onNewChat: () async {
              setState(() { _existingChats = []; });
              if (widget.preSelectedService != null) {
                await _loadServicesAndSkipSteps(widget.preSelectedService!, widget.preSelectedTask);
              } else {
                await _loadServices();
              }
            },
          );
        }

      case _Step.selectService:
        return _ServiceList(
          services: _services,
          scrollCtrl: scrollCtrl,
          onSelect: _onServiceSelected,
        );

      case _Step.selectTask:
        return _TaskList(
          tasks: _tasks,
          scrollCtrl: scrollCtrl,
          onSelect: _onTaskSelected,
        );

      case _Step.selectAddress:
        return _AddressList(
          addresses: _addresses,
          scrollCtrl: scrollCtrl,
          showForm: _showAddressForm,
          formError: _addressFormError,
          rueCtrl: _rueCtrl,
          numCtrl: _numCtrl,
          quartierCtrl: _quartierCtrl,
          villeCtrl: _villeCtrl,
          cpCtrl: _cpCtrl,
          paysCtrl: _paysCtrl,
          onSelectExisting: (addr) =>
              _onAddressConfirmed(addr, addr['id'] as String),
          onToggleForm: () => setState(() {
            _showAddressForm = !_showAddressForm;
            _addressFormError = null;
          }),
          onSaveNew: _saveNewAddress,
        );
    }
  }
}

// ─── Progress dots ───────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final _Step currentStep;
  const _StepDots({required this.currentStep});

  int get _index {
    switch (currentStep) {
      case _Step.selectService: return 0;
      case _Step.selectTask:    return 1;
      case _Step.selectAddress: return 2;
      default:                  return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_index < 0) return const SizedBox.shrink();
    return Row(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(left: 4),
        width: i == _index ? 16 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: i == _index ? _kPrimary : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(3),
        ),
      )),
    );
  }
}

// ─── Existing chat panel ──────────────────────────────────────────────────────

class _ExistingChatPanel extends StatelessWidget {
  final ChatModel chat;
  final String expertName;
  final String? title;
  final VoidCallback onContinue;
  final VoidCallback onNewChat;

  const _ExistingChatPanel({
    required this.chat,
    required this.expertName,
    this.title,
    required this.onContinue,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kPrimary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: _kPrimary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? 'You already have an open chat',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _kPrimary, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'with $expertName',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 18),
              label: const Text('Continue this chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNewChat,
              icon: const Icon(Icons.add_comment_outlined, color: _kPrimary, size: 18),
              label: const Text('New chat', style: TextStyle(color: _kPrimary, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingChatsListPanel extends StatelessWidget {
  final List<ChatModel> chats;
  final String expertName;
  final ValueChanged<ChatModel> onSelect;
  final VoidCallback onNewChat;

  const _ExistingChatsListPanel({
    required this.chats,
    required this.expertName,
    required this.onSelect,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have ${chats.length} active chats with this expert',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _kPrimary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200, // Limit list height slightly
            child: ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final c = chats[index];
                final serviceNom = c.tacheSnapshot?['serviceNom'] ?? 'Generic service';
                final taskNom = c.tacheSnapshot?['nom'] ?? 'Discussion';
                return _SelectionCard(
                  icon: Icons.chat,
                  title: '$serviceNom - $taskNom',
                  subtitle: c.dernierMessage?.contenu ?? 'New chat...',
                  onTap: () => onSelect(c),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNewChat,
              icon: const Icon(Icons.add_comment_outlined, color: _kPrimary, size: 18),
              label: const Text('Start a new chat (Other service)', style: TextStyle(color: _kPrimary, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Service list ─────────────────────────────────────────────────────────────

class _ServiceList extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final ScrollController scrollCtrl;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _ServiceList({required this.services, required this.scrollCtrl, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Text('No services available.', style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = services[i];
        return _SelectionCard(
          icon: Icons.build_circle_outlined,
          title: s['nom'] as String,
          subtitle: s['description'] as String? ?? '',
          onTap: () => onSelect(s),
        );
      },
    );
  }
}

// ─── Task list ────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final ScrollController scrollCtrl;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _TaskList({required this.tasks, required this.scrollCtrl, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Text('No tasks available for this service.', style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final t = tasks[i];
        return _SelectionCard(
          icon: Icons.task_alt_outlined,
          title: t['nom'] as String,
          subtitle: t['description'] as String? ?? '',
          onTap: () => onSelect(t),
        );
      },
    );
  }
}

// ─── Address list + form ──────────────────────────────────────────────────────

class _AddressList extends StatelessWidget {
  final List<Map<String, dynamic>> addresses;
  final ScrollController scrollCtrl;
  final bool showForm;
  final String? formError;
  final TextEditingController rueCtrl, numCtrl, quartierCtrl, villeCtrl, cpCtrl, paysCtrl;
  final ValueChanged<Map<String, dynamic>> onSelectExisting;
  final VoidCallback onToggleForm;
  final VoidCallback onSaveNew;

  const _AddressList({
    required this.addresses,
    required this.scrollCtrl,
    required this.showForm,
    required this.formError,
    required this.rueCtrl,
    required this.numCtrl,
    required this.quartierCtrl,
    required this.villeCtrl,
    required this.cpCtrl,
    required this.paysCtrl,
    required this.onSelectExisting,
    required this.onToggleForm,
    required this.onSaveNew,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Existing addresses
        if (addresses.isNotEmpty) ...addresses.map((addr) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SelectionCard(
            icon: Icons.location_on_outlined,
            title: InterventionService.formatAddress(addr),
            subtitle: '${addr['Ville']} — ${addr['CodePostal']}',
            onTap: () => onSelectExisting(addr),
          ),
        )),

        // Button to toggle form
        GestureDetector(
          onTap: onToggleForm,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: showForm ? _kPrimary : Colors.grey.shade300,
                width: showForm ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(showForm ? Icons.expand_less : Icons.add_location_alt_outlined,
                    color: _kPrimary),
                const SizedBox(width: 12),
                Text(
                  showForm ? 'Hide form' : '+ Add a new address',
                  style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),

        // Address form
        if (showForm) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _FormRow(controllers: [rueCtrl], labels: ['Street']),
                const SizedBox(height: 10),
                _FormRow(controllers: [numCtrl, quartierCtrl], labels: ['Building No.', 'Neighborhood']),
                const SizedBox(height: 10),
                _FormRow(controllers: [villeCtrl, cpCtrl], labels: ['City', 'Postal Code']),
                const SizedBox(height: 10),
                _FormRow(controllers: [paysCtrl], labels: ['Country']),
                if (formError != null) ...[
                  const SizedBox(height: 8),
                  Text(formError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSaveNew,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Confirm and create chat',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Inline row of 1 or 2 form fields.
class _FormRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<String> labels;
  const _FormRow({required this.controllers, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(controllers.length, (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
          child: TextField(
            controller: controllers[i],
            decoration: InputDecoration(
              labelText: labels[i],
              labelStyle: const TextStyle(fontSize: 13, color: _kPrimary),
              filled: true,
              fillColor: _kBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kPrimary),
              ),
            ),
          ),
        ),
      )),
    );
  }
}

// ─── Generic selection card ───────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SelectionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _kPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kPrimary),
          ],
        ),
      ),
    );
  }
}
