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
import 'expert_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    {'label': 'Plomberie', 'icon': Icons.plumbing, 'image': 'assets/categories/plumbing.png'},
    {'label': 'Électricité', 'icon': Icons.electrical_services, 'image': 'assets/categories/electricity.png'},
    {'label': 'Nettoyage', 'icon': Icons.cleaning_services, 'image': 'assets/categories/cleaning.png'},
    {'label': 'Jardinage', 'icon': Icons.yard, 'image': 'assets/categories/gardening.png'},
    {'label': 'Coiffure', 'icon': Icons.content_cut, 'image': 'assets/categories/hair.png'},
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final customId = prefs.getString('logged_client_id');
      final authUser = FirebaseAuth.instance.currentUser;
      
      // Focus on the customId first because the app uses custom Firestore-based auth
      final searchUid = customId ?? authUser?.uid;
      
      debugPrint('Fetching name for searchUid: $searchUid (customId: $customId, authUser: ${authUser?.uid})');

      if (searchUid != null) {
        // Try direct fetch by ID first (works if customId is the doc ID)
        final userDoc = await FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(searchUid)
            .get();
        
        if (userDoc.exists && userDoc.data()?['nom'] != null) {
          if (mounted) setState(() => _clientNom = userDoc.data()!['nom']);
        } else {
          // Fallback: search by current auth user details if they exist
          if (authUser != null) {
            if (authUser.email != null) {
              final qEmail = await FirebaseFirestore.instance
                  .collection('utilisateurs')
                  .where('email', isEqualTo: authUser.email)
                  .limit(1)
                  .get();
              if (qEmail.docs.isNotEmpty) {
                 if (mounted) setState(() => _clientNom = qEmail.docs.first.data()['nom'] ?? '');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
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
    // Tri "Nearby"
    final nearby = List<Expert>.from(_filteredExperts)
      ..sort((a, b) {
        final da = _distanceTo(a);
        final db = _distanceTo(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    // Top Rated
    final topRated = List<Expert>.from(_filteredExperts)
      ..sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── HEADER ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 60), // Restored large padding
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A69B1),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi ${_clientNom.isNotEmpty ? _clientNom : 'Client'},',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'What service are you looking for?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Categories Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Popular',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 20),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = _selectedCategory == cat['label'];
                              return CategoryCard(
                                label: cat['label'],
                                icon: cat['icon'],
                                imagePath: cat['image'],
                                isSelected: isSelected,
                                onTap: () => _selectCategory(cat['label']),
                              );
                            },
                          ),
                        ),
                        
                        // Scroll Indicator Placeholder
                        Center(
                          child: Container(
                            width: 120,
                            height: 4,
                            margin: const EdgeInsets.only(top: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A69B1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Nearby Providers
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Nearby Providers',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Row(
                                  children: [
                                    Text('Map ', style: TextStyle(color: Color(0xFF4A69B1), fontWeight: FontWeight.bold)),
                                    Icon(Icons.chevron_right, size: 18, color: Color(0xFF4A69B1)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A69B1)))
                            : nearby.isEmpty
                                ? const Center(child: Padding(
                                    padding: EdgeInsets.all(40.0),
                                    child: Text('Aucun prestataire trouvé'),
                                  ))
                                : SizedBox(
                                    height: 240,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      scrollDirection: Axis.horizontal,
                                      itemCount: nearby.length,
                                      itemBuilder: (context, index) {
                                        final expert = nearby[index];
                                        final dist = _distanceTo(expert);
                                        return NearbyProviderCard(
                                          name: expert.nom,
                                          service: expert.services.isNotEmpty ? expert.services.first : '',
                                          rating: expert.noteMoyenne,
                                          distance: dist ?? 0.0,
                                          imageUrl: expert.photo,
                                          isPremium: expert.isPremium,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ExpertProfileScreen(expert: expert),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                        const SizedBox(height: 32),

                        // Top Rated
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Text(
                            'Top Rated',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A69B1)))
                            : topRated.isEmpty
                                ? const Center(child: Padding(
                                    padding: EdgeInsets.all(40.0),
                                    child: Text('Aucun prestataire trouvé'),
                                  ))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: topRated.length,
                                    itemBuilder: (context, index) {
                                      final expert = topRated[index];
                                      return TopRatedCard(
                                        name: expert.nom,
                                        services: expert.services.join(', '),
                                        rating: expert.noteMoyenne,
                                        imageUrl: expert.photo,
                                        isPremium: expert.isPremium,
                                        onChat: () {},
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ExpertProfileScreen(expert: expert),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}