import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSidebar extends StatefulWidget {
  final String activeRoute;
  final bool isMobile;
  final VoidCallback? onToggle;
  final bool isOpen;

  const AdminSidebar({
    super.key,
    required this.activeRoute,
    this.isMobile = false,
    this.onToggle,
    this.isOpen = true,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  static const Color _primary = Color(0xFF3D5A99);
  static const Color _textPrimary = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final double width = widget.isOpen || widget.isMobile ? 260 : 80;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: _textPrimary,
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
                      Icon(LucideIcons.shield, color: _primary, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Admin',
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
                _sidebarItem(LucideIcons.home, 'Tableau de bord', '/admin'),
                _sidebarItem(LucideIcons.users, 'Utilisateurs', '/admin/users'),
                _sidebarItem(LucideIcons.wrench, 'Prestataires', '/admin/providers'),
                _sidebarItem(LucideIcons.calendarDays, 'Réservations', '/admin/reservations'),
                _sidebarItem(LucideIcons.star, 'Avis & Réclamations', '/admin/reviews'),
                _sidebarItem(LucideIcons.dollarSign, 'Finances', '/admin/finances'),
                _sidebarItem(LucideIcons.settings, 'Paramètres', '/admin/settings'),
              ],
            ),
          ),

          // Logout
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
            child: _sidebarItem(LucideIcons.logOut, 'Déconnexion', '/logout', isDestructive: true),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, String route, {bool isDestructive = false}) {
    final bool active = widget.activeRoute == route;
    final bool showLabel = widget.isOpen || widget.isMobile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (route == '/logout') {
            _handleLogout();
            return;
          }
          if (widget.activeRoute != route) {
            context.go(route);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: active ? _primary : Colors.transparent,
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
                Text(
                  label,
                  style: TextStyle(
                    color: isDestructive 
                        ? Colors.redAccent 
                        : (active ? Colors.white : Colors.white60),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_admin_id');
    if (mounted) {
      context.go('/admin/login');
    }
  }
}
