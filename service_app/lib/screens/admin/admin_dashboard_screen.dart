import 'package:flutter/material.dart';
import '../../services/admin_dashboard_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _accent = Color(0xFF8B5CF6);
  static const Color _bg = Color(0xFFF5F5F0);
  static const Color _card = Colors.white;

  bool _loading = true;
  String? _error;
  AdminDashboardStats? _stats;
  List<Map<String, dynamic>> _pendingProviders = [];
  List<Map<String, dynamic>> _openClaims = [];
  List<Map<String, dynamic>> _recentUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _service.getDashboardStats(),
        _service.getPendingProviders(limit: 5),
        _service.getOpenClaims(limit: 5),
        _service.getRecentUsers(limit: 5),
      ]);
      setState(() {
        _stats = results[0] as AdminDashboardStats;
        _pendingProviders = results[1] as List<Map<String, dynamic>>;
        _openClaims = results[2] as List<Map<String, dynamic>>;
        _recentUsers = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Tableau de bord Admin', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildBody(),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: _danger),
          const SizedBox(height: 16),
          const Text('Erreur de chargement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error ?? '', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final s = _stats!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── KPI CARDS ────────────────────────────────────────────────
          const Text('Vue d\'ensemble', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi('Utilisateurs', s.totalUsers, Icons.people, _primary),
              _kpi('Clients', s.totalClients, Icons.person, Colors.cyan.shade700),
              _kpi('Prestataires', s.totalProviders, Icons.handshake, _accent),
              _kpi('Réservations (mois)', s.reservationsThisMonth, Icons.calendar_today, _success),
              _kpi('En attente', s.pendingProviders, Icons.access_time, _warning),
              _kpi('Réclamations', s.openClaims, Icons.warning_amber, _danger),
              _kpiDouble('Note moyenne', s.averageRating, Icons.star, Colors.amber),
              _kpi('Premium', s.premiumProviders, Icons.workspace_premium, _accent),
              _kpi('Gratuit', s.freeProviders, Icons.card_membership, Colors.grey),
            ],
          ),
          const SizedBox(height: 28),

          // ─── PENDING PROVIDERS ────────────────────────────────────────
          _sectionHeader('Prestataires à valider', '${s.pendingProviders} en attente'),
          const SizedBox(height: 12),
          _pendingProviders.isEmpty
              ? _emptyCard('Aucun prestataire en attente ✅')
              : Column(children: _pendingProviders.map(_buildProviderTile).toList()),
          const SizedBox(height: 28),

          // ─── OPEN CLAIMS ──────────────────────────────────────────────
          _sectionHeader('Réclamations ouvertes', '${s.openClaims} réclamations'),
          const SizedBox(height: 12),
          _openClaims.isEmpty
              ? _emptyCard('Aucune réclamation ouverte ✅')
              : Column(children: _openClaims.map(_buildClaimTile).toList()),
          const SizedBox(height: 28),

          // ─── RECENT USERS ─────────────────────────────────────────────
          _sectionHeader('Dernières inscriptions', '5 derniers'),
          const SizedBox(height: 12),
          _recentUsers.isEmpty
              ? _emptyCard('Aucun utilisateur récent')
              : Column(children: _recentUsers.map(_buildUserTile).toList()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── KPI Card ─────────────────────────────────────────────────────────────
  Widget _kpi(String label, int value, IconData icon, Color color) {
    return _kpiBase(label, value.toString(), icon, color);
  }

  Widget _kpiDouble(String label, double value, IconData icon, Color color) {
    return _kpiBase(label, value.toStringAsFixed(1), icon, color);
  }

  Widget _kpiBase(String label, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text(msg, style: const TextStyle(color: Colors.grey))),
    );
  }

  // ─── Pending Provider Tile ────────────────────────────────────────────────
  Widget _buildProviderTile(Map<String, dynamic> p) {
    final avatar = p['avatar'] as String? ?? '??';
    final name = p['name'] as String? ?? '';
    final category = p['category'] as String? ?? '';
    final date = p['date'] as String? ?? '';
    final id = p['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primary.withOpacity(0.1),
          child: Text(avatar, style: const TextStyle(fontWeight: FontWeight.bold, color: _primary, fontSize: 12)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$category • $date', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: _success, size: 26),
              tooltip: 'Valider',
              onPressed: () async {
                await _service.approveProvider(id);
                _loadData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: _danger, size: 26),
              tooltip: 'Refuser',
              onPressed: () async {
                await _service.rejectProvider(id);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Claim Tile ────────────────────────────────────────────────────────────
  Widget _buildClaimTile(Map<String, dynamic> c) {
    final priority = c['priority'] as String? ?? 'Normal';
    final status = c['status'] as String? ?? '';
    final isUrgent = priority.toUpperCase().contains('URGENT');
    final priorityColor = isUrgent ? _danger : _warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(Icons.report_problem, color: priorityColor),
        title: Text(c['subject'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('De: ${c['from']}', style: const TextStyle(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: priorityColor)),
            ),
            const SizedBox(height: 4),
            Text(status, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ─── User Tile ─────────────────────────────────────────────────────────────
  Widget _buildUserTile(Map<String, dynamic> u) {
    final name = u['name'] as String? ?? '';
    final type = u['type'] as String? ?? 'Client';
    final date = u['date'] as String? ?? '';
    Color badgeColor = type == 'Prestataire' ? _accent : _primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Text(name.length >= 2 ? name.substring(0, 2).toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
        ),
      ),
    );
  }
}
