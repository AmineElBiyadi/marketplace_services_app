import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

import '../../services/admin_dashboard_service.dart';
import '../../utils/admin_export_util.dart';
import 'package:intl/intl.dart';

class AdminFinancesScreen extends StatefulWidget {
  const AdminFinancesScreen({super.key});

  @override
  State<AdminFinancesScreen> createState() => _AdminFinancesScreenState();
}

class _AdminFinancesScreenState extends State<AdminFinancesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminDashboardService _dashboardService = AdminDashboardService();

  bool _isLoading = true;
  String _premiumPriceInput = "99";
  bool _isUpdatingPrice = false;
  double _totalRevenue = 0.0;
  int _premiumCount = 0;
  int _graceCount = 0;
  double _currentMonthRevenue = 0.0;

  List<Map<String, dynamic>> _revenueData = [];
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _failedPayments = [];

  static const List<String> _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  String get _currentMonthName => _monthNames[DateTime.now().month - 1];

  List<Map<String, dynamic>> get kpis => [
    {
      'label': "Revenus totaux",
      'value': "${_totalRevenue.toInt()} DH",
      'icon': LucideIcons.dollarSign,
      'colorBg': const Color(0xFFF0FDF4),
      'colorFg': const Color(0xFF16A34A),
    },
    {
      'label': "Experts Premium",
      'value': "$_premiumCount",
      'icon': LucideIcons.crown,
      'colorBg': const Color(0xFFFEF9C3),
      'colorFg': const Color(0xFFCA8A04),
    },
    {
      'label': "Revenus $_currentMonthName",
      'value': "${_currentMonthRevenue.toInt()} DH",
      'icon': LucideIcons.creditCard,
      'colorBg': const Color(0xFFEFF6FF),
      'colorFg': const Color(0xFF2563EB),
    },
    {
      'label': "Impayés (Grâce)",
      'value': "$_graceCount",
      'icon': LucideIcons.alertTriangle,
      'colorBg': const Color(0xFFFEF2F2),
      'colorFg': const Color(0xFFEF4444),
    },
  ];

  static const Color _chartYellowStart = Color(0xFFFACC15);
  static const Color _chartYellowEnd = Color(0xFFEAB308);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _dashboardService.getDashboardStats(),
        _dashboardService.getMonthlyRevenue(),
        _dashboardService.getFinancialTransactions(),
        _dashboardService.getGraceSubscriptions(),
      ]);

      final stats = results[0] as AdminDashboardStats;
      final monthlyRev = (results[1] as List).cast<Map<String, dynamic>>();
      final transactions = (results[2] as List).cast<Map<String, dynamic>>();
      final graceList = (results[3] as List).cast<Map<String, dynamic>>();

      final last6Months = monthlyRev.length > 6
          ? monthlyRev.sublist(monthlyRev.length - 6)
          : monthlyRev;

      double currentPackRev = 0;
      if (last6Months.isNotEmpty) {
        currentPackRev = (last6Months.last['revenue'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _totalRevenue = stats.totalRevenue;
          _premiumCount = stats.premiumProviders;
          _graceCount = graceList.length;
          _currentMonthRevenue = currentPackRev;

          _revenueData = last6Months.map((e) => {
            'month': e['month'],
            'abonnements': (e['revenue'] as num).toDouble(),
          }).toList();

          // All subscriptions (ACTIVE) for the main table (Wait, the data comes mapped, I filter for 'Actif')
          final allSubsMapped = transactions.map((t) => {
            'id': t['id'] ?? '',
            'provider': t['expertName'] ?? 'Prestataire',
            'pack': t['pack'] ?? 'Premium',
            'start': t['date'] ?? 'N/A',
            'renewal': t['renewal'] ?? 'Auto',
            'amount': '${t['amount']} DH',
            'status': t['status'] ?? 'Actif',
          }).toList();

          _subscriptions = allSubsMapped.where((s) => s['status'] == 'Actif').toList();
          _failedPayments = graceList; // This now contains GRACE and SUSPENDED from the service using whereIn

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading finance data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;    // Téléphone: < 768px
    final bool isTablet = screenWidth >= 768 && screenWidth < 1024; // Tablette: 768-1023px
    
    // Debug pour voir les données et le type d'appareil
    debugPrint('=== FINANCE SCREEN DEBUG ===');
    debugPrint('screenWidth: $screenWidth');
    debugPrint('isMobile: $isMobile');
    debugPrint('isTablet: $isTablet');
    debugPrint('_isLoading: $_isLoading');
    debugPrint('_revenueData length: ${_revenueData.length}');
    debugPrint('_subscriptions length: ${_subscriptions.length}');
    debugPrint('_failedPayments length: ${_failedPayments.length}');
    debugPrint('_totalRevenue: $_totalRevenue');
    debugPrint('==========================');
    
    return AdminLayout(
      activeRoute: '/admin/finances',
      child: Column(
        children: [
          _buildTopBar(isMobile),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.foreground))
                : _revenueData.isEmpty && _subscriptions.isEmpty && _failedPayments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.alertCircle, size: 64, color: AppColors.mutedForeground),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune donnée disponible',
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Veuillez vérifier votre connexion ou réessayer plus tard.',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: AppColors.mutedForeground,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(LucideIcons.refreshCw),
                              label: Text('Actualiser'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 16 : 24, 
                                  vertical: isMobile ? 10 : 12
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 12.0 : isTablet ? 16.0 : 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildKPIGrid(),
                              SizedBox(height: isMobile ? 20 : isTablet ? 24 : 32),
                              _buildPremiumPricingCard(),
                              SizedBox(height: isMobile ? 20 : isTablet ? 24 : 32),
                              if (_revenueData.isNotEmpty) ...[
                                _buildChartCard(),
                                SizedBox(height: isMobile ? 20 : isTablet ? 24 : 32),
                              ],
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: _buildTabsIndicator(),
                              ),
                              const SizedBox(height: 16),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _tabController.index == 0
                                    ? KeyedSubtree(
                                        key: const ValueKey('tab0'),
                                        child: _buildSubscriptionsTable(),
                                      )
                                    : KeyedSubtree(
                                        key: const ValueKey('tab1'),
                                        child: _buildFailedPaymentsTable(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(LucideIcons.menu, color: AppColors.foreground),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Expanded(
            child: Text(
              'Finances', 
              style: TextStyle(
                fontSize: isMobile ? 16 : 18, 
                fontWeight: FontWeight.bold, 
                color: AppColors.foreground
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _exportFinances,
                icon: const Icon(LucideIcons.fileText, size: 14),
                label: const Text('Exporter PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.foreground,
                  foregroundColor: AppColors.card,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.mutedForeground)),
          ] else ...[
            IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.mutedForeground)),
            IconButton(
              onPressed: _exportFinances,
              icon: const Icon(LucideIcons.fileText, size: 18, color: AppColors.foreground),
            ),
          ],
        ],
      ),
    );
  }

  void _exportFinances() async {
    final bool isAbonnements = _tabController.index == 0;
    
    final List<String> headers = isAbonnements 
        ? ['Prestataire', 'Pack', 'Début', 'Renouvellement', 'Montant', 'Statut']
        : ['Prestataire', 'Montant', 'Date Échec', 'Tentatives'];

    final List<List<dynamic>> rows = isAbonnements
        ? _subscriptions.map((s) => [
            s['provider'], s['pack'], s['start'], s['renewal'], s['amount'], s['status']
          ]).toList()
        : _failedPayments.map((f) => [
            f['provider'], f['amount'], f['date'], f['attempts']
          ]).toList();

    await AdminExportUtil.exportPageToPdf(
      filename: isAbonnements ? 'abonnements_presto' : 'impayes_presto',
      title: isAbonnements ? 'Rapport des Abonnements' : 'Rapport des Impayés',
      subtitle: isAbonnements 
          ? 'Liste des experts avec un abonnement actif'
          : 'Liste des paiements en échec ou en période de grâce',
      kpis: [
        {'label': 'Revenu Total', 'value': '${_totalRevenue.toInt()} DH'},
        {'label': 'Experts Premium', 'value': '$_premiumCount'},
        {'label': 'Revenu Mois', 'value': '${_currentMonthRevenue.toInt()} DH'},
        {'label': 'Impayés', 'value': '$_graceCount'},
      ],
      tableHeaders: headers,
      tableRows: rows,
    );
  }

  // ── KPI GRID ─────────────────────────────────────────────────────────────────
  Widget _buildKPIGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      int cols = constraints.maxWidth >= 1024
          ? 4
          : constraints.maxWidth >= 640
              ? 2
              : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth >= 1024 ? 2.8 : 3.2,
        ),
        itemCount: kpis.length,
        itemBuilder: (context, i) {
          final kpi = kpis[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: kpi['colorBg'],
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(kpi['icon'], color: kpi['colorFg'], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(kpi['label'],
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                              letterSpacing: 0.2),
                          maxLines: 1),
                      const SizedBox(height: 2),
                      Text(kpi['value'],
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  // ── CHART ────────────────────────────────────────────────────────────────────
  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: const Text('Performance Mensuelle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                        letterSpacing: -0.2)),
              ),
              const SizedBox(width: 10),
              Flexible(child: _buildLegendRow()),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10000,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: AppColors.foreground,
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${_revenueData[groupIndex]['month']}\n',
                        const TextStyle(color: Colors.white70, fontSize: 11),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} DH',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= _revenueData.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 14.0),
                          child: Text(_revenueData[value.toInt()]['month'],
                              style: const TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value % 2500 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Text('${(value / 1000).toInt()}k',
                              style: const TextStyle(
                                  color: AppColors.border,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.border.withOpacity(0.3), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _revenueData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value['abonnements'],
                        gradient: const LinearGradient(
                            colors: [_chartYellowStart, _chartYellowEnd],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter),
                        width: 32,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow() {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_chartYellowStart, _chartYellowEnd]),
                borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Flexible(
          child: Text('Abonnements Premium',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ── TAB BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTabsIndicator() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;    // Téléphone: < 768px
    final bool isTablet = screenWidth >= 768 && screenWidth < 1024; // Tablette: 768-1023px
    
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            index: 0,
            controller: _tabController,
            icon: LucideIcons.checkCircle,
            label: isMobile ? 'Abonn.' : (isTablet ? 'Abonnements' : 'Abonnements'),
            count: _subscriptions.length,
            activeColor: AppColors.primary,
            activeBg: AppColors.primary.withOpacity(0.1),
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabButton(
            index: 1,
            controller: _tabController,
            icon: LucideIcons.alertTriangle,
            label: isMobile ? 'Suspendus' : (isTablet ? 'Abonnements Suspendus' : 'Abonnements Suspendus'),
            count: _failedPayments.length,
            activeColor: Colors.orange,
            activeBg: Colors.orange.withOpacity(0.1),
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionsTable() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;    // Téléphone: < 768px
    final bool isTablet = screenWidth >= 768 && screenWidth < 1024; // Tablette: 768-1023px
    
    return _TableShell(
      columnWidths: isMobile ? {
        0: FlexColumnWidth(1.5),  // Prestataire plus petit
        1: FlexColumnWidth(0.8),  // Pack plus petit
        2: FlexColumnWidth(0.8),  // Début plus petit
        3: FlexColumnWidth(1.0),  // Renouvellement plus petit
        4: FlexColumnWidth(0.7),  // Montant plus petit
        5: FlexColumnWidth(0.7),  // Statut plus petit
      } : isTablet ? {
        0: FlexColumnWidth(1.8),
        1: FlexColumnWidth(1.0),
        2: FlexColumnWidth(1.0),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(0.8),
        5: FlexColumnWidth(0.8),
      } : const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.6),
        4: FlexColumnWidth(1.0),
        5: FlexColumnWidth(1.1),
      },
      headerLabels: const [
        'PRESTATAIRE', 'PACK', 'DÉBUT', 'RENOUVELLEMENT', 'MONTANT', 'STATUT',
      ],
      dataRows: _subscriptions.asMap().entries.map((e) {
        final s = e.value;
        return _TableRowData(
          isEven: e.key.isEven,
          cells: [
            Row(children: [
              _Avatar(name: s['provider'], size: isMobile ? 24 : (isTablet ? 28 : 32)),
              SizedBox(width: isMobile ? 6 : (isTablet ? 8 : 10)),
              Flexible(
                child: Text(s['provider'],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                        fontSize: isMobile ? 12 : (isTablet ? 13 : 14))),
              ),
            ]),
            _PackBadge(label: s['pack'], isMobile: isMobile),
            Text(s['start'],
                style: TextStyle(
                    color: AppColors.mutedForeground, 
                    fontSize: isMobile ? 11 : (isTablet ? 12 : 13))),
            Row(children: [
              Icon(LucideIcons.refreshCw,
                  size: isMobile ? 10 : (isTablet ? 11 : 12), color: AppColors.mutedForeground),
              SizedBox(width: isMobile ? 3 : (isTablet ? 4 : 5)),
              Flexible(
                child: Text(s['renewal'],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.mutedForeground, 
                        fontSize: isMobile ? 11 : (isTablet ? 12 : 13))),
              ),
            ]),
            Text(s['amount'],
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                    fontSize: isMobile ? 12 : (isTablet ? 13 : 14))),
            _StatusChip(status: s['status'], isMobile: isMobile),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFailedPaymentsTable() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;    // Téléphone: < 768px
    final bool isTablet = screenWidth >= 768 && screenWidth < 1024; // Tablette: 768-1023px
    
    if (_failedPayments.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isMobile ? 30 : 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 48 : 56,
                height: isMobile ? 48 : 56,
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(LucideIcons.checkCircle2,
                    color: Color(0xFF16A34A), size: isMobile ? 24 : 28),
              ),
              SizedBox(height: isMobile ? 10 : 12),
              Text('Aucun paiement échoué',
                  style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return _TableShell(
      columnWidths: isMobile ? {
        0: FlexColumnWidth(1.4),  // Prestataire plus petit
        1: FlexColumnWidth(0.8),  // Montant plus petit
        2: FlexColumnWidth(0.9),  // Date plus petit
        3: FlexColumnWidth(0.7),  // Tentatives plus petit
        4: FlexColumnWidth(1.2),  // Actions plus petit
      } : isTablet ? {
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(1.0),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(0.8),
        4: FlexColumnWidth(1.5),
      } : const {
        0: FlexColumnWidth(2.0),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(2.0),
      },
      headerLabels: const [
        'PRESTATAIRE', 'MONTANT', 'DATE ÉCHEC', 'TENTATIVES', 'ACTIONS',
      ],
      dataRows: _failedPayments.asMap().entries.map((e) {
        final f = e.value;
        final subId = f['id'] as String? ?? '';
        return _TableRowData(
          isEven: e.key.isEven,
          cells: [
            Row(children: [
              _Avatar(name: f['provider'] ?? 'Expert', danger: true, size: isMobile ? 24 : (isTablet ? 28 : 32)),
              SizedBox(width: isMobile ? 6 : (isTablet ? 8 : 10)),
              Flexible(
                child: Text(f['provider'] ?? 'Expert',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                        fontSize: isMobile ? 12 : (isTablet ? 13 : 14))),
              ),
            ]),
            Text(f['amount'] ?? '--',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                    fontSize: isMobile ? 12 : (isTablet ? 13 : 14))),
            Text(f['date'] ?? '--',
                style: TextStyle(
                    color: AppColors.mutedForeground, 
                    fontSize: isMobile ? 11 : (isTablet ? 12 : 13))),
            _AttemptsIndicator(count: (f['attempts'] as int?) ?? 1, isMobile: isMobile),
            if (isMobile)
              // Mobile: Boutons verticaux pour économiser de l'espace
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    label: 'Relancer',
                    icon: LucideIcons.refreshCw,
                    color: AppColors.primary,
                    bg: const Color(0xFFEFF6FF),
                    onTap: () => _confirmReactivate(subId),
                    isMobile: true,
                  ),
                  SizedBox(height: 4),
                  _ActionButton(
                    label: 'Suspendre',
                    icon: LucideIcons.ban,
                    color: AppColors.destructive,
                    bg: const Color(0xFFFEF2F2),
                    onTap: () => _confirmSuspend(subId),
                    isMobile: true,
                  ),
                ],
              )
            else
              // Desktop: Boutons horizontaux
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(children: [
                  _ActionButton(
                    label: 'Relancer',
                    icon: LucideIcons.refreshCw,
                    color: AppColors.primary,
                    bg: const Color(0xFFEFF6FF),
                    onTap: () => _confirmReactivate(subId),
                  ),
                  SizedBox(width: 8),
                  _ActionButton(
                    label: 'Suspendre',
                    icon: LucideIcons.ban,
                    color: AppColors.destructive,
                    bg: const Color(0xFFFEF2F2),
                    onTap: () => _confirmSuspend(subId),
                  ),
                ]),
              ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _confirmReactivate(String subscriptionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Relancer l\'abonnement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
            'Souhaitez-vous réactiver cet abonnement et restaurer l\'accès Premium ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Relancer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _dashboardService.reactivateSubscription(subscriptionId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Abonnement relancé avec succès.'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmSuspend(String subscriptionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Suspendre l\'abonnement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
            'Souhaitez-vous suspendre définitivement cet abonnement ? L\'accès Premium sera coupé immédiatement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive,
                foregroundColor: Colors.white),
            child: const Text('Suspendre'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _dashboardService.suspendSubscription(subscriptionId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Abonnement suspendu.'),
                backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ── PREMIUM PRICING SETTINGS ────────────────────────────────────────────────

  Widget _buildPremiumPricingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configuration du Pack Premium',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                  letterSpacing: -0.2)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prix Premium mensuel (DH)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedForeground,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _premiumPriceInput,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _premiumPriceInput = v,
                      style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        fillColor: AppColors.muted.withOpacity(0.1),
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingPrice ? null : _updatePremiumPrice,
                    icon: _isUpdatingPrice 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.save, size: 14),
                    label: const Text('Sauvegarder et Appliquer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.foreground,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Attention : la modification du prix mettra à jour le montant de tous les abonnements existants.',
              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Future<void> _updatePremiumPrice() async {
    final double? newPrice = double.tryParse(_premiumPriceInput);
    if (newPrice == null || newPrice <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer un prix valide.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmation de mise à jour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Êtes-vous sûr de vouloir appliquer le prix de ${newPrice.toStringAsFixed(2)} DH à tous les abonnements ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) {
      setState(() { _isUpdatingPrice = true; });
    }

    try {
      await _dashboardService.updateAllSubscriptionsPrice(newPrice);
      await _loadData(); // reload the UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prix mis à jour avec succès pour tous les abonnements.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isUpdatingPrice = false; });
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TABLE — Flutter native Table fills 100% width automatically via FlexColumnWidth
// ══════════════════════════════════════════════════════════════════════════════

class _TableRowData {
  final List<Widget> cells;
  final bool isEven;
  const _TableRowData({required this.cells, required this.isEven});
}

class _TableShell extends StatelessWidget {
  final Map<int, TableColumnWidth> columnWidths;
  final List<String> headerLabels;
  final List<_TableRowData> dataRows;

  const _TableShell({
    required this.columnWidths,
    required this.headerLabels,
    required this.dataRows,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    final bool isTablet = screenWidth >= 768 && screenWidth < 1024;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 6))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, constraints) {
        final minW = constraints.maxWidth > 0 ? constraints.maxWidth : 800.0;
        
        // Adjust column widths for mobile
        Map<int, TableColumnWidth> responsiveColumnWidths = {};
        if (isMobile) {
          // Mobile: Simplified layout with fewer columns
          responsiveColumnWidths = columnWidths.map((key, value) {
            switch (key) {
              case 0: return MapEntry(key, const FlexColumnWidth(3.0)); // Provider
              case 1: return MapEntry(key, const FlexColumnWidth(1.5)); // Pack/Amount
              case 2: return MapEntry(key, const FlexColumnWidth(1.2)); // Start/Date
              case 3: return MapEntry(key, const FlexColumnWidth(1.0)); // Renewal/Attempts
              case 4: return MapEntry(key, const FlexColumnWidth(0.8)); // Amount/Actions
              default: return MapEntry(key, value);
            }
          });
        } else if (isTablet) {
          // Tablet: Medium layout
          responsiveColumnWidths = columnWidths.map((key, value) {
            switch (key) {
              case 0: return MapEntry(key, const FlexColumnWidth(2.5));
              case 1: return MapEntry(key, const FlexColumnWidth(1.2));
              case 2: return MapEntry(key, const FlexColumnWidth(1.1));
              case 3: return MapEntry(key, const FlexColumnWidth(1.3));
              case 4: return MapEntry(key, const FlexColumnWidth(0.9));
              default: return MapEntry(key, value);
            }
          });
        } else {
          responsiveColumnWidths = columnWidths;
        }
        
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minW),
            child: Table(
              columnWidths: responsiveColumnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                // ── Header row
                TableRow(
                  decoration: BoxDecoration(
                    color: AppColors.muted.withOpacity(0.35),
                  ),
                  children: headerLabels
                      .map((label) => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 16, 
                              vertical: isMobile ? 10 : 14
                            ),
                            child: Text(
                              isMobile ? _shortenLabel(label) : label,
                              style: TextStyle(
                                  fontSize: isMobile ? 10 : 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.mutedForeground,
                                  letterSpacing: 0.7),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                ),
                // ── Data rows
                ...dataRows.map((row) => TableRow(
                      decoration: BoxDecoration(
                        color: row.isEven
                            ? Colors.transparent
                            : AppColors.muted.withOpacity(0.10),
                        border: Border(
                          bottom: BorderSide(
                              color: AppColors.border.withOpacity(0.35), width: 1),
                        ),
                      ),
                      children: row.cells
                          .map((cell) => Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 8 : 16, 
                                  vertical: isMobile ? 10 : 14
                                ),
                                child: cell,
                              ))
                          .toList(),
                    )),
              ],
            ),
          ),
        );
      }),
    );
  }
  
  String _shortenLabel(String label) {
    switch (label) {
      case 'PRESTATAIRE': return 'PREST.';
      case 'PACK': return 'PACK';
      case 'DÉBUT': return 'DÉBUT';
      case 'RENOUVELLEMENT': return 'RENOUV.';
      case 'MONTANT': return 'MONTANT';
      case 'STATUT': return 'STATUT';
      case 'DATE ÉCHEC': return 'DATE';
      case 'TENTATIVES': return 'TENT.';
      case 'ACTIONS': return 'ACT.';
      default: return label;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String name;
  final bool danger;
  final double size;
  final bool isMobile;
  const _Avatar({required this.name, this.danger = false, this.size = 32, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(size * 0.3125),
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              fontSize: size * 0.40625,
              fontWeight: FontWeight.w800,
              color: danger ? const Color(0xFFDC2626) : const Color(0xFF2563EB))),
    );
  }
}

class _PackBadge extends StatelessWidget {
  final String label;
  final bool isMobile;
  const _PackBadge({required this.label, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 4 : 6),
        decoration: BoxDecoration(
            color: const Color(0xFFFEF9C3).withOpacity(0.6),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFFEF08A))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.crown, size: isMobile ? 10 : 12, color: Color(0xFFCA8A04)),
            SizedBox(width: isMobile ? 4 : 6),
            Text(label,
                style: TextStyle(
                    fontSize: isMobile ? 9 : 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFCA8A04),
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isMobile;
  const _StatusChip({required this.status, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    // Determine color set based on status
    Color bg;
    Color dot;
    Color text;
    if (status == 'Actif') {
      bg = const Color(0xFFDCFCE7);
      dot = const Color(0xFF16A34A);
      text = const Color(0xFF166534);
    } else if (status == 'Grâce') {
      bg = const Color(0xFFFEF3C7);
      dot = const Color(0xFFD97706);
      text = const Color(0xFF92400E);
    } else {
      // Suspendu / Annulé / Expiré
      bg = const Color(0xFFFEE2E2);
      dot = const Color(0xFFDC2626);
      text = const Color(0xFF991B1B);
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: isMobile ? 4 : 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(25)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 4 : 6,
              height: isMobile ? 4 : 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
            ),
            SizedBox(width: isMobile ? 4 : 6),
            Text(status,
                style: TextStyle(
                    fontSize: isMobile ? 9 : 11, 
                    fontWeight: FontWeight.w800, 
                    color: text)),
          ],
        ),
      ),
    );
  }
}

class _AttemptsIndicator extends StatelessWidget {
  final int count;
  final bool isMobile;
  const _AttemptsIndicator({required this.count, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          3,
          (i) => Container(
            width: isMobile ? 6 : 10,
            height: isMobile ? 6 : 10,
            margin: EdgeInsets.only(right: isMobile ? 2 : 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count
                  ? const Color(0xFFEF4444)
                  : AppColors.border.withOpacity(0.4),
            ),
          ),
        ),
        SizedBox(width: isMobile ? 4 : 6),
        Text('$count/3',
            style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEF4444))),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  final bool isMobile;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: isMobile ? 4 : 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isMobile ? 10 : 12, color: color),
            SizedBox(width: isMobile ? 3 : 5),
            Text(label,
                style: TextStyle(
                    fontSize: isMobile ? 10 : 12, 
                    fontWeight: FontWeight.w700, 
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CUSTOM TAB BUTTON
// ════════════════════════════════════════════════════════════════════════

class _TabButton extends StatelessWidget {
  final int index;
  final TabController controller;
  final IconData icon;
  final String label;
  final int count;
  final Color activeColor;
  final Color activeBg;
  final bool isMobile;

  const _TabButton({
    required this.index,
    required this.controller,
    required this.icon,
    required this.label,
    required this.count,
    required this.activeColor,
    required this.activeBg,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.index == index;
    return GestureDetector(
      onTap: () => controller.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor.withOpacity(0.3)
                : AppColors.border.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: isSelected ? activeColor : AppColors.mutedForeground),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        isSelected ? activeColor : AppColors.mutedForeground)),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : AppColors.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : AppColors.mutedForeground)),
            ),
          ],
        ),
      ),
    );
  }
}
