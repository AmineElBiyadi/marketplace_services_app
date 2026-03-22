import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';
import '../../models/expert.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String expertId;

  const ProviderProfileScreen({super.key, required this.expertId});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  Expert? _expertData;
  ExpertModel? _expertModel;
  int _reviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final expertModel = await _firestoreService.getExpertProfile(widget.expertId);
      final expertDetailed = await _firestoreService.getExpertDetailed(widget.expertId);
      final reviews = await _firestoreService.getExpertReviews(widget.expertId);

      if (mounted) {
        setState(() {
          _expertModel = expertModel;
          _expertData = expertDetailed;
          _reviewsCount = reviews.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ProviderLayout(
        activeRoute: '/provider/profile',
        expertId: widget.expertId,
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final String fullName = _expertData?.nom ?? _expertModel?.user?.nom ?? 'Expert';
    final String serviceCategory = (_expertData?.services.isNotEmpty == true) 
        ? _expertData!.services.first 
        : "Professional Expert";
    final double rating = _expertData?.noteMoyenne ?? 0.0;
    final String city = _expertData?.ville.split(',').first ?? 'City not defined';
    final int rayon = _expertModel?.rayonTravaille ?? 20;
    final String photoUrl = _expertData?.photo ?? '';
    final bool isPremium = _expertData?.isPremium ?? false;

    return ProviderLayout(
      activeRoute: '/provider/profile',
      expertId: widget.expertId,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(
                  context,
                  fullName: fullName,
                  serviceCategory: serviceCategory,
                  rating: rating,
                  reviewsCount: _reviewsCount,
                  city: city,
                  rayon: rayon,
                  photoUrl: photoUrl,
                  isPremium: isPremium,
                ),
                const SizedBox(height: 24),
                _buildMenuSection(context),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {
    required String fullName,
    required String serviceCategory,
    required double rating,
    required int reviewsCount,
    required String city,
    required int rayon,
    required String photoUrl,
    required bool isPremium,
  }) {
    return Column(
      children: [
        // Avatar
        Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                image: photoUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: photoUrl.isEmpty
                  ? Center(
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          fullName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),

        // Category
        Text(
          serviceCategory,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),

        // Tags row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium/Free Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPremium ? const Color(0xFFFEF3C7) : const Color(0xFFFEF3C7), // Yellow background
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    isPremium ? LucideIcons.crown : LucideIcons.crown,
                    size: 14,
                    color: const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPremium ? "Premium" : "Free",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Rating
            Row(
              children: [
                const Icon(Icons.star, size: 18, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "($reviewsCount reviews)",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Location & Response Time
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.mapPin, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              city,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Icon(LucideIcons.clock, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 4),
            const Text(
              "Replies in ~15 min",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Dynamic distance info
        GestureDetector(
          onTap: () {
            // Can open personal info or edit distance modal
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.search, size: 14, color: AppColors.primary), // Close approx to icon in map
                const SizedBox(width: 6),
                Text(
                  "Working radius : $rayon km",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Preview Profile Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                // Future task: preview public profile
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                "Preview my public profile",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(
          icon: LucideIcons.user,
          title: "Personal Information",
          onTap: () async {
            await context.push('/provider/${widget.expertId}/profile/personal-info');
            _loadProfileData();
          },
        ),
        _buildMenuItem(
          icon: LucideIcons.bell,
          title: "Notifications",
          onTap: () {
            context.push('/provider/${widget.expertId}/notifications');
          },
        ),
        _buildMenuItem(
          icon: LucideIcons.barChart2,
          title: "Statistics",
          onTap: () {
            context.push('/provider/${widget.expertId}/profile/statistics');
          },
        ),
        _buildMenuItem(
          icon: LucideIcons.creditCard,
          title: "My Subscription",
          onTap: () {
            context.push('/provider/${widget.expertId}/subscription');
          },
        ),
        _buildMenuItem(
          icon: LucideIcons.fileText,
          title: "Supporting Documents",
          onTap: () {
            // context.push('/provider/${widget.expertId}/documents');
          },
        ),
        _buildMenuItem(
          icon: LucideIcons.fileCode, // Approximating CGU icon
          title: "Terms of Service / Privacy Policy",
          onTap: () {
            context.push('/provider/${widget.expertId}/profile/cgu');
          },
        ),
        
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = const Color(0xFF1E293B),
    Color iconColor = const Color(0xFF64748B),
    bool hideArrow = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (!hideArrow)
              const Icon(LucideIcons.chevronRight, size: 20, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}
