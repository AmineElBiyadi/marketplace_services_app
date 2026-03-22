import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import 'edit_profile_screen.dart';
import 'my_reviews_screen.dart';
import 'my_complaints_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  Map<String, dynamic>? _clientData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final data = await _firestoreService.getClientByUid(user.uid);
        if (mounted) {
          setState(() {
            _clientData = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _authService.signOut();
    if (mounted) {
      context.go('/welcome');
    }
  }

  ImageProvider? _buildImageProvider(String? imageString) {
    if (imageString == null || imageString.isEmpty) return null;
    if (imageString.startsWith('http://') || imageString.startsWith('https://')) {
      return NetworkImage(imageString);
    }
    try {
      final Uint8List bytes = base64Decode(imageString);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors matching the provided design
    const bgColor = Color(0xFFFCF9F2); // Soft cream background
    const primaryBlue = Color(0xFF2A4278); // Dark blue text/icons
    const lightTextBlue = Color(0xFF5B73A0); // Lighter blue for phone number
    const redColor = Color(0xFFF05151); // Red for logout

    String nom = _clientData?['nom'] ?? 'Client';
    String telephone = _clientData?['telephone'] ?? '';
    if (telephone.isEmpty && _authService.currentUser?.phoneNumber != null) {
      telephone = _authService.currentUser!.phoneNumber!;
    }
    String initial = nom.isNotEmpty ? nom[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Avatar Section ──
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFFDCDFEA),
                          backgroundImage: _buildImageProvider(_clientData?['image_profile']),
                          child: _buildImageProvider(_clientData?['image_profile']) == null
                              ? Text(initial, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: primaryBlue))
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // ── User Info ──
                    Text(
                      nom,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      telephone,
                      style: const TextStyle(
                        fontSize: 15,
                        color: lightTextBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // ── Edit Profile Button ──
                    if (_clientData != null)
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(
                                clientData: _clientData!,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadProfileData();
                          }
                        },
                        child: const Text(
                          'Edit profile',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3561A7), // slightly brighter blue
                          ),
                        ),
                      ),
                    if (_clientData == null)
                      const SizedBox(height: 14), // Placeholder space if loading fail
                    const SizedBox(height: 40),
                    
                    // ── Menu List ──
                    _buildMenuItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'My Bookings',
                      color: primaryBlue,
                      onTap: () => context.push('/bookings-list'),
                    ),
                    _buildMenuItem(
                      icon: Icons.star_border_outlined,
                      label: 'My Reviews',
                      color: primaryBlue,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyReviewsScreen())),
                    ),
                    _buildMenuItem(
                      icon: Icons.warning_amber_outlined,
                      label: 'My Complaints',
                      color: primaryBlue,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyComplaintsScreen())),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildMenuItem(
                      icon: Icons.text_snippet_outlined,
                      label: 'Terms & Privacy',
                      color: primaryBlue,
                      onTap: () {
                        // TODO
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // ── Log Out Option ──
                    _buildMenuItem(
                      icon: Icons.logout,
                      label: 'Log out',
                      color: redColor,
                      hideArrow: true,
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool hideArrow = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (!hideArrow)
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6), size: 22),
          ],
        ),
      ),
    );
  }
}
