import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/expert.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'expert_details_screen.dart';
import '../../widgets/smart_image.dart';

// ─────────────────────────────────────────────
//  CONSTANTES
// ─────────────────────────────────────────────
const Color _kPrimary   = Color(0xFF1A1F36);   // navy foncé
const Color _kAccent    = Color(0xFF4F6BED);   // bleu bouton filtre
const Color _kBg        = Color(0xFFF5F3EC);   // beige clair maquette
const Color _kGold      = Color(0xFFFFC107);   // premium
const Color _kAvailable = Color(0xFF2ECC71);   // badge vert

// ─────────────────────────────────────────────
//  MODÈLE DE FILTRE
// ─────────────────────────────────────────────
enum SortOption { pertinence, noteDec, nearest }

class _FilterState {
  String? ville;
  double minNote = 0.0;
  SortOption sort = SortOption.pertinence;
  bool premiumFirst = true;

  _FilterState copyWith({
    String? ville,
    double? minNote,
    SortOption? sort,
    bool? premiumFirst,
  }) =>
      _FilterState()
        ..ville = ville ?? this.ville
        ..minNote = minNote ?? this.minNote
        ..sort = sort ?? this.sort
        ..premiumFirst = premiumFirst ?? this.premiumFirst;

  bool get hasActiveFilters =>
      ville != null ||
          minNote > 0 ||
          sort != SortOption.pertinence;
}

// ─────────────────────────────────────────────
//  ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  List<Expert> _allExperts = [];
  List<Expert> _filteredExperts = [];
  List<String> _villesExperts = [];
  Position? _userPosition;
  bool _isLoading = true;
  _FilterState _filters = _FilterState();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Chargement initial ──────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snap = await FirebaseFirestore.instance
          .collection('adresses')
          .where('idUtilisateur', isEqualTo: user.uid)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final ville = (data['Ville'] ?? '').toString();
        if (ville.isNotEmpty) {
          setState(() => _filters.ville = ville);
        }
      }
    }

    final experts = await _firestoreService.getExperts();
    final villes = await _firestoreService.getVillesExperts();
    final position = await _locationService.getCurrentPosition();

    setState(() {
      _allExperts = experts;
      _villesExperts = villes;
      _userPosition = position;
      _isLoading = false;
    });

    _applyFilters();
  }

  // ── Filtrage + tri ──────────────────────────
  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    List<Expert> result = _allExperts.where((e) {
      if (_filters.ville != null &&
          !e.ville.toLowerCase().contains(_filters.ville!.toLowerCase())) {
        return false;
      }
      if (e.noteMoyenne < _filters.minNote) return false;
      if (query.isNotEmpty) {
        final matchNom = e.nom.toLowerCase().contains(query);
        final matchService =
        e.services.any((s) => s.toLowerCase().contains(query));
        if (!matchNom && !matchService) return false;
      }
      return true;
    }).toList();

    switch (_filters.sort) {
      case SortOption.noteDec:
        result.sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
        break;
      case SortOption.nearest:
        if (_userPosition != null) {
          result.sort((a, b) {
            final da = _locationService.distanceFromGeoPoint(
                userPosition: _userPosition, expertGeoPoint: a.location);
            final db = _locationService.distanceFromGeoPoint(
                userPosition: _userPosition, expertGeoPoint: b.location);
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        }
        break;
      case SortOption.pertinence:
        break;
    }

    if (_filters.premiumFirst) {
      final premium = result.where((e) => e.isPremium).toList();
      final others = result.where((e) => !e.isPremium).toList();
      result = [...premium, ...others];
    }

    setState(() => _filteredExperts = result);
  }

  // ── Bottom sheet filtres avancés ────────────
  void _showFilterSheet() async {
    final newFilters = await showModalBottomSheet<_FilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: _filters,
        villes: _villesExperts,
      ),
    );
    if (newFilters != null) {
      setState(() => _filters = newFilters);
      _applyFilters();
    }
  }

  // ── Bottom sheet sélection ville ────────────
  void _showVilleSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _VilleSheet(
        villes: _villesExperts,
        selected: _filters.ville,
        onSelect: (v) {
          setState(() => _filters.ville = v);
          _applyFilters();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final premiumCount = _filteredExperts.where((e) => e.isPremium).length;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [

            // ══════════════════════════════════════
            //  HEADER (fond beige, pas bleu)
            // ══════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barre de recherche
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
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
                              Icon(Icons.search,
                                  color: Colors.grey.shade400, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => _applyFilters(),
                                  decoration: InputDecoration(
                                    hintText: 'Search services...',
                                    hintStyle: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  style: const TextStyle(
                                      fontSize: 14, color: _kPrimary),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                  child: Icon(Icons.close,
                                      color: Colors.grey.shade400, size: 18),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Bouton filtre bleu
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _kAccent.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.tune_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Chips : Ville + Tri rapides
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _HeaderChip(
                          icon: Icons.location_on,
                          label: _filters.ville ?? 'Toutes les villes',
                          onTap: _showVilleSheet,
                          active: _filters.ville != null,
                        ),
                        const SizedBox(width: 8),
                        _HeaderChip(
                          icon: Icons.star,
                          label: 'Top Rated',
                          onTap: () {
                            setState(() => _filters.sort =
                            _filters.sort == SortOption.noteDec
                                ? SortOption.pertinence
                                : SortOption.noteDec);
                            _applyFilters();
                          },
                          active: _filters.sort == SortOption.noteDec,
                        ),
                        const SizedBox(width: 8),
                        _HeaderChip(
                          icon: Icons.near_me,
                          label: 'Nearest',
                          onTap: () {
                            setState(() => _filters.sort =
                            _filters.sort == SortOption.nearest
                                ? SortOption.pertinence
                                : SortOption.nearest);
                            _applyFilters();
                          },
                          active: _filters.sort == SortOption.nearest,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ══════════════════════════════════════
            //  BARRE INFO + RESET
            // ══════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _isLoading
                        ? const Text('Chargement…',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey))
                        : RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                        children: [
                          TextSpan(
                            text:
                            '${_filteredExperts.length} résultat(s)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (premiumCount > 0)
                            TextSpan(
                                text:
                                '  •  $premiumCount Premium 👑'),
                        ],
                      ),
                    ),
                  ),
                  if (_filters.hasActiveFilters || _filters.ville != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filters = _FilterState();
                          _searchController.clear();
                        });
                        _applyFilters();
                      },
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero),
                      child: const Text(
                        'Réinitialiser',
                        style:
                        TextStyle(color: _kPrimary, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),

            // ══════════════════════════════════════
            //  LISTE DES RÉSULTATS
            // ══════════════════════════════════════
            Expanded(
              child: _isLoading
                  ? const Center(
                  child:
                  CircularProgressIndicator(color: _kPrimary))
                  : _filteredExperts.isEmpty
                  ? _EmptyState()
                  : ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: _filteredExperts.length,
                itemBuilder: (context, index) {
                  final expert = _filteredExperts[index];
                  final showPremiumHeader = index == 0 &&
                      expert.isPremium &&
                      _filters.premiumFirst;
                  final showOthersHeader =
                      _filters.premiumFirst &&
                          !expert.isPremium &&
                          (index == 0 ||
                              _filteredExperts[index - 1]
                                  .isPremium);

                  return Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      if (showPremiumHeader)
                        _SectionLabel(
                          icon: Icons.workspace_premium,
                          label: 'Prestataires Premium',
                          color: _kGold,
                        ),
                      if (showOthersHeader)
                        _SectionLabel(
                          icon: Icons.people_outline,
                          label: 'Autres prestataires',
                          color: Colors.grey.shade600,
                        ),
                      _ExpertCard(
                        expert: expert,
                        searchQuery: _searchController.text,
                        userPosition: _userPosition,
                      ),
                      const SizedBox(height: 12),
                    ],
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

// ─────────────────────────────────────────────
//  Chip du header
// ─────────────────────────────────────────────
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _kAccent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: active ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Label de section Premium / Autres
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Carte expert
// ─────────────────────────────────────────────
class _ExpertCard extends StatelessWidget {
  final Expert expert;
  final String searchQuery;
  final Position? userPosition;

  const _ExpertCard({
    required this.expert,
    required this.searchQuery,
    this.userPosition,
  });

  static final LocationService _locationService = LocationService();

  @override
  Widget build(BuildContext context) {
    final isPremium = expert.isPremium;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExpertProfileScreen(expert: expert),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPremium
              ? Border.all(
              color: _kGold.withOpacity(0.6), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: isPremium
                  ? _kGold.withOpacity(0.15)
                  : Colors.grey.shade200,
              blurRadius: isPremium ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau Premium
            if (isPremium)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 5, horizontal: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                  ),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium,
                        size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'PRESTATAIRE PREMIUM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  SmartImage(
                    source: expert.photo,
                    width: 68,
                    height: 68,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(width: 12),

                  // Infos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expert.nom,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expert.services.join(' • '),
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Note
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius:
                                BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star,
                                      color: Colors.amber,
                                      size: 13),
                                  const SizedBox(width: 2),
                                  Text(
                                    expert.noteMoyenne
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.location_on,
                                size: 13,
                                color: Colors.grey.shade400),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                expert.ville,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (userPosition != null && expert.location != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.near_me, size: 12, color: _kAccent),
                              const SizedBox(width: 2),
                              Text(
                                '${_locationService.distanceFromGeoPoint(userPosition: userPosition, expertGeoPoint: expert.location)?.toStringAsFixed(1) ?? '??'} km',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _kAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (expert.prixMin != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'À partir de ${expert.prixMin!.toStringAsFixed(0)} MAD',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.grey.shade300, size: 22),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  État vide
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucun prestataire trouvé',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text('Essayez de modifier vos filtres',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Bottom Sheet : Sélection ville
// ─────────────────────────────────────────────
class _VilleSheet extends StatelessWidget {
  final List<String> villes;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _VilleSheet(
      {required this.villes,
        required this.selected,
        required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Choisir une ville',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _VilleTile(
                  label: 'Toutes les villes',
                  icon: Icons.public,
                  selected: selected == null,
                  onTap: () => onSelect(null),
                ),
                ...villes.map((v) => _VilleTile(
                  label: v,
                  icon: Icons.location_on,
                  selected: selected == v,
                  onTap: () => onSelect(v),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _VilleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VilleTile(
      {required this.label,
        required this.icon,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: selected ? _kPrimary : Colors.grey, size: 20),
      title: Text(label,
          style: TextStyle(
            color: selected ? _kPrimary : Colors.black87,
            fontWeight:
            selected ? FontWeight.bold : FontWeight.normal,
          )),
      trailing: selected
          ? const Icon(Icons.check, color: _kPrimary, size: 18)
          : null,
      tileColor:
      selected ? _kPrimary.withOpacity(0.06) : null,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────
//  Bottom Sheet : Filtres avancés
// ─────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final _FilterState current;
  final List<String> villes;

  const _FilterSheet(
      {required this.current, required this.villes});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current.copyWith();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Filtres & Tri',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 24),

            // ── Note minimale ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      const Text('Note minimale',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_local.minNote.toStringAsFixed(1)} ★',
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
                      overlayColor: Colors.amber.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _local.minNote,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      onChanged: (v) =>
                          setState(() => _local.minNote = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('0',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      Text('5',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // ── Tri ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Trier par',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SortChip(
                    label: 'Pertinence',
                    icon: Icons.auto_awesome,
                    selected:
                    _local.sort == SortOption.pertinence,
                    onTap: () => setState(
                            () => _local.sort = SortOption.pertinence),
                  ),
                  _SortChip(
                    label: 'Meilleure note',
                    icon: Icons.star,
                    selected: _local.sort == SortOption.noteDec,
                    onTap: () => setState(
                            () => _local.sort = SortOption.noteDec),
                  ),
                  _SortChip(
                    label: 'Le plus proche',
                    icon: Icons.near_me,
                    selected: _local.sort == SortOption.nearest,
                    onTap: () => setState(
                            () => _local.sort = SortOption.nearest),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // ── Premium en tête ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SwitchListTile(
                value: _local.premiumFirst,
                activeColor: _kGold,
                onChanged: (v) =>
                    setState(() => _local.premiumFirst = v),
                title: const Row(
                  children: [
                    Icon(Icons.workspace_premium,
                        color: _kGold, size: 18),
                    SizedBox(width: 8),
                    Text('Mettre Premium en avant',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
                subtitle: const Text(
                  'Les prestataires premium apparaissent en premier',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Boutons Réinitialiser / Appliquer ──
            Padding(
              padding:
              const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _local = _FilterState()),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kPrimary),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      child: const Text('Réinitialiser',
                          style: TextStyle(color: _kPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _local),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      child: const Text(
                        'Appliquer les filtres',
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

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip(
      {required this.label,
        required this.icon,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.white : Colors.grey),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                )),
          ],
        ),
      ),
    );
  }
}