import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  bool _loading = true;
  Map<String, int> _categoryStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final stats = await _service.getReservationsByCategory();
      if (mounted) {
        setState(() {
          _categoryStats = stats;
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
      activeRoute: '/admin/statistics',
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
          const Text('Statistiques & Analyses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const Spacer(),
          IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 18, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Réservations par Catégorie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(_categoryStats.length, (index) {
                        return BarChartGroupData(x: index, barRods: [
                          BarChartRodData(toY: _categoryStats.values.elementAt(index).toDouble(), color: _primary, width: 16),
                        ]);
                      }),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                          if (v.toInt() < _categoryStats.keys.length) return Text(_categoryStats.keys.elementAt(v.toInt()).substring(0, 3).toUpperCase(), style: const TextStyle(fontSize: 10));
                          return const Text('');
                        })),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
