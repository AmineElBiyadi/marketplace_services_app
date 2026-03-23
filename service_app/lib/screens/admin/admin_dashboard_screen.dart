import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminDashboardService _service = AdminDashboardService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Theme Constants (Matching React Design)
  static const Color _primary = Color(0xFF3D5A99); // primary
  static const Color _accent = Color(0xFF8B5CF6); // purple
  static const Color _bg = Color(0xFFF8FAFC); // muted/30
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _destructive = Color(0xFFEF4444);

  bool _loading = true;
  String? _error;
  AdminDashboardStats? _stats;
  List<Map<String, dynamic>> _pendingProviders = [];
  List<Map<String, dynamic>> _openClaims = [];
  List<Map<String, dynamic>> _recentUsers = [];
  Map<String, int> _categoriesData = {};
  List<Map<String, dynamic>> _dailyInscriptions = [];
  List<Map<String, dynamic>> _monthlyRevenue = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getDashboardStats(),
        _service.getPendingProviders(limit: 5),
        _service.getOpenClaims(limit: 5),
        _service.getRecentUsers(limit: 5),
        _service.getReservationsByCategory(),
        _service.getDailyInscriptions(),
        _service.getMonthlyRevenue(),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as AdminDashboardStats;
          _pendingProviders = results[1] as List<Map<String, dynamic>>;
          _openClaims = results[2] as List<Map<String, dynamic>>;
          _recentUsers = results[3] as List<Map<String, dynamic>>;
          _categoriesData = results[4] as Map<String, int>;
          _dailyInscriptions = results[5] as List<Map<String, dynamic>>;
          _monthlyRevenue = results[6] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin',
      child: Column(
        children: [
          _buildTopBar(isMobile),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: _buildMainContent(),
                      ),
          ),
        ],
      ),
    );
  }

  // ─── Sidebar ───────────────────────────────────────────────────────────────
  // ─── Top Bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(LucideIcons.menu, color: _textPrimary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const Spacer(),
          const SizedBox(width: 16),
          // Notifications
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.bell, size: 20, color: _textPrimary),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(color: _destructive, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(_stats?.unreadNotifications.toString() ?? '0', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Admin Profile
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('SA', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 8),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin', style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('Super Admin', style: TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── Main Content ─────────────────────────────────────────────────────────
  Widget _buildMainContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tableau de bord', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _textPrimary)),
          const Text('Vue d\'ensemble de la plateforme', style: TextStyle(fontSize: 14, color: _textSecondary)),
          const SizedBox(height: 24),

          // KPIs
          _buildKPIGrid(),
          const SizedBox(height: 24),

          // Charts
          _buildChartsSection(),
          const SizedBox(height: 24),

          // Action Panels
          _buildActionPanels(),
        ],
      ),
    );
  }

  Widget _buildKPIGrid() {
    final s = _stats!;
    final double cancellationRate = s.totalReservations > 0 ? (s.cancelledReservations / s.totalReservations) * 100 : 0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _kpiItem('Total Clients', s.totalClients.toString(), LucideIcons.users, _primary.withOpacity(0.1), _primary, s.userGrowth),
        _kpiItem('Réservations du mois', s.reservationsThisMonth.toString(), LucideIcons.calendarDays, Colors.blue.withOpacity(0.1), Colors.blue, ''),
        _kpiItem('Revenus totaux', '${NumberFormat("#,##0", "fr_FR").format(s.totalRevenue)} DH', LucideIcons.dollarSign, Colors.green.withOpacity(0.1), Colors.green, s.revenueGrowth),
        _kpiItem('En attente', s.pendingProviders.toString(), LucideIcons.clock, Colors.amber.withOpacity(0.1), Colors.amber, ''),
        _kpiItem('Terminées', s.totalFinishedReservations.toString(), LucideIcons.checkSquare, Colors.teal.withOpacity(0.1), Colors.teal, ''),
        _kpiItem('Taux d\'annulation', '${cancellationRate.toStringAsFixed(1)}%', LucideIcons.ban, Colors.red.withOpacity(0.1), Colors.red, ''),
      ],
    );
  }

  Widget _kpiItem(String label, String value, IconData icon, Color bg, Color color, String change) {
    final width = (MediaQuery.of(context).size.width - (MediaQuery.of(context).size.width < 1024 ? 80 : 340)) / 6;
    final minWidth = 160.0;

    return Container(
      width: width < minWidth ? (MediaQuery.of(context).size.width < 600 ? 160 : 180) : width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w600)),
          if (change.isNotEmpty && change != '+0') ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(change, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Charts Section ────────────────────────────────────────────────────────
  Widget _buildChartsSection() {
    final isPageWide = MediaQuery.of(context).size.width > 1200;

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 1, child: _chartCard('Évolution des inscriptions (30j)', _buildInscriptionsChart())),
            const SizedBox(width: 24),
            if (isPageWide) Expanded(flex: 1, child: _chartCard('Réservations par catégorie', _buildCategoryChart())),
          ],
        ),
        if (!isPageWide) ...[
          const SizedBox(height: 24),
          _chartCard('Réservations par catégorie', _buildCategoryChart()),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(flex: 1, child: _chartCard('Répartition Gratuit vs Premium', _buildPackChart())),
            const SizedBox(width: 24),
            if (isPageWide) Expanded(flex: 1, child: _chartCard('Revenus mensuels', _buildRevenueChart())),
          ],
        ),
        if (!isPageWide) ...[
          const SizedBox(height: 24),
          _chartCard('Revenus mensuels', _buildRevenueChart()),
        ],
      ],
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textPrimary)),
          const SizedBox(height: 24),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildInscriptionsChart() {
    if (_dailyInscriptions.isEmpty) return _emptyState('Pas de données');
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5, getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1)),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              reservedSize: 22, 
              getTitlesWidget: (v, m) {
                if (v % 5 != 0) return const SizedBox();
                return Text('J${v.toInt()}', style: const TextStyle(fontSize: 10, color: _textSecondary));
              }
            )
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              reservedSize: 28, 
              getTitlesWidget: (v, m) {
                if (v % 2 != 0) return const SizedBox();
                return Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: _textSecondary));
              }
            )
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_dailyInscriptions.length, (i) => FlSpot(i.toDouble(), _dailyInscriptions[i]['clients'].toDouble())),
            isCurved: true,
            color: _primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: _primary.withOpacity(0.1)),
          ),
          LineChartBarData(
            spots: List.generate(_dailyInscriptions.length, (i) => FlSpot(i.toDouble(), _dailyInscriptions[i]['experts'].toDouble())),
            isCurved: true,
            color: _accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    final data = _categoriesData.entries.toList();
    data.sort((a, b) => b.value.compareTo(a.value));
    final displayData = data.take(6).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: (displayData.isEmpty ? 10 : displayData.first.value.toDouble()) + 2,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final idx = v.toInt();
                if (idx < 0 || idx >= displayData.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(displayData[idx].key, style: const TextStyle(fontSize: 9, color: _textSecondary), maxLines: 1),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(displayData.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: displayData[i].value.toDouble(), color: _primary, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
          );
        }),
      ),
    );
  }

  Widget _buildPackChart() {
    final premium = _stats?.premiumProviders.toDouble() ?? 0;
    final free = _stats?.freeProviders.toDouble() ?? 0;
    if (premium == 0 && free == 0) return _emptyState('Aucun prestataire');

    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 55,
        sections: [
          PieChartSectionData(color: _primary, value: premium, title: '${(premium/(premium+free)*100).toInt()}%', radius: 30, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          PieChartSectionData(color: _textSecondary.withOpacity(0.2), value: free, title: '${(free/(premium+free)*100).toInt()}%', radius: 30, titleStyle: const TextStyle(color: _textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    if (_monthlyRevenue.isEmpty) return _emptyState('Pas de données');
    
    double maxRev = 100;
    for (var m in _monthlyRevenue) if (m['revenue'] > maxRev) maxRev = m['revenue'].toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxRev / 4),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _monthlyRevenue.length || idx % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_monthlyRevenue[idx]['month'], style: const TextStyle(fontSize: 10, color: _textSecondary)),
                );
              },
            )
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (v, m) {
                 if (v == 0) return const SizedBox();
                 return Text('${(v/1000).toInt()}k', style: const TextStyle(fontSize: 10, color: _textSecondary));
              }
            )
          )
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_monthlyRevenue.length, (i) => FlSpot(i.toDouble(), _monthlyRevenue[i]['revenue'].toDouble())),
            isCurved: true,
            color: _primary,
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: _primary.withOpacity(0.05)),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  // ─── Action Panels ─────────────────────────────────────────────────────────
  Widget _buildActionPanels() {
    final isDesktop = MediaQuery.of(context).size.width > 1200;

    return Column(
      children: [
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _panelWrapper('Réclamations urgentes', _buildClaimsList(), '/admin/reviews')),
              const SizedBox(width: 24),
              Expanded(child: _panelWrapper('Derniers Clients', _buildUsersList(), '/admin/users')),
            ],
          )
        else ...[
          _panelWrapper('Réclamations urgentes', _buildClaimsList(), '/admin/reviews'),
          const SizedBox(height: 24),
          _panelWrapper('Derniers Clients', _buildUsersList(), '/admin/users'),
        ],
      ],
    );
  }

  Widget _panelWrapper(String title, Widget content, String path) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textPrimary)),
              TextButton(
                onPressed: () => context.go(path),
                child: const Text('Voir tout →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primary))
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    final query = _searchController.text.toLowerCase();
    final filtered = _pendingProviders.where((p) => 
      p['name'].toString().toLowerCase().contains(query) || 
      p['category'].toString().toLowerCase().contains(query)
    ).toList();

    if (filtered.isEmpty) return _emptyState('Aucun résultat');
    return Column(
      children: filtered.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(10),
                  image: p['imageUrl'] != null ? DecorationImage(image: NetworkImage(p['imageUrl']), fit: BoxFit.cover) : null,
                ),
                alignment: Alignment.center,
                child: p['imageUrl'] == null ? Text(p['avatar'], style: const TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.bold)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'] ?? 'Nom inconnu', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
                    Text('${p['category'] ?? 'Service'} • ${p['date']}', style: const TextStyle(fontSize: 10, color: _textSecondary)),
                  ],
                ),
              ),
              Row(
                children: [
                  _circleAction(LucideIcons.check, Colors.green, () async {
                    await _service.approveProvider(p['id']);
                    _loadData();
                  }),
                  const SizedBox(width: 6),
                  _circleAction(LucideIcons.x, _destructive, () async {
                    await _service.rejectProvider(p['id']);
                    _loadData();
                  }),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClaimsList() {
    final query = _searchController.text.toLowerCase();
    final filtered = _openClaims.where((c) => 
      c['subject'].toString().toLowerCase().contains(query) || 
      c['from'].toString().toLowerCase().contains(query)
    ).toList();

    if (filtered.isEmpty) return _emptyState('Aucun résultat');
    return Column(
      children: filtered.map((c) {
        final isUrgent = c['priority'].toString().toUpperCase() == 'URGENT';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['subject'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(c['from'], style: const TextStyle(fontSize: 10, color: _textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _badge(c['priority'], isUrgent ? _destructive : Colors.orange),
                  const SizedBox(height: 4),
                  _badge(c['status'], isUrgent ? _destructive : Colors.amber),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUsersList() {
    final query = _searchController.text.toLowerCase();
    final filtered = _recentUsers.where((u) => 
      u['name'].toString().toLowerCase().contains(query) || 
      u['type'].toString().toLowerCase().contains(query)
    ).toList();

    if (filtered.isEmpty) return _emptyState('Aucun résultat');
    return Column(
      children: filtered.map((u) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _bg, 
                  borderRadius: BorderRadius.circular(10),
                  image: u['imageUrl'] != null ? DecorationImage(image: NetworkImage(u['imageUrl']), fit: BoxFit.cover) : null,
                ),
                alignment: Alignment.center,
                child: u['imageUrl'] == null ? Text(u['name'].toString().length >= 2 ? u['name'].toString().substring(0, 2).toUpperCase() : '??', style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['name'] ?? 'Sans nom', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
                    Text(u['date'], style: const TextStyle(fontSize: 10, color: _textSecondary)),
                  ],
                ),
              ),
              _badge(u['type'] ?? 'Client', u['type'] == 'Prestataire' ? _accent : _primary),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _circleAction(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyState(String msg) {
    return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(msg, style: const TextStyle(fontSize: 12, color: _textSecondary))));
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.alertTriangle, size: 48, color: _destructive),
          const SizedBox(height: 16),
          const Text('Erreur de chargement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_error ?? '', style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadData, style: ElevatedButton.styleFrom(backgroundColor: _primary), child: const Text('Réessayer', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
