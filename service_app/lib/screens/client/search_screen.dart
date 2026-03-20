import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/expert.dart';
import '../../models/chat_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/smart_image.dart';
import '../../widgets/start_chat_sheet.dart';
import 'expert_details_screen.dart';
import '../chat/chat_screen.dart';

// ─── Couleurs ──────────────────────────────────────────────────
const Color _kBg        = Color(0xFFF5F3EC);   // beige maquette
const Color _kBlue      = Color(0xFF3D5A99);   // bleu principal
const Color _kAvailable = Color(0xFF27AE60);   // vert "Available"
const Color _kGold      = Color(0xFFFFC107);   // étoile

// ─── Sort options ──────────────────────────────────────────────
enum _Sort { relevance, topRated, nearest }

// ══════════════════════════════════════════════════════════════
//  SEARCH SCREEN
// ══════════════════════════════════════════════════════════════
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FirestoreService  _firestoreService  = FirestoreService();
  final LocationService   _locationService   = LocationService();
  final ChatService       _chatService       = ChatService();
  final TextEditingController _searchCtrl    = TextEditingController();

  List<Expert> _all        = [];
  List<Expert> _filtered   = [];
  bool         _isLoading  = true;
  _Sort        _sort       = _Sort.relevance;
  Position?    _userPos;
  String?      _activeServiceFilter;

  // ── Filtre avancé (bottom sheet) ──
  bool   _showFilterBanner = true;
  double _minNote          = 0.0;
  String? _selectedVille;
  List<String> _villes     = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Chargement ──────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    // Position GPS
    final pos = await _locationService.getCurrentPosition();
    if (mounted) setState(() => _userPos = pos);

    // Experts + villes
    final experts = await _firestoreService.getExperts();
    final villes  = await _firestoreService.getVillesExperts();

    if (mounted) {
      setState(() {
        _all    = experts;
        _villes = villes;
        _isLoading = false;
      });
      _apply();
    }
  }

  // ── Filtrage + tri ───────────────────────────────────────────
  void _apply() {
    final q = _searchCtrl.text.toLowerCase().trim();

    List<Expert> res = _all.where((e) {
      if (e.noteMoyenne < _minNote) return false;
      if (_selectedVille != null &&
          !e.ville.toLowerCase().contains(_selectedVille!.toLowerCase())) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.nom.toLowerCase().contains(q) ||
          e.services.any((s) => s.toLowerCase().contains(q));
    }).toList();

    switch (_sort) {
      case _Sort.topRated:
        res.sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
        break;
      case _Sort.nearest:
        res.sort((a, b) {
          final da = _dist(a);
          final db = _dist(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
        break;
      case _Sort.relevance:
        // Premium d'abord, puis par note
        final premium = res.where((e) => e.isPremium).toList()
          ..sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
        final others = res.where((e) => !e.isPremium).toList()
          ..sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
        res = [...premium, ...others];
        break;
    }

    String? determinedService;
    if (q.isNotEmpty) {
      final matches = _all.expand((e) => e.services).where((s) => s.toLowerCase().contains(q)).toSet().toList();
      if (matches.length == 1) determinedService = matches.first;
    }

    setState(() { 
      _filtered = res;
      _activeServiceFilter = determinedService;
    });
  }

  double? _dist(Expert e) {
    if (_userPos == null || e.location == null) return null;
    return _locationService.distanceFromGeoPoint(
      userPosition: _userPos,
      expertGeoPoint: e.location,
    );
  }

  // ── Ouvrir chat ─────────────────────────────────────────────
  Future<void> _openChat(Expert expert) async {
    await StartChatSheet.show(
      context,
      expert: expert,
      preSelectedService: _activeServiceFilter,
    );
  }

  // ── Filter bottom sheet ─────────────────────────────────────
  void _showFilterSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        minNote:       _minNote,
        selectedVille: _selectedVille,
        villes:        _villes,
      ),
    );
    if (result != null) {
      setState(() {
        _minNote       = result['minNote'] ?? 0.0;
        _selectedVille = result['ville'];
      });
      _apply();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 32,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(height: 32),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Presto — snap your fingers, we handle the rest.',
                      style: TextStyle(
                        color: _kBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Barre de recherche
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(Icons.search,
                              color: Colors.grey.shade400, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => _apply(),
                              decoration: InputDecoration(
                                hintText: 'Search services...',
                                hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _apply();
                              },
                              child: Icon(Icons.close,
                                  color: Colors.grey.shade400, size: 18),
                            ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Bouton filtre
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _kBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Sort chips : Relevance / Top Rated / Nearest ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _SortChip(
                    label: 'Relevance',
                    active: _sort == _Sort.relevance,
                    onTap: () {
                      setState(() => _sort = _Sort.relevance);
                      _apply();
                    },
                  ),
                  const SizedBox(width: 8),
                  _SortChip(
                    label: 'Top Rated',
                    active: _sort == _Sort.topRated,
                    onTap: () {
                      setState(() => _sort = _Sort.topRated);
                      _apply();
                    },
                  ),
                  const SizedBox(width: 8),
                  _SortChip(
                    label: 'Nearest',
                    active: _sort == _Sort.nearest,
                    onTap: () {
                      setState(() => _sort = _Sort.nearest);
                      _apply();
                    },
                  ),
                  const Spacer(),
                  // Icône carte
                  Icon(Icons.map_outlined, color: Colors.grey.shade500, size: 22),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Bannière filtre (dismissible) ────────────────
            if (_showFilterBanner)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Category, Rating, Location and Availability filters coming soon',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showFilterBanner = false),
                        child: Icon(Icons.close,
                            size: 18, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // ── Liste ────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: _kBlue))
                  : _filtered.isEmpty
                      ? _EmptyState(query: _searchCtrl.text)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              16, 4, 16, 24),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 2),
                          itemBuilder: (ctx, i) {
                            final expert = _filtered[i];
                            final dist   = _dist(expert);
                            return _ExpertTile(
                              expert:   expert,
                              distance: dist,
                              onTap: () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => ExpertProfileScreen(
                                      expert: expert),
                                ),
                              ),
                              onChat: () => _openChat(expert),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SORT CHIP
// ══════════════════════════════════════════════════════════════
class _SortChip extends StatelessWidget {
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _kBlue : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  EXPERT TILE  — design maquette
// ══════════════════════════════════════════════════════════════
class _ExpertTile extends StatelessWidget {
  final Expert    expert;
  final double?   distance;
  final VoidCallback onTap;
  final VoidCallback onChat;

  const _ExpertTile({
    required this.expert,
    required this.distance,
    required this.onTap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final service = expert.services.isNotEmpty ? expert.services.first : '';
    final distText = distance != null
        ? '${distance!.toStringAsFixed(1)} km'
        : '';
    final isAvailable = true; // TODO: relier à un champ Firestore "estDisponible"

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Avatar arrondi ──────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: SmartImage(
                source: expert.photo,
                width:  58,
                height: 58,
                fit:    BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),

            // ── Infos ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom + badge Available
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expert.nom,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kAvailable,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Available',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Service (bleu)
                  Text(
                    service,
                    style: TextStyle(
                      fontSize: 13,
                      color: _kBlue.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Note ★ + distance
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: _kGold, size: 15),
                      const SizedBox(width: 3),
                      Text(
                        expert.noteMoyenne.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      if (distText.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Text(
                          distText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Icône chat ──────────────────────────────────
            GestureDetector(
              onTap: onChat,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  EMPTY STATE
// ══════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            query.isEmpty
                ? 'Aucun prestataire trouvé'
                : 'Aucun résultat pour "$query"',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            'Essayez de modifier vos filtres',
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  FILTER BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class _FilterSheet extends StatefulWidget {
  final double  minNote;
  final String? selectedVille;
  final List<String> villes;

  const _FilterSheet({
    required this.minNote,
    required this.selectedVille,
    required this.villes,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late double  _minNote;
  late String? _ville;

  @override
  void initState() {
    super.initState();
    _minNote = widget.minNote;
    _ville   = widget.selectedVille;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Filters & Sort',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 24),

            // Note minimale
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      const Text('Note minimale',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_minNote.toStringAsFixed(1)} ★',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.amber,
                      thumbColor: Colors.amber,
                      inactiveTrackColor: Colors.amber.shade100,
                    ),
                    child: Slider(
                      value: _minNote,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      onChanged: (v) => setState(() => _minNote = v),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Ville
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Ville',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _VilleChip(
                    label: 'Toutes',
                    active: _ville == null,
                    onTap: () => setState(() => _ville = null),
                  ),
                  ...widget.villes.map((v) => _VilleChip(
                        label: v,
                        active: _ville == v,
                        onTap: () => setState(() => _ville = v),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Boutons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() {
                            _minNote = 0;
                            _ville   = null;
                          }),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kBlue),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Réinitialiser',
                          style: TextStyle(color: _kBlue)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                          context,
                          {'minNote': _minNote, 'ville': _ville}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Appliquer',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VilleChip extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;

  const _VilleChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}