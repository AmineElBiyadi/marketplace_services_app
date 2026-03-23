import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class NotificationBell extends StatefulWidget {
  final String? idUtilisateur;
  final String? role;
  final Color color;

  const NotificationBell({
    super.key,
    this.idUtilisateur,
    this.role,
    this.color = const Color(0xFF1E293B),
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  String? _idUtilisateur;
  String? _role;

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    if (widget.idUtilisateur != null && widget.idUtilisateur!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _idUtilisateur = widget.idUtilisateur;
          _role = widget.role;
        });
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Check Admin
    final adminId = prefs.getString('logged_admin_id');
    if (adminId != null && adminId.isNotEmpty) {
      if (mounted) {
        setState(() {
          _idUtilisateur = adminId;
          _role = 'admin';
        });
      }
      return;
    }

    // Check Client
    final clientId = prefs.getString('logged_client_id') ?? FirebaseAuth.instance.currentUser?.uid;
    if (clientId != null && clientId.isNotEmpty) {
      if (mounted) {
        setState(() {
          _idUtilisateur = clientId;
          _role = 'client';
        });
      }
      return;
    }

    // Check Expert/Provider
    final expertId = FirebaseAuth.instance.currentUser?.uid;
    if (expertId != null && expertId.isNotEmpty) {
      if (mounted) {
        setState(() {
          _idUtilisateur = expertId;
          _role = 'expert';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_idUtilisateur == null) {
      return IconButton(
        icon: Icon(Icons.notifications_outlined, color: widget.color),
        onPressed: () {},
      );
    }
    
    final _service = NotificationService();

    return StreamBuilder<int>(
      stream: _service.getUnreadCount(_idUtilisateur!),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: widget.color),
              onPressed: () {
                context.push('/notifications', extra: {
                  'idUtilisateur': _idUtilisateur,
                  'role': _role,
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
