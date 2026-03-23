import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class NotificationBell extends StatelessWidget {
  final String idUtilisateur;
  final String role; // 'Client', 'Expert', 'Admin'
  final Color? color;

  const NotificationBell({
    super.key,
    required this.idUtilisateur,
    required this.role,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final _service = NotificationService();

    return StreamBuilder<int>(
      stream: _service.getUnreadCount(idUtilisateur),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(LucideIcons.bell, color: color ?? const Color(0xFF1E293B)),
              onPressed: () {
                // Navigate to notification list screen
                context.push('/notifications', extra: {
                  'idUtilisateur': idUtilisateur,
                  'role': role,
                });
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
