import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/notification_service.dart';
import '../../../theme/app_colors.dart';
import 'edit_profile_screen.dart';
import 'my_reviews_screen.dart';
import 'my_complaints_screen.dart';
import 'my_addresses_screen.dart';
import 'client_cgu_screen.dart';
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
  int _bookingsCount = 0;
  bool _useLocation = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadLocationPreference();
  }

  Future<void> _loadLocationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useLocation = prefs.getBool('use_location') ?? true;
    });
  }

  Future<void> _toggleLocationPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_location', value);
    setState(() {
      _useLocation = value;
    });
  }

  Future<void> _loadProfileData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final data = await _firestoreService.getClientByUid(user.uid);
        final clientId = data?['clientId'];
        final List<String> clientIds = [user.uid];
        if (clientId != null) clientIds.add(clientId);

        int bookingsCount = 0;
        try {
          final querySnapshot = await _firestoreService.getFirestoreInstance()
              .collection('interventions')
              .where('idClient', whereIn: clientIds)
              .get();
          bookingsCount = querySnapshot.docs.length;
        } catch (e) {
          debugPrint("Error fetching bookings count: $e");
        }

        if (mounted) {
          setState(() {
            _clientData = data;
            _bookingsCount = bookingsCount;
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
    final user = _authService.currentUser;
    if (user != null) {
      // Delete FCM token so this device stops receiving notifications for this account
      await NotificationService.deleteUserToken(user.uid);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _authService.signOut();
    if (mounted) context.go('/welcome');
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final String nom = _clientData?['nom'] ?? 'Client';
    String telephone = _clientData?['telephone'] ?? '';
    if (telephone.isEmpty && _authService.currentUser?.phoneNumber != null) {
      telephone = _authService.currentUser!.phoneNumber!;
    }
    final String email = _clientData?['email'] ?? _authService.currentUser?.email ?? '';
    final String city = _clientData?['ville'] ?? _clientData?['Ville'] ?? '';
    final String initial = nom.isNotEmpty ? nom[0].toUpperCase() : 'C';
    final ImageProvider? avatar = _buildImageProvider(_clientData?['image_profile']);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── Avatar ──
              Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      image: avatar != null
                          ? DecorationImage(image: avatar, fit: BoxFit.cover)
                          : null,
                    ),
                    child: avatar == null
                        ? Center(
                            child: Text(
                              initial,
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
                    child: GestureDetector(
                      onTap: () async {
                        if (_clientData == null) return;
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(clientData: _clientData!),
                          ),
                        );
                        if (result == true) _loadProfileData();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Name ──
              Text(
                nom,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),

              // ── Contact info ──
              Text(
                telephone.isNotEmpty ? telephone : email,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),

              // ── City + Member badge ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (city.isNotEmpty) ...[
                    const Icon(LucideIcons.mapPin, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCBD5E1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.user, size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Client',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Stats row ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    _buildStat(_bookingsCount.toString(), 'Bookings'),
                    _vDivider(),
                    _buildStat(
                      _clientData?['Pays'] ?? _clientData?['pays'] ?? 'Morocco',
                      'Country',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Edit profile button ──
              if (_clientData != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(clientData: _clientData!),
                          ),
                        );
                        if (result == true) _loadProfileData();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 28),

              // ── Menu Section ──
              _buildMenuSection(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats widget ──────────────────────────────────────────────
  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 36,
        color: const Color(0xFFE2E8F0),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  // ── Menu ─────────────────────────────────────────────────────
  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        _menuItem(
          icon: LucideIcons.calendar,
          title: 'My Bookings',
          onTap: () => context.push('/bookings-list'),
        ),
        _menuItem(
          icon: LucideIcons.mapPin,
          title: 'My Addresses',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const MyAddressesScreen())),
        ),
        _menuItem(
          icon: LucideIcons.star,
          title: 'My Reviews',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const MyReviewsScreen())),
        ),
        _menuItem(
          icon: LucideIcons.alertCircle,
          title: 'My Complaints',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const MyComplaintsScreen())),
        ),
        _menuItem(
          icon: LucideIcons.fileText,
          title: 'T&C / Privacy',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ClientCguScreen())),
        ),
        _buildToggleItem(
          icon: LucideIcons.mapPin,
          title: 'Use my location',
          value: _useLocation,
          onChanged: _toggleLocationPreference,
        ),
        const SizedBox(height: 16),
        _menuItem(
          icon: LucideIcons.logOut,
          title: 'Logout',
          textColor: const Color(0xFFEF4444),
          iconColor: const Color(0xFFEF4444),
          hideArrow: true,
          onTap: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF64748B)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: value ? const Color(0xFF2E335A) : const Color(0xFFCBD5E1),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 1,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
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
