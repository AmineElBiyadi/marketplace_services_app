import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../screens/chat/chat_list_screen.dart';
import '../services/firestore_service.dart';

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
<<<<<<< HEAD
                _sidebarItem(LucideIcons.home, 'Tableau de bord', '/provider/:expertId/dashboard'),
                // Agenda tab: only visible for premium experts
                if (_isPremium)
                  _sidebarItem(
                    LucideIcons.calendarDays,
                    'Mon Agenda',
                    '/provider/:expertId/agenda',
                    badge: '⭐',
                  ),
=======
                _sidebarItem(LucideIcons.home, 'Dashboard', '/provider/:expertId/dashboard'),
                _sidebarItem(LucideIcons.calendarDays, 'My Agenda', '/provider/:expertId/agenda'),
>>>>>>> a22adabeb4cfdb3a6446dfacc1ef4b31007eca54
                _sidebarItem(LucideIcons.messageSquare, 'Messages', '/provider/messages'),
                _sidebarItem(LucideIcons.user, 'Profile', '/provider/:expertId/profile'),
                _sidebarItem(LucideIcons.briefcase, 'My Services', '/provider/:expertId/services'),
                _sidebarItem(LucideIcons.clipboardList, 'Reservations', '/provider/:expertId/bookings'),
                _sidebarItem(LucideIcons.bell, 'Notifications', '/provider/:expertId/notifications'),
                _sidebarItem(LucideIcons.creditCard, 'Subscription', '/provider/:expertId/subscription'),
                _sidebarItem(LucideIcons.settings, 'Settings', '/provider/:expertId/settings'),
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

  Widget _sidebarItem(IconData icon, String label, String route, {bool isDestructive = false, String? badge}) {
    final bool active = widget.activeRoute == route;
    final bool showLabel = widget.isOpen || widget.isMobile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (route == '/logout') {
            context.go('/login');
            return;
          }
          if (route == '/provider/messages') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatListScreen(
                  currentUserRole: 'expert',
                  expertId: widget.expertId,
                ),
              ),
            );
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
                  Text(badge, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
