import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paramètres',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Configuration de la plateforme',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSettingsSection(
                      title: 'Général',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.business,
                          title: 'Informations de l\'entreprise',
                          onTap: () {},
                        ),
                        _buildSettingsItem(
                          icon: Icons.language,
                          title: 'Langues',
                          onTap: () {},
                        ),
                        _buildSettingsItem(
                          icon: Icons.access_time,
                          title: 'Fuseau horaire',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildSettingsSection(
                      title: 'Paiements',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.payment,
                          title: 'Méthodes de paiement',
                          onTap: () {},
                        ),
                        _buildSettingsItem(
                          icon: Icons.percent,
                          title: 'Commissions',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildSettingsSection(
                      title: 'Notifications',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.notifications,
                          title: 'Paramètres de notifications',
                          onTap: () {},
                        ),
                        _buildSettingsItem(
                          icon: Icons.email,
                          title: 'Templates d\'emails',
                          onTap: () {},
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
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
      onTap: onTap,
    );
  }
}
