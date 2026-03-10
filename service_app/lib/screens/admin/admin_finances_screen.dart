import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';

class AdminFinancesScreen extends StatefulWidget {
  const AdminFinancesScreen({super.key});

  @override
  State<AdminFinancesScreen> createState() => _AdminFinancesScreenState();
}

class _AdminFinancesScreenState extends State<AdminFinancesScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getFinancialTransactions();
      if (mounted) {
        setState(() {
          _transactions = data;
          _totalRevenue = data.fold(0, (sum, item) => sum + (item['amount'] as num));
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
      activeRoute: '/admin/finances',
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
          const Text('Gestion Financière', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
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
            decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                const Icon(LucideIcons.dollarSign, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenu Total (Abonnements)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text('${_totalRevenue.toStringAsFixed(2)} DH', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border)),
            child: Column(
              children: [
                if (_transactions.isEmpty)
                  const Padding(padding: EdgeInsets.all(48), child: Text('Aucune transaction trouvée'))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _transactions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: _border),
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        title: Text('${t['expertName']} • ${t['amount']} DH', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Pack: ${t['pack']} • Date: ${t['date']}'),
                        trailing: const Icon(LucideIcons.checkCircle, color: Colors.green, size: 18),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
