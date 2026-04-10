import 'dart:ui';
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
import '../../widgets/shared/client_header.dart';

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
  final ScrollController _servicesScrollController = ScrollController();
  double _indicatorOffset = 0.0;
  final double _trackWidth = 120.0;
  final double _indicatorWidth = 40.0;

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
    _servicesScrollController.addListener(_updateIndicator);
  }

  @override
  void dispose() {
    _servicesScrollController.removeListener(_updateIndicator);
    _servicesScrollController.dispose();
    super.dispose();
  }

  void _updateIndicator() {
    if (_servicesScrollController.hasClients &&
        _servicesScrollController.position.maxScrollExtent > 0) {
      final maxScroll = _servicesScrollController.position.maxScrollExtent;
      final currentScroll = _servicesScrollController.offset;
      final scrollRatio = (currentScroll / maxScroll).clamp(0.0, 1.0);
      
      setState(() {
        _indicatorOffset = scrollRatio * (_trackWidth - _indicatorWidth);
      });
    }
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
        final userData = await _firestoreService.getClientSnapshot(searchUid);
        
        if (userData != null) {
          // Look for 'nom', fallback to 'prenom' if 'nom' is empty
          String name = userData['nom'] ?? userData['prenom'] ?? '';
          
          if (name.isNotEmpty && mounted) {
            setState(() => _clientNom = name);
          }
        }
        
        // Fallback: search by current auth user details if they exist
        if (_clientNom.isEmpty && authUser != null && authUser.email != null) {
          final qEmail = await FirebaseFirestore.instance
              .collection('utilisateurs')
              .where('email', isEqualTo: authUser.email)
              .limit(1)
              .get();
          if (qEmail.docs.isNotEmpty) {
            final data = qEmail.docs.first.data();
            String name = data['nom'] ?? data['prenom'] ?? '';
            if (name.isNotEmpty && mounted) {
              setState(() => _clientNom = name);
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
    final experts = await _firestoreService.getExperts(onlyAvailable: true);
    final villes = await _firestoreService.getVillesExperts();
    final serviceModels = await _firestoreService.getServices();

    if (mounted) {
      setState(() {
        _experts = experts;
        _villesExperts = villes;
        
        // Map Firestore services to UI format
        _categories = serviceModels.map((s) {
          final label = s.nom;
          final hardcoded = _categoryAssets[label];
          return {
            'label': label,
            // Use Cloudinary image from Firestore first, fallback to local asset
            'image': (s.image != null && s.image!.isNotEmpty) ? s.image : hardcoded?['image'],
            // Use hardcoded icon if available, fallback to a generic one
            'icon': hardcoded?['icon'] ?? Icons.business_center,
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
        // ALWAYS filter out unavailable experts in Client Home unless explicitly requested otherwise
        // (Since getExperts(onlyAvailable: true) is used, e.estDisponible should already be true,
        // but this adds a layer of safety).
        if (!e.estDisponible) return false;

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
        const SnackBar(content: Text('Please login to chat')),
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
                    child: Text('No cities available'),
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
                  ClientHeader(
                    greeting: 'Hi ${_clientNom.isNotEmpty ? _clientNom : "Client"},',
                    title: 'What service are you\nlooking for?',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NotificationBell(
                          idUtilisateur: FirebaseAuth.instance.currentUser?.uid ?? '',
                          role: 'client',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              context.go('/login');
                            }
                          },
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                    bottomPadding: 32,
                  ),
                  
                  const SizedBox(height: 24),
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
                  ScrollConfiguration(
                    behavior: const ScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: SizedBox(
                      height: 140,
                      child: ListView.separated(
                        controller: _servicesScrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 24),
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
                  ),
                  
                  // Enhanced Scroll Indicator
                  if (_categories.length > 3)
                    Center(
                      child: Container(
                        width: _trackWidth,
                        height: 4,
                        margin: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A69B1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 50),
                              left: _indicatorOffset,
                              child: Container(
                                width: _indicatorWidth,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A69B1),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4A69B1).withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
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
                              child: Text('No providers found'),
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
                                    service: expert.services.join(', '),
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
                              child: Text('No providers found'),
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
          ),
        ),
      ),
    );
  }
}