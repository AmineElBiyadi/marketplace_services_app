import 'package:flutter/material.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../models/booking.dart';
import '../../models/chat_model.dart';
import '../chat/chat_screen.dart';
import '../../routes/routes.dart';
import '../../services/firestore_service.dart';


const _tabs = ["Pending", "Confirmed", "Completed", "Cancelled", "Refused"];
const _tabStatusMap = {
  "Pending": "EN_ATTENTE",
  "Confirmed": "ACCEPTEE",
  "Completed": "TERMINEE",
  "Cancelled": "ANNULEE",
  "Refused": "REFUSEE",
};

class BookingsScreen extends StatefulWidget {
  final String clientId;
  final bool showBackButton;
  const BookingsScreen({Key? key, required this.clientId, this.showBackButton = false}) : super(key: key);

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedTab = 0;
  List<String> _clientIds = [];
  bool _initializingIds = true;

  @override
  void initState() {
    super.initState();
    _initClientIds();
  }

  Future<void> _initClientIds() async {
    final List<String> ids = [widget.clientId];
    try {
      final data = await _firestoreService.getClientByUid(widget.clientId);
      final legacyId = data?['clientId'];
      if (legacyId != null && legacyId != widget.clientId) {
        ids.add(legacyId);
      }
    } catch (e) {
      debugPrint("Error fetching legacy clientId: $e");
    }
    if (mounted) {
      setState(() {
        _clientIds = ids;
        _initializingIds = false;
      });
    }
  }


  Color _statusColor(String status) {
    switch (status) {
      case "ACCEPTEE": return AppColors.primary;
      case "TERMINEE": return Colors.green;
      case "ANNULEE": return Colors.red;
      case "REFUSEE": return Colors.red.shade900;
      default: return const Color(0xFFF5C518); // EN_ATTENTE
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case "EN_ATTENTE": return const Color(0xFF7A5C00);
      case "ANNULEE": return Colors.red.shade700;
      case "REFUSEE": return Colors.red.shade100;
      default: return Colors.white;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case "EN_ATTENTE": return "Pending";
      case "ACCEPTEE": return "Confirmed";
      case "TERMINEE": return "Completed";
      case "ANNULEE": return "Cancelled";
      case "REFUSEE": return "Refused";
      default: return "Pending";
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Not defined";
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final month = months[date.month - 1];
    return "${month} ${date.day}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _generateAndSaveCode(InterventionModel intervention) async {
    final code = _generateRandomCode(5);
    await FirebaseFirestore.instance
        .collection('interventions')
        .doc(intervention.id)
        .update({'codeValidationExpert': code});
  }

  Future<void> _handleChatTap(InterventionModel intervention) async {
    final clientId = intervention.idClient;
    final expertId = intervention.idExpert;
    
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('idIntervention', isEqualTo: intervention.id)
        .limit(1)
        .get();
        
    DocumentSnapshot chatDoc;
    if (chatQuery.docs.isNotEmpty) {
      chatDoc = chatQuery.docs.first;
      
      // Auto-close check
      final bool shouldBeClosed = ['TERMINEE', 'ANNULEE', 'REFUSEE'].contains(intervention.statut);
      if (shouldBeClosed && chatDoc['estOuvert'] == true) {
        await chatDoc.reference.update({'estOuvert': false});
        chatDoc = await chatDoc.reference.get(); // Refresh doc
      }
    } else {
      final newChatRef = FirebaseFirestore.instance.collection('chats').doc();
      final data = {
        'idIntervention': intervention.id,
        'idClient': clientId,
        'idExpert': expertId,
        'estOuvert': true,
        'DateFin': null,
        'nbMessagesNonLus': 0,
        'clientSnapshot': intervention.clientSnapshot ?? {'nom': 'Client', 'photo': ''},
        'expertSnapshot': intervention.expertSnapshot ?? {'nom': 'Expert', 'photo': ''},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await newChatRef.set(data);
      chatDoc = await newChatRef.get();
    }
    
    if (mounted) {
      final chatModel = ChatModel.fromDoc(chatDoc);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chat: chatModel,
            currentUserRole: 'client',
          ),
        ),
      );
    }
  }

  Future<void> _showDetailsDialog(InterventionModel intervention) async {
    final dateDebut = intervention.dateDebutIntervention;
    final tacheSnap = intervention.tacheSnapshot ?? {};
    final taskName = tacheSnap['nom'] ?? 'Unspecified task';

    final adresseSnap = intervention.adresseSnapshot ?? {};
    final fullAddress = "${adresseSnap['Quartier'] ?? ''}, ${adresseSnap['Ville'] ?? ''}".trim().replaceAll(RegExp(r'^,\s*|\s*,\s*$'), '');
    final displayAddress = fullAddress.isEmpty ? "Address not specified" : fullAddress;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Booking Details",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.calendar_today, "Date", _formatDate(dateDebut)),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.handyman_outlined, "Task", taskName),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.location_on_outlined, "Address", displayAddress),
                if (intervention.codeValidationExpert != null && intervention.statut == 'ACCEPTEE') ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.pin_outlined, "Validation code", intervention.codeValidationExpert!),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, left: 32.0),
                    child: Text(
                      "Give this code to the expert at the end of the task.",
                      style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                if (intervention.statut == 'ANNULEE' && intervention.motifeAnnulation != null && intervention.motifeAnnulation!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.cancel_outlined, "Cancellation reason", intervention.motifeAnnulation!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCancelDialog(InterventionModel intervention) async {
    TextEditingController reasonController = TextEditingController();
    String? errorText;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Cancel Booking",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please provide a reason for cancellation.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Cancellation reason",
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final inputReason = reasonController.text.trim();
                          if (inputReason.isEmpty) {
                            setDialogState(() => errorText = "Reason is required");
                            return;
                          }
                          
                          try {
                            await FirebaseFirestore.instance.collection('interventions').doc(intervention.id).update({
                              'statut': 'ANNULEE',
                              'motifeAnnulation': inputReason,
                              'annulerPar': 'client',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            // Auto-close associated chat
                            try {
                              final chats = await FirebaseFirestore.instance.collection('chats').where('idIntervention', isEqualTo: intervention.id).get();
                              for (var doc in chats.docs) {
                                await doc.reference.update({'estOuvert': false});
                              }
                            } catch (_) {}

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Booking cancelled successfully.")),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => errorText = "Connection error");
                          }
                        },
                        child: const Text("Confirm Cancellation", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Back", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = _selectedTab == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Text(
                  _tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ));
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(InterventionModel intervention) {
    final status = intervention.statut;
    final isPending = status == 'EN_ATTENTE';
    final isConfirmed = status == 'ACCEPTEE';
    final isCompleted = status == 'TERMINEE';
    final isCancelled = status == 'ANNULEE';
    final isRefused = status == 'REFUSEE';
    final hasDetails = isConfirmed || isCompleted || isCancelled || isRefused;

    final expertSnap = intervention.expertSnapshot ?? {};
    final expertName = expertSnap['nom'] ?? 'Unknown Expert';
    final expertPhoto = expertSnap['photo'] ?? '';

    final tacheSnap = intervention.tacheSnapshot ?? {};
    final serviceName = tacheSnap['serviceNom'] ?? 'Unspecified Service';
    final taskName = tacheSnap['nom'] ?? 'Unspecified task';
    
    final adresseSnap = intervention.adresseSnapshot ?? {};
    final fullAddress = "${adresseSnap['Quartier'] ?? ''}, ${adresseSnap['Ville'] ?? ''}".trim().replaceAll(RegExp(r'^,\s*|\s*,\s*$'), '');
    final displayAddress = fullAddress.isEmpty ? "Address not specified" : fullAddress;

    final dateDebut = intervention.dateDebutIntervention;

    String avatarInitials = "E";
    if (expertName != null && expertName.isNotEmpty) {
      final parts = expertName.split(" ");
      if (parts.length > 1) {
        avatarInitials = "${parts[0][0]}${parts[1][0]}".toUpperCase();
      } else {
        avatarInitials = expertName.substring(0, 1).toUpperCase();
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    image: expertPhoto.isNotEmpty
                        ? DecorationImage(image: NetworkImage(expertPhoto), fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: expertPhoto.isEmpty
                      ? Text(
                          avatarInitials,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expertName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (isPending) ...[
                        Text(
                          serviceName,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.handyman_outlined, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(taskName, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(displayAddress, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                          ],
                        ),
                      ] else ...[
                        Text(
                          serviceName,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(dateDebut),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _handleChatTap(intervention),
                      child: Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(status == "EN_ATTENTE" ? 1.0 : 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatStatusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusTextColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: "Cancel",
                      icon: Icons.close,
                      color: Colors.red,
                      filled: false,
                      onTap: () => _showCancelDialog(intervention),
                    ),
                  ),
                ],
              ),
            ],
            if (hasDetails) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Booking Details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  GestureDetector(
                    onTap: () => context.push('/booking-detail/${intervention.id}'),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.remove_red_eye_outlined, size: 20, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
            if (isConfirmed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                   if (intervention.codeValidationExpert == null || intervention.codeValidationExpert!.isEmpty)
                      FutureBuilder(
                        future: _generateAndSaveCode(intervention),
                        builder: (context, _) => const SizedBox(),
                      ),
                  Expanded(
                    child: _buildActionButton(
                      label: "Cancel",
                      icon: Icons.close,
                      color: Colors.red,
                      filled: false,
                      onTap: () => _showCancelDialog(intervention),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: "Complain",
                      icon: Icons.report_problem_outlined,
                      color: Colors.orange,
                      filled: false,
                      onTap: () => context.push(AppRoutes.complaint.replaceFirst(':interventionId', intervention.id!)),
                    ),
                  ),
                ],
              ),
            ],
            if (isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: "Rate",
                      icon: Icons.star_border,
                      color: AppColors.primary,
                      filled: true,
                      onTap: () => context.push('/review/${intervention.id}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: "Complain",
                      icon: Icons.report_problem_outlined,
                      color: Colors.orange,
                      filled: false,
                      onTap: () => context.push(AppRoutes.complaint.replaceFirst(':interventionId', intervention.id!)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializingIds) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentStatus = _tabStatusMap[_tabs[_selectedTab]]!;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec gradient
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF818CF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                if (widget.showBackButton) ...
                  [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                  ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/logo.png',
                            height: 30,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(height: 30),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Presto — snap your fingers, we handle the rest.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'My Bookings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your appointments',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTabBar(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('interventions')
                  .where('idClient', whereIn: _clientIds)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                // Filter by status in memory for robustness
                List<InterventionModel> interventions = docs
                    .map((doc) => InterventionModel.fromFirestore(doc))
                    .where((i) => i.statut == currentStatus)
                    .toList();
                
                interventions.sort((a, b) {
                  final t1 = a.updatedAt;
                  final t2 = b.updatedAt;
                  if (t1 == null && t2 == null) return 0;
                  if (t1 == null) return 1;
                  if (t2 == null) return -1;
                  return t2.compareTo(t1);
                });

                if (interventions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          "No bookings",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Your bookings with status \"${_tabs[_selectedTab]}\" will appear here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: interventions.length,
                  itemBuilder: (_, i) => _buildCard(interventions[i]),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}
