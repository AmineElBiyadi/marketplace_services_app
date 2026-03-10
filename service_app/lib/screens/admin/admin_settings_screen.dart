import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../layouts/admin_layout.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin/settings',
      child: Column(
        children: [
          _buildTopBar(isMobile),
          _buildMainContent(),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _border))),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(LucideIcons.menu, color: _textPrimary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const Text('Paramètres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _settingItem(LucideIcons.appWindow, 'Général', 'Nom de l\'application, logo, etc.'),
          _settingItem(LucideIcons.shieldCheck, 'Sécurité', 'Authentification et accès.'),
          _settingItem(LucideIcons.bell, 'Notifications', 'Configuration des alertes.'),
          _settingItem(LucideIcons.database, 'Base de données', 'Maintenance et sauvegardes.'),
        ],
      ),
    );
  }

  Widget _settingItem(IconData icon, String title, String sub) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
      child: ListTile(
        leading: Icon(icon, color: _primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
        trailing: const Icon(LucideIcons.chevronRight, size: 18),
        onTap: () {},
      ),
    );
  }
}
