import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../layouts/admin_layout.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final List<Map<String, dynamic>> _notifications = [
    {'title': 'New Provider', 'msg': 'Ahmed Khalil is waiting for approval.', 'time': '5 min', 'type': 'warning'},
    {'title': 'Urgent Claim', 'msg': 'A customer reported a major delay.', 'time': '12 min', 'type': 'error'},
    {'title': 'Payment Received', 'msg': 'A new Premium plan was activated by Fatima.', 'time': '1h', 'type': 'success'},
    {'title': 'System', 'msg': 'Automatic backup completed successfully.', 'time': '3h', 'type': 'info'},
  ];

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin/notifications',
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
      height: isMobile ? 48 : 64,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
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
          const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final n = _notifications[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: _primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.bell, color: _primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n['title'], style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                      Text(n['msg'], style: const TextStyle(color: _textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Text(n['time'], style: const TextStyle(fontSize: 11, color: _textSecondary)),
              ],
            ),
          );
        },
      ),
    );
  }
}
