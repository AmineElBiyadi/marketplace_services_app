import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/expert.dart';
import '../../services/firestore_service.dart';
import '../../widgets/smart_image.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpertProfileScreen extends StatefulWidget {
  final Expert expert;

  const ExpertProfileScreen({super.key, required this.expert});

  @override
  State<ExpertProfileScreen> createState() => _ExpertProfileScreenState();
}

class _ExpertProfileScreenState extends State<ExpertProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _reviews = [];
  List<String> _portfolioImages = []; // base64 strings
  bool _isLoadingExtra = true;
  late Expert _expert;

  static const Color _kPrimary = Color(0xFF3D5A99);
  static const Color _kBg = Color(0xFFF5F3EC);
  static const Color _kGold = Color(0xFFFFC107);

  @override
  void initState() {
    super.initState();
    _expert = widget.expert;
    _tabController = TabController(length: 4, vsync: this);
    _loadExtraData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExtraData() async {
    try {
      // 1. Services réels depuis serviceExperts + services
      final servicesDetailed =
          await _firestoreService.getExpertServicesDetailed(widget.expert.id);

      if (servicesDetailed.isNotEmpty) {
        setState(() {
          _services = servicesDetailed
              .map((s) => {
                    'title': s['serviceName'] ?? '',
                    'description': s['description'] ?? '',
                    'duration': '',
                    'anneeExperience': s['anneeExperience'] ?? 0,
                  })
              .toList();
        });
      } else {
        setState(() {
          _services = widget.expert.services
              .map((s) => {'title': s, 'description': '', 'duration': ''})
              .toList();
        });
      }

      // 2. Reviews depuis la collection interventions
      final reviews =
          await _firestoreService.getExpertReviews(widget.expert.id);

      // 3. Images portfolio depuis imagesExemplaires
      final portfolioImages =
          await _firestoreService.getExpertPortfolioImages(widget.expert.id);

      // 4. Refresh basic expert info (rating, etc.)
      final refreshed = await _firestoreService.getExpertDetailed(widget.expert.id);

      if (mounted) {
        setState(() {
          if (refreshed != null) _expert = refreshed;
          _reviews = reviews;
          _portfolioImages = portfolioImages;
          _isLoadingExtra = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expert extra data: \$e');
      if (mounted) setState(() => _isLoadingExtra = false);
    }
  }

  String get _responseTime => _expert.isPremium ? '~10 min' : '~15 min';

  String get _reviewCount {
    if (_reviews.isNotEmpty) return '(${_reviews.length} avis)';
    return '(0 avis)';
  }

  @override
  Widget build(BuildContext context) {
    final expert = _expert;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: _kPrimary,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.black87, size: 18),
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                flexibleSpace: const FlexibleSpaceBar(
                  background: ColoredBox(color: _kPrimary),
                ),
              ),
            ],
            body: CustomScrollView(
              slivers: [
                // Profile card
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(height: 60, color: _kPrimary),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: _kBg,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.12),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: SmartImage(
                                        source: expert.photo,
                                        width: 80,
                                        height: 80,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Name + category
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    expert.nom,
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                if (expert.isPremium)
                                                  const Text('👑',
                                                      style: TextStyle(fontSize: 18)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              expert.services.isNotEmpty
                                                  ? expert.services.first
                                                  : '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.star,
                                                    color: _kGold, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  expert.noteMoyenne.toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _reviewCount,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(Icons.access_time,
                                                    size: 14,
                                                    color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _responseTime,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    
                // Tabs
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: _kBg,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: _kPrimary,
                          unselectedLabelColor: Colors.grey.shade500,
                          indicator: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          tabs: const [
                            Tab(text: 'Services'),
                            Tab(text: 'Portfolio'),
                            Tab(text: 'Reviews'),
                            Tab(text: 'Info'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    
                // Tab content
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ServicesTab(
                        services: _services,
                        isLoading: _isLoadingExtra,
                        expert: expert,
                      ),
                      _PortfolioTab(
                        images: _portfolioImages,
                        isLoading: _isLoadingExtra,
                      ),
                      _ReviewsTab(
                        reviews: _reviews,
                        rating: expert.noteMoyenne,
                        isLoading: _isLoadingExtra,
                      ),
                      _InfoTab(expert: expert),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),


      // Bottom action bar
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Row(
            children: [
              // Contact Button (Call)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri launchUri = Uri(
                      scheme: 'tel',
                      path: widget.expert.telephone,
                    );
                    if (await canLaunchUrl(launchUri)) {
                      await launchUrl(launchUri);
                    }
                  },
                  icon: const Icon(Icons.call, color: Colors.white, size: 20),
                  label: const Text(
                    'Contact this provider',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50), // Green for contact
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Main Action (Book Now - Placeholder)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.bookmark_border, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEEEEEE),
      child: Icon(Icons.person, size: 40, color: Colors.grey.shade400),
    );
  }
}

// ─────────────────────────────────────────────
class _ServicesTab extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final bool isLoading;
  final Expert expert;

  const _ServicesTab({
    required this.services,
    required this.isLoading,
    required this.expert,
  });

  static const Color _kPrimary = Color(0xFF3D5A99);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (services.isEmpty) {
      return Center(
        child: Text('No services available',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final service = services[index];
        final title = (service['title'] as String?) ??
            (service['nom'] as String?) ?? '';
        final description = (service['description'] as String?) ?? '';
        final duration = (service['duration'] as String?) ??
            (service['duree'] as String?) ?? '';

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(description,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500)),
                      ],
                      if (duration.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(duration,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.chat_bubble_outline,
                        color: _kPrimary, size: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
class _PortfolioTab extends StatelessWidget {
  /// Liste d'images en base64 récupérées depuis [imagesExemplaires]
  final List<String> images;
  final bool isLoading;

  const _PortfolioTab({required this.images, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF3D5A99)));
    }
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No portfolio photos yet',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final raw = images[index];
        return GestureDetector(
          onTap: () => _showFullImage(context, raw),
          child: SmartImage(
            source: raw,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext context, String raw) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: SmartImage(source: raw, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _ReviewsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final double rating;
  final bool isLoading;

  const _ReviewsTab({
    required this.reviews,
    required this.rating,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF3D5A99)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                            (i) => Icon(
                          i < rating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reviews.length} reviews',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No reviews yet',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          )
        else
          for (final r in reviews) _ReviewCard(review: r),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final name =
    (review['clientNom'] ?? review['nom'] ?? 'Client') as String;
    final comment =
    (review['commentaire'] ?? review['comment'] ?? '') as String;
    final note = ((review['note'] ?? 0) as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                const Color(0xFF3D5A99).withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Color(0xFF3D5A99),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Row(
                children: List.generate(
                  5,
                      (i) => Icon(
                    i < note.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment,
                style:
                TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _InfoTab extends StatefulWidget {
  final Expert expert;

  const _InfoTab({required this.expert});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  static const Color _kPrimary = Color(0xFF3D5A99);
  final FirestoreService _firestoreService = FirestoreService();

  String? _description;

  @override
  void initState() {
    super.initState();
    _loadDescription();
  }

  Future<void> _loadDescription() async {
    try {
      final data = await _firestoreService.getExpertById(widget.expert.id);
      final raw = data?['Experience'] as String?;
      if (mounted && raw != null && raw.isNotEmpty) {
        setState(() => _description = raw);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final expert = widget.expert;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoSection(
          title: 'About',
          child: Text(
            _description ?? 'No description available.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 16),
        _InfoSection(
          title: 'Location',
          child: Row(
            children: [
              const Icon(Icons.location_on, color: _kPrimary, size: 18),
              const SizedBox(width: 6),
              Text(
                expert.ville.isNotEmpty ? expert.ville : 'Not specified',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoSection(
          title: 'Services offered',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in expert.services)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Text(
                      s,
                      style: const TextStyle(
                          fontSize: 13,
                          color: _kPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (expert.prixMin != null) ...[
          const SizedBox(height: 16),
          _InfoSection(
            title: 'Starting price',
            child: Text(
              'From ${expert.prixMin!.toStringAsFixed(0)} MAD',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _kPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}