import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/expert.dart';
import '../../models/chat_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/home/category_card.dart';
import '../../widgets/home/nearby_provider_card.dart';
import '../../widgets/home/top_rated_card.dart';
import 'expert_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../models/service.dart';
import '../../widgets/start_chat_sheet.dart';
import '../../widgets/notification_bell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();
  final LocationService _locationService = LocationService();

  List<Expert> _experts = [];
  List<Expert> _filteredExperts = [];
  bool _isLoading = true;
  String _clientNom = '';
  String? _selectedCategory;
  List<String> _villesExperts = [];
  String? _selectedVille;

  /// Position GPS de l'utilisateur (null si permission refusée)
  Position? _userPosition;

  List<Map<String, dynamic>> _categories = [];

  // Map of category names to their assets/icons (for hardcoded ones)
  final Map<String, Map<String, dynamic>> _categoryAssets = {
    'Plomberie': {'icon': Icons.plumbing, 'image': 'assets/categories/plumbing.png'},
    'Électricité': {'icon': Icons.electrical_services, 'image': 'assets/categories/electricity.png'},
    'Nettoyage': {'icon': Icons.cleaning_services, 'image': 'assets/categories/cleaning.png'},
    'Jardinage': {'icon': Icons.yard, 'image': 'assets/categories/gardening.png'},
    'Coiffure': {'icon': Icons.content_cut, 'image': 'assets/categories/hair.png'},
  };

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

    // 3. Liste des experts, des villes et des services
    final experts = await _firestoreService.getExperts();
    final villes = await _firestoreService.getVillesExperts();
    final serviceModels = await _firestoreService.getServices();

    if (mounted) {
      setState(() {
        _experts = experts;
        _villesExperts = villes;
        
        // Map Firestore services to UI format
        _categories = serviceModels.map((s) {
          final label = s.nom;
          // Check if we have hardcoded assets for this service name
          final assets = _categoryAssets[label] ?? _categoryAssets.values.firstWhere(
            (val) => label.toLowerCase().contains(val['image'].toString().split('/').last.split('.').first),
            orElse: () => {'icon': Icons.business_center, 'image': s.image},
          );
          
          return {
            'label': label,
            'icon': assets['icon'] ?? Icons.business_center,
            'image': s.image ?? assets['image'],
          };
        }).toList();

        _isLoading = false;
      });
      _applyFilters();
    }
  }

  // ── Filtre par catégorie ────────────────────
  void _applyFilters() {
    setState(() {
      _filteredExperts = _experts.where((e) {
        if (_selectedCategory != null && !e.services.any((s) => s.toLowerCase().contains(_selectedCategory!.toLowerCase()))) {
          return false;
        }
        if (_selectedVille != null && _selectedVille!.isNotEmpty) {
          if (!e.ville.toLowerCase().contains(_selectedVille!.toLowerCase())) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  void _selectCategory(String label) {
    setState(() {
      _selectedCategory = _selectedCategory == label ? null : label;
    });
    _applyFilters();
  }

  /// Opens (or creates) a chat with the given expert and navigates to ChatScreen
  Future<void> _openChat(Expert expert) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour chater')),
      );
      return;
    }

    await StartChatSheet.show(context, expert: expert);
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
  
  // Afficher le dropdown des villes
  void _showVilleDropdown(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _villesExperts.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucune ville disponible'),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _villesExperts.length,
                    itemBuilder: (context, index) {
                      final ville = _villesExperts[index];
                      final isSelected = _selectedVille == ville;
                      return ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: isSelected
                              ? const Color(0xFF3D5A99)
                              : Colors.grey,
                          size: 18,
                        ),
                        title: Text(
                          ville,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF3D5A99)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        tileColor: isSelected
                            ? const Color(0xFF3D5A99).withValues(alpha: 0.1)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          setState(() => _selectedVille = ville);
                          _applyFilters();
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    'assets/logo.png',
                                    height: 40,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox(height: 40),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Presto — snap your fingers, we handle the rest.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
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
                        Row(
                          children: [
                            NotificationBell(
                              idUtilisateur: FirebaseAuth.instance.currentUser?.uid ?? '',
                              role: 'Client',
                              color: Colors.white,
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white),
                              tooltip: 'Se déconnecter',
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.clear();
                                await FirebaseAuth.instance.signOut();
                                if (context.mounted) {
                                  context.go('/login');
                                }
                              },
                            ),
                          ],
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
                                'Our Services',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 20),
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
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
                                onPressed: () => _showVilleDropdown(context),
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
                                                builder: (_) => ExpertProfileScreen(
                                                  expert: expert,
                                                  preSelectedService: _selectedCategory, 
                                              ),
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
                                        onChat: () => _openChat(expert),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ExpertProfileScreen(
                                                expert: expert,
                                                preSelectedService: _selectedCategory,
                                            ),
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