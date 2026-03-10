import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

class AdminFinancesScreen extends StatelessWidget {
  const AdminFinancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finances',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Vue d\'ensemble financière',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            // KPI Cards
            Row(
              children: [
                _buildKPICard(
                  title: 'Revenus totaux',
                  value: '45,200 DH',
                  icon: Icons.attach_money,
                  color: AppColors.success,
                ),
                const SizedBox(width: 16),
                _buildKPICard(
                  title: 'Commissions',
                  value: '4,520 DH',
                  icon: Icons.percent,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 16),
                _buildKPICard(
                  title: 'En attente',
                  value: '2,100 DH',
                  icon: Icons.pending,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Transactions list
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transactions récentes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Voir tout'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildTransactionItem(
                            id: 'TXN-001',
                            client: 'Amina B.',
                            amount: '250 DH',
                            commission: '25 DH',
                            date: '2026-03-10',
                          ),
                          _buildTransactionItem(
                            id: 'TXN-002',
                            client: 'Omar T.',
                            amount: '300 DH',
                            commission: '30 DH',
                            date: '2026-03-09',
                          ),
                          _buildTransactionItem(
                            id: 'TXN-003',
                            client: 'Sara M.',
                            amount: '180 DH',
                            commission: '18 DH',
                            date: '2026-03-08',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required String id,
    required String client,
    required String amount,
    required String commission,
    required String date,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  client,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'Commission: $commission',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
