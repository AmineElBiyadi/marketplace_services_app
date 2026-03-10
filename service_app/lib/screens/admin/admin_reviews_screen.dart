import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getAllReviews();
      if (mounted) {
        setState(() {
          _reviews = data;
          _filtered = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin/reviews',
      child: Column(
        children: [
          _buildTopBar(isMobile),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _buildMainContent(),
          ),
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
          const Text('Avis & Réclamations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const Spacer(),
          IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 18, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border)),
        child: Column(
          children: [
            if (_filtered.isEmpty)
              const Padding(padding: EdgeInsets.all(48), child: Text('Aucun avis trouvé'))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: _border),
                itemBuilder: (context, index) {
                  final r = _filtered[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(r['subject'] ?? 'Sans sujet', style: const TextStyle(fontWeight: FontWeight.bold)),
                        _priorityBadge(r['priority']),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(r['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text('Par ${r['from']} • ${r['date']}', style: const TextStyle(fontSize: 11, color: _textSecondary)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(String p) {
    Color color = Colors.blue;
    if (p == 'Haute') color = Colors.red;
    if (p == 'Urgente') color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(p, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
