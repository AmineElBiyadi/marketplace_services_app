import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class NotificationListScreen extends StatelessWidget {
  final Map<String, dynamic> data; // idUtilisateur, role

  const NotificationListScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final _service = NotificationService();
    final String idUtilisateur = data['idUtilisateur'] ?? '';
    final String role = data['role'] ?? 'Client';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => _service.markAllAsRead(idUtilisateur),
            child: const Text("Mark as read", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _service.getNotifications(idUtilisateur),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading notifications: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _buildNotificationCard(context, n, _service, role);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(LucideIcons.bellOff, size: 48, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          const Text("No notifications yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Text("We'll let you know when something happens.", style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel n, NotificationService _service, String role) {
    final bool isUnread = !n.estLue;
    final timeStr = DateFormat('dd/MM HH:mm').format(n.createdAt);

    return InkWell(
      onTap: () {
        _service.markAsRead(n.id);
        _handleRedirection(context, n, role);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF8FAFF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isUnread ? AppColors.primary.withOpacity(0.1) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _getIconBackgroundByNotification(n.type), shape: BoxShape.circle),
              child: Icon(_getIconByNotification(n.type), size: 18, color: _getIconColorByNotification(n.type)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(n.titre, style: TextStyle(fontSize: 14, fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF0F172A))),
                      Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(n.corps, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
                ],
              ),
            ),
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(left: 10, top: 2),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconByNotification(String type) {
    switch (type) {
      case 'booking': return LucideIcons.calendar;
      case 'review': return LucideIcons.star;
      case 'claim': return LucideIcons.alertCircle;
      case 'account': return LucideIcons.user;
      case 'registration': return LucideIcons.userPlus;
      default: return LucideIcons.bell;
    }
  }

  Color _getIconBackgroundByNotification(String type) {
    switch (type) {
      case 'booking': return const Color(0xFFEEF2FF);
      case 'review': return const Color(0xFFFFF7ED);
      case 'claim': return const Color(0xFFFEF2F2);
      case 'account': return const Color(0xFFF0FDF4);
      case 'registration': return const Color(0xFFF0F9FF);
      default: return const Color(0xFFF8FAFC);
    }
  }

  Color _getIconColorByNotification(String type) {
    switch (type) {
      case 'booking': return const Color(0xFF4F46E5);
      case 'review': return const Color(0xFFF59E0B);
      case 'claim': return const Color(0xFFEF4444);
      case 'account': return const Color(0xFF22C55E);
      case 'registration': return const Color(0xFF0EA5E9);
      default: return const Color(0xFF64748B);
    }
  }

  void _handleRedirection(BuildContext context, NotificationModel n, String role) {
    debugPrint('DEBUG: Redirection for type ${n.type} and role $role');
    
    switch (n.type) {
      case 'booking':
      case 'booking_status':
        if (role == 'Client' || role.toLowerCase() == 'client') {
          context.push('/bookings');
        } else if (role == 'Expert' || role.toLowerCase() == 'expert' || role == 'Prestataire') {
          // Si on a l'userId dans la notification, on l'utilise, sinon on redirige vers l'accueil provider
          context.push('/provider/reservations');
        }
        break;
      case 'claim':
      case 'claim_response':
        if (role == 'Admin') {
          // L'admin gère les réclams dans l'onglet reviews/claims
          context.go('/admin/reviews');
        } else if (role == 'Client' || role.toLowerCase() == 'client') {
          // Pas encore d'écran historique réclamation client, on envoie vers bookings ou home
          context.push('/bookings');
        } else if (role == 'Expert' || role.toLowerCase() == 'expert') {
          context.push('/provider/reservations');
        }
        break;
      case 'review':
        if (role == 'Expert' || role.toLowerCase() == 'expert') {
           context.push('/provider/profile');
        } else if (role == 'Admin') {
           context.go('/admin/reviews');
        }
        break;
      case 'account':
      case 'account_status':
        if (role == 'Expert' || role.toLowerCase() == 'expert' || role == 'Prestataire') {
          context.push('/provider/profile');
        }
        break;
      case 'registration':
        if (role == 'Admin') {
          context.go('/admin/providers');
        }
        break;
      default:
        // Fallback redirection logic if needed
        break;
    }
  }
}
