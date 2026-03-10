import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  final List<Map<String, dynamic>> notifications = const [
    {'id': 1, 'text': 'Nouveau prestataire à valider', 'type': 'warning', 'time': 'Il y a 5 min'},
    {'id': 2, 'text': 'Réclamation urgente déposée', 'type': 'error', 'time': 'Il y a 20 min'},
    {'id': 3, 'text': 'Paiement abonnement échoué', 'type': 'warning', 'time': 'Il y a 1h'},
    {'id': 4, 'text': 'Rapport mensuel disponible', 'type': 'info', 'time': 'Il y a 3h'},
  ];

  Color _getTypeColor(String type) {
    switch (type) {
      case 'error':
        return AppColors.destructive;
      case 'warning':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Centre de notifications',
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getTypeColor(notif['type'] as String),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif['text'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['time'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
