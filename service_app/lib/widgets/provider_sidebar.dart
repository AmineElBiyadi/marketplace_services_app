import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../screens/chat/chat_list_screen.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';

class ProviderSidebar extends StatefulWidget {
  final String activeRoute;
  final bool isMobile;
  final VoidCallback? onToggle;
  final bool isOpen;
  final String expertId;

  const ProviderSidebar({
    super.key,
    required this.activeRoute,
    this.isMobile = false,
    this.onToggle,
    this.isOpen = true,
    required this.expertId,
  });

  @override
  State<ProviderSidebar> createState() => _ProviderSidebarState();
}

class _ProviderSidebarState extends State<ProviderSidebar> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _firestoreService
        .isExpertPremium(widget.expertId)
        .listen((premium) {
          if (mounted) setState(() => _isPremium = premium);
        });
  }

  Future<void> _handleExpertLogout(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Delete FCM token so this device stops receiving notifications for this expert account
      await NotificationService.deleteUserToken(user.uid);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await AuthService().signOut();
    if (context.mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final double width = widget.isOpen || widget.isMobile ? 260 : 80;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: widget.isMobile || widget.isOpen ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
              children: [
                if (widget.isMobile || widget.isOpen)
                  const Row(
                    children: [
                      Icon(LucideIcons.users, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Expert',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                if (!widget.isMobile)
                  IconButton(
                    icon: Icon(widget.isOpen ? LucideIcons.x : LucideIcons.menu, color: Colors.white60, size: 18),
                    onPressed: widget.onToggle,
                  ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              children: [
                _sidebarItem(Icons.home, 'Home', '/provider/:expertId/dashboard'),
                _sidebarItem(Icons.work, 'Services', '/provider/:expertId/services'),
                _sidebarItem(Icons.calendar_today, 'Bookings', '/provider/:expertId/bookings'),
                _sidebarItem(
                  Icons.event,
                  'Agenda',
                  '/provider/:expertId/agenda',
                  badge: _isPremium ? '⭐' : null,
                ),
                StreamBuilder<int>(
                  stream: ChatService().getTotalUnreadCount('expert', expertId: widget.expertId),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _sidebarItem(
                      Icons.message,
                      'Messages',
                      '/provider/:expertId/messages',
                      badge: count > 0 ? count.toString() : null,
                      isNumericBadge: count > 0,
                    );
                  },
                ),
                _sidebarItem(Icons.person, 'Profile', '/provider/:expertId/profile'),
              ],
            ),
          ),

          // Logout
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
            child: _sidebarItem(LucideIcons.logOut, 'Log Out', '/logout', isDestructive: true),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, String route, {bool isDestructive = false, String? badge, bool isNumericBadge = false}) {
    final bool active = widget.activeRoute == route;
    final bool showLabel = widget.isOpen || widget.isMobile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (route == '/logout') {
            await _handleExpertLogout(context);
            return;
          }
          if (route.contains('/messages')) {
            context.go('/provider/${widget.expertId}/messages');
            if (widget.isMobile) {
              Navigator.pop(context);
            }
            return;
          }
          if (widget.activeRoute != route) {
            final targetRoute = route.replaceAll(':expertId', widget.expertId);
            context.go(targetRoute);
          }
          if (widget.isMobile) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isDestructive
                    ? Colors.redAccent
                    : (active ? Colors.white : Colors.white60),
              ),
              if (showLabel) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDestructive
                          ? Colors.redAccent
                          : (active ? Colors.white : Colors.white60),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null)
                  isNumericBadge
                      ? Badge(label: Text(badge))
                      : Text(badge, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
