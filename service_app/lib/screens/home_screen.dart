import 'package:flutter/material.dart';
import '../widgets/category_card.dart';
import '../widgets/nearby_provider_card.dart';
import '../widgets/top_rated_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {'label': 'Plumbing', 'icon': Icons.plumbing},
      {'label': 'Electricity', 'icon': Icons.electrical_services},
      {'label': 'Cleaning', 'icon': Icons.cleaning_services},
      {'label': 'Gardening', 'icon': Icons.yard},
      {'label': 'Hair', 'icon': Icons.content_cut},
    ];

    final List<Map<String, dynamic>> nearbyProviders = [
      {
        'name': 'Ahmed K.',
        'service': 'Plumbing',
        'rating': 4.8,
        'distance': 1.2,
        'imageUrl': 'https://i.pravatar.cc/150?img=1',
        'isPremium': false,
      },
      {
        'name': 'Sarah M.',
        'service': 'Cleaning',
        'rating': 4.9,
        'distance': 0.8,
        'imageUrl': 'https://i.pravatar.cc/150?img=2',
        'isPremium': true,
      },
      {
        'name': 'Youssef B.',
        'service': 'Electricity',
        'rating': 4.7,
        'distance': 2.1,
        'imageUrl': 'https://i.pravatar.cc/150?img=3',
        'isPremium': false,
      },
    ];

    final List<Map<String, dynamic>> topRated = [
      {
        'name': 'Omar H.',
        'services': 'Plumbing, Heating',
        'rating': 5.0,
        'imageUrl': 'https://i.pravatar.cc/150?img=4',
        'isPremium': true,
      },
      {
        'name': 'Leila A.',
        'services': 'Deep Cleaning',
        'rating': 4.9,
        'imageUrl': 'https://i.pravatar.cc/150?img=5',
        'isPremium': false,
      },
      {
        'name': 'Karim D.',
        'services': 'IT Support, Networking',
        'rating': 4.8,
        'imageUrl': 'https://i.pravatar.cc/150?img=6',
        'isPremium': false,
      },
    ];

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
                    const Text('Hi John,',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const Text('What service are you looking for?',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const TextField(
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
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
                          return CategoryCard(
                            label: cat['label'],
                            icon: cat['icon'],
                            onTap: () {},
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── BANNIERE PROMO ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Get 40% on Ironing',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const Text('CODE: IRON40',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3D5A99),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('BOOK NOW',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.iron,
                              size: 60, color: Color(0xFF3D5A99)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── NEARBY PROVIDERS ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nearby Providers',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Map >',
                              style: TextStyle(color: Color(0xFF3D5A99))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 210,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: nearbyProviders.length,
                        itemBuilder: (context, index) {
                          final p = nearbyProviders[index];
                          return NearbyProviderCard(
                            name: p['name'],
                            service: p['service'],
                            rating: p['rating'],
                            distance: p['distance'],
                            imageUrl: p['imageUrl'],
                            isPremium: p['isPremium'],
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
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topRated.length,
                      itemBuilder: (context, index) {
                        final e = topRated[index];
                        return TopRatedCard(
                          name: e['name'],
                          services: e['services'],
                          rating: e['rating'],
                          imageUrl: e['imageUrl'],
                          isPremium: e['isPremium'],
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