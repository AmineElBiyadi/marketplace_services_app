import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() => _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  String searchQuery = '';
  String statusFilter = 'all';

  final List<Map<String, dynamic>> mockReservations = [
    {'id': 1, 'client': 'Amina Benali', 'provider': 'Ahmed Khalil', 'service': 'Plomberie', 'date': '2026-03-15', 'price': '250 DH', 'status': 'Confirmée'},
    {'id': 2, 'client': 'Omar Tazi', 'provider': 'Fatima Alaoui', 'service': 'Ménage', 'date': '2026-03-14', 'price': '300 DH', 'status': 'Terminée'},
    {'id': 3, 'client': 'Sara Mounir', 'provider': 'Youssef Berrada', 'service': 'Électricité', 'date': '2026-03-13', 'price': '180 DH', 'status': 'Annulée'},
    {'id': 4, 'client': 'Karim Hajji', 'provider': 'Nadia Fassi', 'service': 'Coiffure', 'date': '2026-03-12', 'price': '150 DH', 'status': 'Confirmée'},
    {'id': 5, 'client': 'Hana Bouzid', 'provider': 'Rachid Kabbaj', 'service': 'Jardinage', 'date': '2026-03-11', 'price': '400 DH', 'status': 'Terminée'},
  ];

  List<Map<String, dynamic>> get filteredReservations {
    return mockReservations.where((r) {
      final matchesSearch = r['client'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          r['provider'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      final matchesStatus = statusFilter == 'all' || r['status'] == statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmée':
        return AppColors.primary;
      case 'Terminée':
        return AppColors.success;
      case 'Annulée':
        return AppColors.destructive;
      default:
        return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservations = filteredReservations;

    return AdminLayout(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Réservations',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Gestion des réservations et paiements',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            // Toolbar
            Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: AppColors.muted.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: statusFilter,
                      items: ['all', 'Confirmée', 'Terminée', 'Annulée'].map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status == 'all' ? 'Tous' : status),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          statusFilter = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Client')),
                      DataColumn(label: Text('Prestataire')),
                      DataColumn(label: Text('Service')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Prix')),
                      DataColumn(label: Text('Statut')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: reservations.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(Text('#${r['id']}')),
                          DataCell(Text(r['client'] as String)),
                          DataCell(Text(r['provider'] as String)),
                          DataCell(Text(r['service'] as String)),
                          DataCell(Text(r['date'] as String)),
                          DataCell(Text(r['price'] as String)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(r['status'] as String).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                r['status'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(r['status'] as String),
                                ),
                              ),
                            ),
                          ),
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18),
                                onPressed: () {},
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
