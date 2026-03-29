import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cloudinary_service.dart';
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
  double _rayonValue = 20.0;
  bool _isSavingRayon = false;
  bool _isUploadingPhoto = false;

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
          _rayonValue = (_expertModel?.rayonTravaille ?? 20).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfilePicture() async {
    if (_expertModel == null) return;
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isUploadingPhoto = true);
        
        final imageUrl = await CloudinaryService.uploadImage(result.files.single.bytes);
        
        if (imageUrl != null) {
          await FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(_expertModel!.idUtilisateur)
              .update({'photo': imageUrl, 'image_profile': imageUrl});
              
          // Ensure it's optionally updated on the expert document if your DB uses it there
          await FirebaseFirestore.instance
              .collection('experts')
              .doc(widget.expertId)
              .update({'photo': imageUrl}).catchError((_) => null); // Silently ignore if experts doesn't have photo
              
          await _loadProfileData();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile picture updated successfully!"), backgroundColor: Colors.green),
            );
          }
        } else {
          throw Exception("Failed to upload image.");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
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
        ? _expertData!.services.join('  •  ') 
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
        body: SingleChildScrollView(
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
    );
  }

  Widget _buildHeader(BuildContext context, {
    required String fullName,
    required String serviceCategory,
    required double rating,
    required int reviewsCount,
    required String city,
    required String photoUrl,
    required bool isPremium,
  }) {
    return Column(
      children: [
        // Avatar
        GestureDetector(
          onTap: _isUploadingPhoto ? null : _updateProfilePicture,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  image: photoUrl.isNotEmpty && !_isUploadingPhoto
                      ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: _isUploadingPhoto
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : photoUrl.isEmpty
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
              if (!_isUploadingPhoto)
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
          textAlign: TextAlign.center,
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
        const SizedBox(height: 24),
        _buildRayonSlider(),
        const SizedBox(height: 24),

        // Preview Profile Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                if (_expertData != null) {
                  context.push('/experts/${widget.expertId}', extra: _expertData);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Loading profile data...")),
                  );
                }
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

  Widget _buildRayonSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.compass, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              const Text(
                "Working radius",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_isSavingRayon)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Maximum distance", style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    Text(
                      "${_rayonValue.toInt()} km",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: const Color(0xFFE2E8F0),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _rayonValue,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    onChanged: (val) {
                      setState(() {
                        _rayonValue = val;
                      });
                    },
                    onChangeEnd: (val) async {
                      setState(() => _isSavingRayon = true);
                      try {
                        await _firestoreService.updateExpertRadius(widget.expertId, val.toInt());
                      } finally {
                        setState(() => _isSavingRayon = false);
                      }
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("5 km", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    Text("100 km", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
          icon: LucideIcons.fileImage,
          title: "My Documents",
          onTap: () {
            context.push('/provider/${widget.expertId}/profile/documents');
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
          title: "Terms of Service / Privacy Policy",
          onTap: () {
            context.push('/provider/${widget.expertId}/profile/cgu');
          },
        ),
        _buildMenuItem(
          icon: LucideIcons.alertCircle,
          title: "My Claims",
          onTap: () {
            context.push('/provider/${widget.expertId}/profile/reclamations');
          },
        ),
        _buildMenuItem(
          icon: LucideIcons.alertTriangle,
          title: "Deactivate my account",
          onTap: () => _showDeactivateDialog(context),
          textColor: Colors.orange,
          iconColor: Colors.orange,
        ),
        _buildMenuItem(
          icon: LucideIcons.logOut,
          title: "Log out",
          onTap: () async {
            bool confirm = await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Log out"),
                content: const Text("Are you sure you want to log out?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Log out", style: TextStyle(color: Colors.red))),
                ],
              ),
            ) ?? false;
            if (confirm) {
              await FirebaseAuth.instance.signOut();
              if (mounted) context.go('/welcome');
            }
          },
          textColor: Colors.red,
          iconColor: Colors.red,
          hideArrow: true,
        ),
      ],
    );
  }

  void _showDeactivateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Deactivate my account"),
        content: const Text(
          "Are you sure you want to deactivate your account? Your profile will no longer be visible to clients. You can reactivate it at any time.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _handleDeactivate();
            },
            child: const Text("Deactivate", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeactivate() async {
    try {
      await _firestoreService.deactivateExpertSelf(widget.expertId);
      if (mounted) {
        context.go('/provider/deactivated');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
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
