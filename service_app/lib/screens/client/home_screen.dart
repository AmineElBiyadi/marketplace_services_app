import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/expert.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/home/category_card.dart';
import '../../widgets/home/nearby_provider_card.dart';
import '../../widgets/home/top_rated_card.dart';
import 'expert_datails_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();

  List<Expert> _experts = [];
  List<Expert> _filteredExperts = [];
  bool _isLoading = true;
  String _clientNom = '';
  String? _selectedCategory;

  /// Position GPS de l'utilisateur (null si permission refusée)
  Position? _userPosition;

  final List<Map<String, dynamic>> categories = [
    {'label': 'Plomberie', 'icon': Icons.plumbing},
    {'label': 'Électricité', 'icon': Icons.electrical_services},
    {'label': 'Nettoyage', 'icon': Icons.cleaning_services},
    {'label': 'Jardinage', 'icon': Icons.yard},
    {'label': 'Coiffure', 'icon': Icons.content_cut},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Chargement des données ──────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Nom du client connecté
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      setState(() {
        _clientNom =
            userDoc.data()?['nom'] ?? userDoc.data()?['email'] ?? '';
      });
    }

    // 2. Position GPS (optionnel — ne bloque pas le chargement)
    final position = await _locationService.getCurrentPosition();
    if (mounted) setState(() => _userPosition = position);

    // 3. Liste des experts
    final experts = await _firestoreService.getExperts();
    if (mounted) {
      setState(() {
        _experts = experts;
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  // ── Filtre par catégorie ────────────────────
  void _applyFilters() {
    setState(() {
      _filteredExperts = _experts.where((e) {
        if (_selectedCategory == null) return true;
        return e.services.any((s) =>
            s.toLowerCase().contains(_selectedCategory!.toLowerCase()));
      }).toList();
    });
  }

  void _selectCategory(String label) {
    setState(() {
      _selectedCategory = _selectedCategory == label ? null : label;
    });
    _applyFilters();
  }

  /// Calcule la distance entre l'utilisateur et un expert.
  /// Retourne null si la position n'est pas disponible ou si l'expert
  /// n'a pas de coordonnées.
  double? _distanceTo(Expert expert) {
    if (_userPosition == null) return null;
    if (expert.location == null) return null;
    return _locationService.distanceFromGeoPoint(
      userPosition: _userPosition,
      expertGeoPoint: expert.location,
    );
  }

  // ── Build ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Tri "Nearby" : experts avec distance connue d'abord
    final nearby = List<Expert>.from(_filteredExperts)
      ..sort((a, b) {
        final da = _distanceTo(a);
        final db = _distanceTo(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    // Top Rated : tri par note décroissante
    final topRated = List<Expert>.from(_filteredExperts)
      ..sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ══════════════════════════════════════
              //  HEADER BLEU
              // ══════════════════════════════════════
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF3D5A99),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Notification
                    Align(
                      alignment: Alignment.centerRight,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Salutation dynamique
                    _isLoading
                        ? const SizedBox(
                      height: 28,
                      width: 180,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        color: Colors.white54,
                      ),
                    )
                        : Text(
                      'Hi ${_clientNom.isNotEmpty ? _clientNom : 'Client'},',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'What service are you looking for?',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),

                    // Indicateur GPS discret
                    if (_userPosition != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.my_location,
                              color: Colors.white60, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Localisation activée',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── CATÉGORIES ──
                    const Text(
                      'Popular',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected =
                              _selectedCategory == cat['label'];
                          return CategoryCard(
                            label: cat['label'],
                            icon: cat['icon'],
                            isSelected: isSelected,
                            onTap: () => _selectCategory(cat['label']),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── NEARBY PROVIDERS ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nearby Providers',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Map >',
                              style:
                              TextStyle(color: Color(0xFF3D5A99))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _isLoading
                        ? const Center(
                        child: CircularProgressIndicator())
                        : nearby.isEmpty
                        ? const Center(
                        child:
                        Text('Aucun prestataire trouvé'))
                        : SizedBox(
                      height: 210,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: nearby.length,
                        itemBuilder: (context, index) {
                          final expert = nearby[index];
                          final dist = _distanceTo(expert);
                          return NearbyProviderCard(
                            name: expert.nom,
                            service:
                            expert.services.isNotEmpty
                                ? expert.services.first
                                : '',
                            rating: expert.noteMoyenne,
                            distance: dist ?? 0.0,
                            imageUrl: expert.photo,
                            isPremium: expert.isPremium,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExpertProfileScreen(expert: expert),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── TOP RATED ──
                    const Text(
                      'Top Rated',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    _isLoading
                        ? const Center(
                        child: CircularProgressIndicator())
                        : topRated.isEmpty
                        ? const Center(
                        child:
                        Text('Aucun prestataire trouvé'))
                        : ListView.builder(
                      shrinkWrap: true,
                      physics:
                      const NeverScrollableScrollPhysics(),
                      itemCount: topRated.length,
                      itemBuilder: (context, index) {
                        final expert = topRated[index];
                        return TopRatedCard(
                          name: expert.nom,
                          services:
                          expert.services.join(', '),
                          rating: expert.noteMoyenne,
                          imageUrl: expert.photo,
                          isPremium: expert.isPremium,
                          onChat: () {},
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ExpertProfileScreen(expert: expert),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}