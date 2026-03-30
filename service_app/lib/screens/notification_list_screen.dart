import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../models/expert.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
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
              return _buildNotificationCard(context, n, _service, role, idUtilisateur);
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

  Widget _buildNotificationCard(BuildContext context, NotificationModel n, NotificationService _service, String role, String idUtilisateur) {
    final bool isUnread = !n.estLue;
    final timeStr = DateFormat('dd/MM HH:mm').format(n.createdAt);

    return InkWell(
      onTap: () async {
        _service.markAsRead(n.id);
        await _handleRedirection(context, n, role, idUtilisateur);
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
                    children: [
                      Expanded(
                        child: Text(
                          n.titre,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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

  Future<void> _handleRedirection(BuildContext context, NotificationModel n, String role, String idUtilisateur) async {
    debugPrint('DEBUG: Redirection for type ${n.type} and role $role');
    
    // Resolve expertId if role is Expert (needed for many paths)
    String? expertId;
    if (role == 'Expert' || role.toLowerCase() == 'expert' || role == 'Prestataire') {
      try {
        final expertSnap = await FirebaseFirestore.instance
            .collection('experts')
            .where('idUtilisateur', isEqualTo: idUtilisateur)
            .limit(1)
            .get();
        if (expertSnap.docs.isNotEmpty) {
          expertId = expertSnap.docs.first.id;
        }
      } catch (e) {
        debugPrint("Error resolving expertId: $e");
      }
    }

    if (!context.mounted) return;

    switch (n.type) {
      case 'booking':
      case 'booking_status':
        if (role == 'Client' || role.toLowerCase() == 'client') {
          if (n.relatedId != null && n.relatedId!.isNotEmpty) {
            context.push('/booking-detail/${n.relatedId}');
          } else {
            context.push('/bookings-list');
          }
        } else if (expertId != null) {
          context.push('/provider/$expertId/bookings');
        }
        break;

      case 'claim':
      case 'claim_response':
        if (role == 'Admin') {
          context.go('/admin/reviews');
        } else if (role == 'Client' || role.toLowerCase() == 'client') {
          context.push('/reclamations');
        } else if (expertId != null) {
          context.push('/provider/$expertId/profile/reclamations');
        }
        break;

      case 'review':
        if (role == 'Expert' || role.toLowerCase() == 'expert') {
           if (expertId != null) {
             final fs = FirestoreService();
             final expert = await fs.getExpertDetailed(expertId);
             if (expert != null && context.mounted) {
               context.push('/experts/$expertId', extra: expert);
             } else if (context.mounted) {
               context.push('/provider/profile');
             }
           } else {
             context.push('/provider/profile');
           }
        } else if (role == 'Admin') {
           context.go('/admin/reviews');
        } else if (role == 'Client' || role.toLowerCase() == 'client') {
           context.push('/my-reviews');
        }
        break;

      case 'account':
      case 'account_status':
        if (expertId != null) {
          context.push('/provider/$expertId/profile');
        } else if (role == 'Expert' || role.toLowerCase() == 'expert' || role == 'Prestataire') {
          context.push('/provider/profile');
        }
        break;

      case 'registration':
        if (role == 'Admin') {
          context.go('/admin/providers');
        }
        break;

      default:
        // No redirection for unknown types
        break;
    }
  }
}
