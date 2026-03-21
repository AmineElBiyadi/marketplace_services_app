import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

import '../../services/admin_dashboard_service.dart';

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
  double _totalRevenue = 0.0;
  int _premiumCount = 0;
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
      'label': "Impayés",
      'value': "${_failedPayments.length}",
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
      final stats = await _dashboardService.getDashboardStats();
      final monthlyRev = await _dashboardService.getMonthlyRevenue();
      final transactions = await _dashboardService.getFinancialTransactions();

      final last6Months = monthlyRev.length > 6 ? monthlyRev.sublist(monthlyRev.length - 6) : monthlyRev;
      
      double currentPackRev = 0;
      if (last6Months.isNotEmpty) {
         currentPackRev = (last6Months.last['revenue'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _totalRevenue = stats.totalRevenue;
          _premiumCount = stats.premiumProviders;
          _currentMonthRevenue = currentPackRev;

          _revenueData = last6Months.map((e) => {
            'month': e['month'],
            'abonnements': (e['revenue'] as num).toDouble(),
          }).toList();

          _subscriptions = transactions.map((t) => {
            'provider': t['expertName'] ?? 'Prestataire',
            'pack': t['pack'] ?? 'Premium',
            'start': t['date'] ?? 'N/A',
            'renewal': t['renewal'] ?? 'Auto',
            'amount': '${t['amount']} DH',
            'status': t['status'] ?? 'Actif',
          }).toList();
          
          _failedPayments = [];
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
    return AdminLayout(
      activeRoute: '/admin/finances',
      child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.foreground))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildKPIGrid(),
                    const SizedBox(height: 32),
                    _buildChartCard(),
                    const SizedBox(height: 32),
                    _buildTabsIndicator(),
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
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finances',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.foreground,
                    letterSpacing: -0.5)),
            SizedBox(height: 4),
            Text('Suivi des revenus et abonnements premium',
                style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(LucideIcons.download, size: 14),
          label: const Text('Export Excel',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.foreground,
            foregroundColor: AppColors.card,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Performance Mensuelle',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                      letterSpacing: -0.2)),
              _buildLegendRow(),
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
        const Text('Abonnements Premium',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── TAB BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTabsIndicator() {
    return Row(
      children: [
        _TabButton(
          index: 0,
          controller: _tabController,
          icon: LucideIcons.checkCircle,
          label: 'Abonnements Actifs',
          count: _subscriptions.length,
          activeColor: const Color(0xFF16A34A),
          activeBg: const Color(0xFFF0FDF4),
        ),
        const SizedBox(width: 8),
        _TabButton(
          index: 1,
          controller: _tabController,
          icon: LucideIcons.alertCircle,
          label: 'Paiements Échoués',
          count: _failedPayments.length,
          activeColor: const Color(0xFFDC2626),
          activeBg: const Color(0xFFFEF2F2),
        ),
      ],
    );
  }

  // ── SUBSCRIPTIONS TABLE ──────────────────────────────────────────────────────
  Widget _buildSubscriptionsTable() {
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
        'PRESTATAIRE', 'PACK', 'DÉBUT', 'RENOUVELLEMENT', 'MONTANT', 'STATUT',
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
              const Text('Aucun paiement échoué',
                  style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
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
        'PRESTATAIRE', 'MONTANT', 'DATE', 'TENTATIVES', 'ACTIONS',
      ],
      dataRows: _failedPayments.asMap().entries.map((e) {
        final f = e.value;
        return _TableRowData(
          isEven: e.key.isEven,
          cells: [
            Row(children: [
              _Avatar(name: f['provider'], danger: true),
              const SizedBox(width: 10),
              Flexible(
                child: Text(f['provider'],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                        fontSize: 14)),
              ),
            ]),
            Text(f['amount'],
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                    fontSize: 14)),
            Text(f['date'],
                style: const TextStyle(
                    color: AppColors.mutedForeground, fontSize: 13)),
            _AttemptsIndicator(count: f['attempts']),
            Row(children: [
              _ActionButton(
                label: 'Relancer',
                icon: LucideIcons.refreshCw,
                color: AppColors.primary,
                bg: const Color(0xFFEFF6FF),
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: 'Bloquer',
                icon: LucideIcons.ban,
                color: AppColors.destructive,
                bg: const Color(0xFFFEF2F2),
                onTap: () {},
              ),
            ]),
          ],
        );
      }).toList(),
    );
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
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minW),
            child: Table(
              columnWidths: columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                // ── Header row
                TableRow(
                  decoration: BoxDecoration(
                    color: AppColors.muted.withOpacity(0.35),
                  ),
                  children: headerLabels
                      .map((label) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Text(label,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.mutedForeground,
                                    letterSpacing: 0.7)),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF9C3).withOpacity(0.6),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFFEF08A))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.crown, size: 12, color: Color(0xFFCA8A04)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFCA8A04),
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool active = status == "Actif";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: active ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(25)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626)),
          ),
          const SizedBox(width: 6),
          Text(status,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? const Color(0xFF166534)
                      : const Color(0xFF991B1B))),
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

  const _TabButton({
    required this.index,
    required this.controller,
    required this.icon,
    required this.label,
    required this.count,
    required this.activeColor,
    required this.activeBg,
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