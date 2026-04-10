import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

import '../../services/admin_dashboard_service.dart';
import '../../utils/admin_export_util.dart';

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
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String get _currentMonthName => _monthNames[DateTime.now().month - 1];

  List<Map<String, dynamic>> get kpis => [
    {
      'label': "Total Revenue",
      'value': "${_totalRevenue.toInt()} DH",
      'icon': LucideIcons.dollarSign,
      'colorBg': const Color(0xFFF0FDF4),
      'colorFg': const Color(0xFF16A34A),
    },
    {
      'label': "Premium Providers",
      'value': "$_premiumCount",
      'icon': LucideIcons.crown,
      'colorBg': const Color(0xFFFEF9C3),
      'colorFg': const Color(0xFFCA8A04),
    },
    {
      'label': "Revenue $_currentMonthName",
      'value': "${_currentMonthRevenue.toInt()} DH",
      'icon': LucideIcons.creditCard,
      'colorBg': const Color(0xFFEFF6FF),
      'colorFg': const Color(0xFF2563EB),
    },
    {
      'label': "Unpaid (Grace)",
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

          // All subscriptions (ACTIVE) for the main table
          final allSubsMapped = transactions.map((t) => {
            'id': t['id'] ?? '',
            'provider': t['expertName'] ?? 'Provider',
            'pack': t['pack'] ?? 'Premium',
            'start': t['date'] ?? 'N/A',
            'renewal': t['renewal'] ?? 'Auto',
            'amount': '${t['amount']} DH',
            'status': t['status'] ?? 'Active',
          }).toList();

          _subscriptions = allSubsMapped.where((s) => s['status'] == 'Active' || s['status'] == 'Actif').toList();
          _failedPayments = graceList; // This now contains GRACE and SUSPENDED from the service using whereIn

          _failedPayments = graceList;
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    final bool isTablet = screenWidth >= 768 && screenWidth < 1024;
    final bool isDesktop = screenWidth >= 1024;
    
    // Debug for finance screen
    debugPrint('=== FINANCE SCREEN DEBUG ===');
    debugPrint('screenWidth: $screenWidth');
    debugPrint('isMobile: $isMobile');
    debugPrint('isTablet: $isTablet');
    debugPrint('isDesktop: $isDesktop');
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
          _buildTopBar(isMobile, isTablet),
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
                              'No data available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check your connection or try again later.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.mutedForeground,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(LucideIcons.refreshCw),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12.0 : isTablet ? 18.0 : 24.0,
                            vertical: isMobile ? 12.0 : 18.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildKPIGrid(),
                              const SizedBox(height: 32),
                              _buildPremiumPricingCard(),
                              const SizedBox(height: 32),
                              if (_revenueData.isNotEmpty) ...[
                                _buildChartCard(),
                                const SizedBox(height: 32),
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
  Widget _buildTopBar(bool isMobile, bool isTablet) {
    final bool showDrawerButton = isMobile || isTablet;
    return Container(
      height: isMobile ? 48 : 64,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          if (showDrawerButton)
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
                label: const Text('Export PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        ? ['Provider', 'Pack', 'Start', 'Renewal', 'Amount', 'Status']
        : ['Provider', 'Amount', 'Failure Date', 'Attempts'];

    final List<List<dynamic>> rows = isAbonnements
        ? _subscriptions.map((s) => [
            s['provider'], s['pack'], s['start'], s['renewal'], s['amount'], s['status']
          ]).toList()
        : _failedPayments.map((f) => [
            f['provider'], f['amount'], f['date'], f['attempts']
          ]).toList();

    await AdminExportUtil.exportPageToPdf(
      filename: isAbonnements ? 'subscriptions_presto' : 'unpaid_presto',
      title: isAbonnements ? 'Subscription Report' : 'Unpaid Report',
      subtitle: isAbonnements 
          ? 'List of providers with an active subscription'
          : 'List of failed payments or grace period subscriptions',
      kpis: [
        {'label': 'Total Revenue', 'value': '${_totalRevenue.toInt()} DH'},
        {'label': 'Premium Providers', 'value': '$_premiumCount'},
        {'label': 'Monthly Revenue', 'value': '${_currentMonthRevenue.toInt()} DH'},
        {'label': 'Unpaid', 'value': '$_graceCount'},
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
          LayoutBuilder(builder: (context, headerConstraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final bool isMobile = screenWidth < 768;
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: isMobile ? headerConstraints.maxWidth * 0.55 : headerConstraints.maxWidth * 0.65,
                  child: const Text('Monthly Performance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                          letterSpacing: -0.2)),
                ),
                _buildLegendRow(),
              ],
            );
          }),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (context, chartConstraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final chartHeight = screenWidth < 768 ? 220.0 : screenWidth < 1024 ? 260.0 : 300.0;
            return SizedBox(
              height: chartHeight,
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
          );
        }),
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
          child: Text('Premium Subscriptions',
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
    final isMobile = screenWidth < 768;
    
    return Row(
      children: [
        _TabButton(
          index: 0,
          controller: _tabController,
          icon: LucideIcons.checkCircle,
          label: isMobile ? 'Subs.' : 'Subscriptions',
          count: _subscriptions.length,
          activeColor: AppColors.primary,
          activeBg: AppColors.primary.withOpacity(0.1),
          isMobile: isMobile,
        ),
        SizedBox(width: isMobile ? 4 : 8),
        _TabButton(
          index: 1,
          controller: _tabController,
          icon: LucideIcons.alertTriangle,
          label: isMobile ? 'Suspended' : 'Suspended Subscriptions',
          count: _failedPayments.length,
          activeColor: Colors.orange,
          activeBg: Colors.orange.withOpacity(0.1),
          isMobile: isMobile,
        ),
      ],
    );
  }

  // ── SUBSCRIPTIONS TABLE ──────────────────────────────────────────────────────
  Widget _buildSubscriptionsTable() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    if (isMobile) {
      return Column(
        children: _subscriptions.asMap().entries.map((e) {
          final s = e.value;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Avatar(name: s['provider']),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s['provider'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                              fontSize: 15)),
                    ),
                    const SizedBox(width: 12),
                    _StatusChip(status: s['status']),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PackBadge(label: s['pack']),
                    _InfoPill(icon: LucideIcons.calendarDays, label: s['start']),
                    _InfoPill(icon: LucideIcons.refreshCcw, label: s['renewal']),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s['amount'],
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.foreground,
                            fontSize: 16)),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return _TableShell(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.6),
        4: FlexColumnWidth(1.0),
        5: FlexColumnWidth(1.1),
      },
      headerLabels: const [
        'PROVIDER', 'PACK', 'START', 'RENEWAL', 'AMOUNT', 'STATUS',
      ],
      dataRows: _subscriptions.asMap().entries.map((e) {
        final s = e.value;
        return _TableRowData(
          isEven: e.key.isEven,
          cells: [
            Row(children: [
              _Avatar(name: s['provider']),
              const SizedBox(width: 10),
              Flexible(
                child: Text(s['provider'],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                        fontSize: 14)),
              ),
            ]),
            _PackBadge(label: s['pack']),
            Text(s['start'],
                style: const TextStyle(
                    color: AppColors.mutedForeground, fontSize: 13)),
            Row(children: [
              const Icon(LucideIcons.refreshCw,
                  size: 12, color: AppColors.mutedForeground),
              const SizedBox(width: 5),
              Flexible(
                child: Text(s['renewal'],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.mutedForeground, fontSize: 13)),
              ),
            ]),
            Text(s['amount'],
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                    fontSize: 14)),
            _StatusChip(status: s['status']),
          ],
        );
      }).toList(),
    );
  }

  // ── FAILED PAYMENTS TABLE ────────────────────────────────────────────────────
  Widget _buildFailedPaymentsTable() {
    if (_failedPayments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16)),
                child: const Icon(LucideIcons.checkCircle2,
                    color: Color(0xFF16A34A), size: 28),
              ),
              const SizedBox(height: 12),
              const Text('No failed payments found',
                  style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    if (isMobile) {
      return Column(
        children: _failedPayments.asMap().entries.map((e) {
          final f = e.value;
          final subId = f['id'] as String? ?? '';
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Avatar(name: f['provider'] ?? 'Expert', danger: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(f['provider'] ?? 'Expert',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                              fontSize: 15)),
                    ),
                    const SizedBox(width: 12),
                    Text(f['amount'] ?? '--',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.foreground,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(icon: LucideIcons.calendarDays, label: f['date'] ?? '--'),
                    _AttemptsIndicator(count: (f['attempts'] as int?) ?? 1),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ActionButton(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      color: AppColors.primary,
                      bg: const Color(0xFFEFF6FF),
                      onTap: () => _confirmReactivate(subId),
                    ),
                    const SizedBox(width: 10),
                    _ActionButton(
                      label: 'Suspend',
                      icon: LucideIcons.ban,
                      color: AppColors.destructive,
                      bg: const Color(0xFFFEF2F2),
                      onTap: () => _confirmSuspend(subId),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return _TableShell(
      columnWidths: const {
        0: FlexColumnWidth(2.0),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(2.0),
      },
      headerLabels: const [
        'PROVIDER', 'AMOUNT', 'FAILED DATE', 'ATTEMPTS', 'ACTIONS',
      ],
      dataRows: _failedPayments.asMap().entries.map((e) {
        final f = e.value;
        final subId = f['id'] as String? ?? '';
        return _TableRowData(
          isEven: e.key.isEven,
          cells: [
            Row(children: [
              _Avatar(name: f['provider'] ?? 'Expert', danger: true),
              const SizedBox(width: 10),
              Flexible(
                child: Text(f['provider'] ?? 'Expert',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                        fontSize: 14)),
              ),
            ]),
            Text(f['amount'] ?? '--',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                    fontSize: 14)),
            Text(f['date'] ?? '--',
                style: const TextStyle(
                    color: AppColors.mutedForeground, fontSize: 13)),
            _AttemptsIndicator(count: (f['attempts'] as int?) ?? 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(children: [
                _ActionButton(
                  label: 'Retry',
                  icon: LucideIcons.refreshCw,
                  color: AppColors.primary,
                  bg: const Color(0xFFEFF6FF),
                  onTap: () => _confirmReactivate(subId),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Suspend',
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
        title: const Text('Retry Subscription',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
            'Do you want to reactivate this subscription and restore Premium access?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Retry'),
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
                content: Text('Subscription retried successfully.'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: const Text('Suspend Subscription',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
            'Do you want to permanently suspend this subscription? Premium access will be cut immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive,
                foregroundColor: Colors.white),
            child: const Text('Suspend'),
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
                content: Text('Subscription suspended.'),
                backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ── PREMIUM PRICING SETTINGS ────────────────────────────────────────────────

  Widget _buildPremiumPricingCard() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
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
          const Text('Premium Pack Configuration',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                  letterSpacing: -0.2)),
          const SizedBox(height: 24),
          Builder(builder: (context) {
            final double screenWidth = MediaQuery.of(context).size.width;
            final bool isMobile = screenWidth < 768;
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Premium Price (DH)',
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
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isUpdatingPrice ? null : _updatePremiumPrice,
                    icon: _isUpdatingPrice 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.save, size: 14),
                    label: const Text('Save and Apply', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.foreground,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      elevation: 0,
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Premium Price (DH)',
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
                SizedBox(
                  width: 220,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingPrice ? null : _updatePremiumPrice,
                    icon: _isUpdatingPrice 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.save, size: 14),
                    label: const Text('Save and Apply', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.foreground,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          const Text('Warning: Modifying the price will update the amount for all existing subscriptions.',
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
          const SnackBar(content: Text('Please enter a valid price.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Confirmation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to apply the price of ${newPrice.toStringAsFixed(2)} DH to all subscriptions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirm'),
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
          const SnackBar(content: Text('Price updated successfully for all subscriptions.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isUpdatingPrice = false; });
      }
    }
  }
}


// ════════════════════════════════════════════════════════════════════════════
// TABLE — Flutter native Table fills 100% width automatically via FlexColumnWidth
// ════════════════════════════════════════════════════════════════════════════

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
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 1024;
    
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
      case 'PROVIDER': return 'PROV.';
      case 'PACK': return 'PACK';
      case 'START': return 'START';
      case 'RENEWAL': return 'RENEW.';
      case 'AMOUNT': return 'AMOUNT';
      case 'STATUS': return 'STATUS';
      case 'FAILED DATE': return 'DATE';
      case 'ATTEMPTS': return 'ATT.';
      case 'ACTIONS': return 'ACT.';
      default: return label;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String name;
  final bool danger;
  const _Avatar({required this.name, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: danger ? const Color(0xFFDC2626) : const Color(0xFF2563EB))),
    );
  }
}

class _PackBadge extends StatelessWidget {
  final String label;
  const _PackBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    // Translate French pack names to English at display time
    final displayLabel = const {
      'Gratuit':   'Free',
      'GRATUIT':   'Free',
      'gratuit':   'Free',
      'Premium':   'Premium',
      'PREMIUM':   'Premium',
    }[label] ?? label;

    final bool isFree = displayLabel.toUpperCase() == 'FREE';

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: isFree
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFFEF9C3).withOpacity(0.6),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isFree
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFFFEF08A),
            )),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFree ? LucideIcons.package : LucideIcons.crown,
              size: 12,
              color: isFree ? const Color(0xFF64748B) : const Color(0xFFCA8A04),
            ),
            const SizedBox(width: 6),
            Text(displayLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isFree ? const Color(0xFF475569) : const Color(0xFFCA8A04),
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    // Normalise: accept both French (Actif, Grâce) and English (Active, Grace)
    final normalised = status.toLowerCase().replaceAll('â', 'a').replaceAll('é', 'e');
    Color bg;
    Color dot;
    Color text;
    String displayLabel;

    if (normalised == 'actif' || normalised == 'active') {
      bg = const Color(0xFFDCFCE7);
      dot = const Color(0xFF16A34A);
      text = const Color(0xFF166534);
      displayLabel = 'Active';
    } else if (normalised == 'grace' || normalised == 'grâce') {
      bg = const Color(0xFFFEF3C7);
      dot = const Color(0xFFD97706);
      text = const Color(0xFF92400E);
      displayLabel = 'Grace Period';
    } else {
      // Suspended / Cancelled / Expired
      bg = const Color(0xFFFEE2E2);
      dot = const Color(0xFFDC2626);
      text = const Color(0xFF991B1B);
      displayLabel = 'Suspended';
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(25)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
            ),
            const SizedBox(width: 6),
            Text(displayLabel,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: text)),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.muted.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.mutedForeground),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

class _AttemptsIndicator extends StatelessWidget {
  final int count;
  const _AttemptsIndicator({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          3,
          (i) => Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count
                  ? const Color(0xFFEF4444)
                  : AppColors.border.withOpacity(0.4),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$count/3',
            style: const TextStyle(
                fontSize: 12,
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

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CUSTOM TAB BUTTON
// ════════════════════════════════════════════════════════════════════════════

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