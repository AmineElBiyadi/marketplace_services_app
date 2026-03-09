import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expert.dart';
import '../services/firestore_service.dart';
import '../widgets/category_card.dart';
import '../widgets/nearby_provider_card.dart';
import '../widgets/top_rated_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<Expert> _experts = [];
  List<Expert> _filteredExperts = [];
  bool _isLoading = true;
  String _clientNom = 'Client';
  String? _selectedCategory;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Récupérer nom du client connecté
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      setState(() {
        _clientNom = userDoc.data()?['nom'] ??
            userDoc.data()?['email'] ??
            'Client';
      });
    }

    // Récupérer les experts
    final experts = await _firestoreService.getExperts();
    setState(() {
      _experts = experts;
      _filteredExperts = experts;
      _isLoading = false;
    });
  }

  // Filtre combiné : texte + catégorie
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    print('🔍 Catégorie sélectionnée: $_selectedCategory');
    print('👷 Experts: ${_experts.map((e) => '${e.nom}: ${e.services}').toList()}');

    setState(() {
      _filteredExperts = _experts.where((expert) {
        final matchCategory = _selectedCategory == null ||
            expert.services.any((s) =>
                s.toLowerCase().contains(
                    _selectedCategory!.toLowerCase()));
        final matchQuery = query.isEmpty ||
            expert.nom.toLowerCase().contains(query) ||
            expert.services.any(
                    (s) => s.toLowerCase().contains(query));
        return matchCategory && matchQuery;
      }).toList();
    });
  }

  // Sélectionner ou désélectionner une catégorie
  void _selectCategory(String label) {
    setState(() {
      _selectedCategory = _selectedCategory == label ? null : label;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── HEADER BLEU ──
              Container(
                padding: const EdgeInsets.all(16),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Casablanca, Maarif',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              Icon(Icons.keyboard_arrow_down,
                                  color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications_outlined,
                                  color: Colors.white, size: 22),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hi $_clientNom,',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('What service are you looking for?',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    // Barre de recherche
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => _applyFilters(),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search here',
                          hintStyle: TextStyle(color: Colors.white60),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── CATEGORIES ──
                    const Text('Popular',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
                        const Text('Nearby Providers',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Map >',
                              style: TextStyle(
                                  color: Color(0xFF3D5A99))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _isLoading
                        ? const Center(
                        child: CircularProgressIndicator())
                        : _filteredExperts.isEmpty
                        ? const Center(
                        child: Text('Aucun prestataire trouvé'))
                        : SizedBox(
                      height: 210,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filteredExperts.length,
                        itemBuilder: (context, index) {
                          final expert =
                          _filteredExperts[index];
                          return NearbyProviderCard(
                            name: expert.nom,
                            service: expert.services.isNotEmpty
                                ? expert.services.first
                                : '',
                            rating: expert.noteMoyenne,
                            distance: 0.0,
                            imageUrl: expert.photo,
                            isPremium: expert.isPremium,
                            onTap: () {},
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── TOP RATED ──
                    const Text('Top Rated',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    _isLoading
                        ? const Center(
                        child: CircularProgressIndicator())
                        : _filteredExperts.isEmpty
                        ? const Center(
                        child: Text('Aucun prestataire trouvé'))
                        : ListView.builder(
                      shrinkWrap: true,
                      physics:
                      const NeverScrollableScrollPhysics(),
                      itemCount: _filteredExperts.length,
                      itemBuilder: (context, index) {
                        final expert = _filteredExperts[index];
                        return TopRatedCard(
                          name: expert.nom,
                          services: expert.services.join(', '),
                          rating: expert.noteMoyenne,
                          imageUrl: expert.photo,
                          isPremium: expert.isPremium,
                          onChat: () {},
                          onTap: () {},
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