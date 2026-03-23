import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/expert.dart';
import '../../services/firestore_service.dart';
import '../../widgets/smart_image.dart';
import '../../widgets/start_chat_sheet.dart';

class ExpertProfileScreen extends StatefulWidget {
  final Expert expert;
  final String? preSelectedService;

  const ExpertProfileScreen({
    super.key, 
    required this.expert,
    this.preSelectedService,
  });

  @override
  State<ExpertProfileScreen> createState() => _ExpertProfileScreenState();
}

class _ExpertProfileScreenState extends State<ExpertProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;

  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _portfolioImages = [];
  bool _isLoadingExtra = true;
  late Expert _expert;

  static const Color _kPrimary = Color(0xFF3D5A99);
  static const Color _kBg = Color(0xFFF9F6EE); // matches screenshot off-white
  static const Color _kTextBlue = Color(0xFF3D5A99);
  static const Color _kGold = Color(0xFFFFC107);

  @override
  void initState() {
    super.initState();
    _expert = widget.expert;
    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();
    _loadExtraData();
    // Record profile view
    _firestoreService.recordProfileView(_expert.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExtraData() async {
    try {
      // 1. Services réels depuis serviceExperts + services
      final servicesDetailed =
          await _firestoreService.getExpertServicesDetailed(widget.expert.id);

      if (servicesDetailed.isNotEmpty) {
        // Filter out hidden or inactive services from the client view
        final visibleServices = servicesDetailed.where((s) => 
            (s['estActive'] ?? true) == true && 
            (s['isVisibleByPlan'] ?? true) == true
        ).toList();

        List<Map<String, dynamic>> groupedList = [];
        for (var s in visibleServices) {
          final tasks = s['tasks'] as List<dynamic>? ?? [];
          groupedList.add({
            'title': s['serviceName'] ?? '',
            'description': s['description'] ?? '',
            'duration': '1h',
            'serviceName': s['serviceName'] ?? '',
            'tasks': tasks,
          });
        }
        if (widget.preSelectedService != null && widget.preSelectedService!.isNotEmpty) {
          groupedList = groupedList.where((s) => s['serviceName'].toString().toLowerCase() == widget.preSelectedService!.toLowerCase()).toList();
        }

        setState(() {
          _services = groupedList;
        });
      } else {
        var fallbackList = widget.expert.services
              .map((s) => {
                    'title': s,
                    'description': '',
                    'duration': '',
                    'serviceName': s,
                    'taskName': null,
                    'tasks': <dynamic>[],
                  })
              .toList();
        
        if (widget.preSelectedService != null && widget.preSelectedService!.isNotEmpty) {
          fallbackList = fallbackList.where((s) => s['serviceName'].toString().toLowerCase() == widget.preSelectedService!.toLowerCase()).toList();
        }

        setState(() {
          _services = fallbackList;
        });
      }

      // 2. Reviews depuis la collection interventions
      final reviews =
          await _firestoreService.getExpertReviews(widget.expert.id);

      // 3. Images portfolio avec détails service/tache
      final portfolioImages =
          await _firestoreService.getExpertPortfolioImagesWithDetails(widget.expert.id);

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

  String get _reviewCount {
    if (_reviews.isNotEmpty) return '(${_reviews.length} reviews)';
    return '(0 reviews)';
  }

  /// Calcule la note moyenne à partir des reviews réellement chargées.
  double get _computedRating {
    if (_reviews.isEmpty) return _expert.noteMoyenne;
    double total = 0;
    for (final r in _reviews) {
      total += ((r['note'] ?? 0) as num).toDouble();
    }
    return total / _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final expert = _expert;

    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
              // ── Scrollable content ─────────────────────────────
              NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    expandedHeight: 160,
                    pinned: true,
                    backgroundColor: _kPrimary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    automaticallyImplyLeading: false,
                    flexibleSpace: const FlexibleSpaceBar(
                      background: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Spacer so content doesn't hide behind the avatar overlay
                  const SliverToBoxAdapter(child: SizedBox(height: 56)),

                  // Name + rating row
                  SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Name + premium badge
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        expert.nom,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: _kTextBlue,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    if (expert.isPremium)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(Icons.workspace_premium, color: Colors.amber, size: 26),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  expert.services.join('  •  '),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _kTextBlue.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Rating + response time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  _computedRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: _kTextBlue,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _reviewCount,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _kTextBlue.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Tabs (Now Sticky via SliverPersistentHeader)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyTabBarDelegate(
                        Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: _kTextBlue,
                            unselectedLabelColor:
                                _kTextBlue.withValues(alpha: 0.6),
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelStyle: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                            unselectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 13),
                            tabs: const [
                              Tab(text: 'Services'),
                              Tab(text: 'Portfolio'),
                              Tab(text: 'Reviews'),
                              Tab(text: 'Info'),
                            ],
                          ),
                        ),
                      ),
                      _kBg,
                    ),
                  ),
                ],
                body: TabBarView(
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
                      filterService: widget.preSelectedService,
                    ),
                    _ReviewsTab(
                      reviews: _reviews,
                      rating: _computedRating,
                      isLoading: _isLoadingExtra,
                    ),
                    _InfoTab(expert: expert),
                  ],
                ),
              ),

              // ── Avatar overlay — smooth collapse animation ──
              AnimatedBuilder(
                animation: _scrollController,
                builder: (context, child) {
                  double offset = _scrollController.hasClients ? _scrollController.offset : 0;
                  
                  // The AppBar shrinks by roughly 104 pixels.
                  double maxOffset = 90.0; 
                  double progress = (offset / maxOffset).clamp(0.0, 1.0);
                  
                  // Interpolate Top
                  double startTop = 115;
                  double endTop = MediaQuery.of(context).padding.top + 8;
                  double top = startTop - (startTop - endTop) * progress;

                  // Interpolate Left (starts centered, moves to next to back button)
                  double startSize = 90;
                  double startLeft = (constraints.maxWidth - startSize) / 2;
                  double endLeft = 56;
                  double left = startLeft + (endLeft - startLeft) * progress;

                  // Interpolate Size
                  double endSize = 40;
                  double size = startSize - (startSize - endSize) * progress;
                  
                  // Fade in name when scrolled
                  double nameOpacity = ((progress - 0.5) * 2).clamp(0.0, 1.0);

                  return Positioned(
                    top: top,
                    left: left,
                    // We use an unbounded width so the Row can safely overflow the 
                    // right constraint of the avatar Box constraints without wrapping incorrectly.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24 - (12 * progress)), // shrinks from 24 to 12
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20 - (10 * progress)),
                            child: child,
                          ),
                        ),
                        if (nameOpacity > 0) ...[
                          const SizedBox(width: 12),
                          Opacity(
                            opacity: nameOpacity,
                            child: Row(
                              children: [
                                Text(
                                  expert.nom,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (expert.isPremium)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
                                  )
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                },
                child: SmartImage(
                  source: expert.photo,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              // ── Back button on top of everything ──
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: _kTextBlue, size: 20),
                        onPressed: () => context.pop(),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
          },
        ),
        ),
      ),

      // Bottom action bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton.icon(
            onPressed: () => StartChatSheet.show(context, expert: _expert),
            icon: const Icon(Icons.chat_bubble_outline,
                color: Colors.white, size: 20),
            label: const Text(
              'Contacter le prestataire',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color backgroundColor;

  _StickyTabBarDelegate(this.child, this.backgroundColor);

  @override
  double get minExtent => 56.0;

  @override
  double get maxExtent => 56.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return oldDelegate.child != child;
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
        final serviceName = (service['serviceName'] as String?) ?? (service['title'] as String?) ?? '';
        final description = (service['description'] as String?) ?? '';
        final duration = (service['duration'] as String?) ?? '';
        final tasks = (service['tasks'] as List<dynamic>?) ?? [];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: services.length == 1,
              title: Text(
                serviceName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _kPrimary,
                ),
              ),
              subtitle: description.isNotEmpty ? Text(
                description,
                style: TextStyle(fontSize: 13, color: _kPrimary.withValues(alpha: 0.6)),
              ) : null,
              childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              children: [
                if (tasks.isEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Service standard", style: TextStyle(fontSize: 14)),
                    trailing: _buildChatIcon(context, expert, serviceName, null),
                  )
                else
                  ...tasks.map((t) {
                    final taskTitle = t['nom'] ?? 'Tâche';
                    final taskDesc = t['description'] ?? '';
                    final taskDuration = t['duree']?.toString() ?? t['prix']?.toString() ?? '';
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(
                        taskTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (taskDesc.isNotEmpty)
                            Text(taskDesc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          if (taskDuration.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, size: 12, color: _kPrimary.withValues(alpha: 0.5)),
                                  const SizedBox(width: 4),
                                  Text(taskDuration, style: TextStyle(fontSize: 11, color: _kPrimary.withValues(alpha: 0.6))),
                                ],
                              ),
                            )
                        ],
                      ),
                      trailing: _buildChatIcon(context, expert, serviceName, taskTitle),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatIcon(BuildContext context, Expert expert, String serviceName, String? taskName) {
    return GestureDetector(
      onTap: () => StartChatSheet.show(
        context, 
        expert: expert, 
        preSelectedService: serviceName,
        preSelectedTask: taskName,
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.chat_bubble_outline, color: _kPrimary, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _PortfolioTab extends StatelessWidget {
  final List<Map<String, dynamic>> images;
  final bool isLoading;
  final String? filterService;

  const _PortfolioTab({
    required this.images,
    required this.isLoading,
    this.filterService,
  });

  static const Color _kPrimary = Color(0xFF3D5A99);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF3D5A99)));
    }

    // Only show images the plan allows
    var filtered = images.where((img) => img['isVisibleByPlan'] == true).toList();

    // Apply service filter if passed
    if (filterService != null && filterService!.isNotEmpty) {
      filtered = filtered.where((img) =>
        (img['serviceName'] as String? ?? '').toLowerCase() ==
            filterService!.toLowerCase()
      ).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              filterService != null
                  ? 'Aucune photo pour ce service'
                  : 'Aucune photo de portfolio',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // Group by service name
    final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (final img in filtered) {
      final service = (img['serviceName'] as String?) ?? 'Autre';
      final task = (img['taskName'] as String?) ?? '';
      grouped.putIfAbsent(service, () => {});
      grouped[service]!.putIfAbsent(task, () => []);
      grouped[service]![task]!.add(img);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((serviceEntry) {
        final serviceName = serviceEntry.key;
        final taskGroups = serviceEntry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Service header ──────────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.handyman_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    serviceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            // ── Tasks within this service ─────────────────────
            ...taskGroups.entries.map((taskEntry) {
              final taskName = taskEntry.key;
              final taskImages = taskEntry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (taskName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 4, height: 16,
                            decoration: BoxDecoration(
                              color: _kPrimary.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            taskName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _kPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: taskImages.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, index) {
                      final raw = taskImages[index]['image'] as String? ?? '';
                      return GestureDetector(
                        onTap: () => _showFullImage(context, raw),
                        child: SmartImage(
                          source: raw,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),

            const SizedBox(height: 8),
          ],
        );
      }).toList(),
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
