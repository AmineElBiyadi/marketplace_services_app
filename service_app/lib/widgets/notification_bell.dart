import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class NotificationBell extends StatelessWidget {
  final String idUtilisateur;
  final String role;

  const NotificationBell({
    super.key,
    required this.idUtilisateur,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final _service = NotificationService();

    return StreamBuilder<int>(
      stream: _service.getUnreadCount(idUtilisateur),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1E293B)),
              onPressed: () {
                context.push('/notifications', extra: {
                  'idUtilisateur': idUtilisateur,
                  'role': role,
                });
              },
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
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
