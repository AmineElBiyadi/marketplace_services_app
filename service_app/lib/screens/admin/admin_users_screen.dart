import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/badges.dart';
import '../../widgets/common_widgets.dart';
import '../../layouts/admin_layout.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  Map<String, dynamic>? _selectedUser;

  final List<Map<String, dynamic>> mockUsers = [
    {'id': 1, 'name': 'Amina Benali', 'phone': '06 12 34 56 78', 'date': '2026-01-15', 'bookings': 12, 'status': 'Actif', 'avatar': 'AB', 'region': 'Casablanca'},
    {'id': 2, 'name': 'Omar Tazi', 'phone': '06 98 76 54 32', 'date': '2026-02-01', 'bookings': 5, 'status': 'Actif', 'avatar': 'OT', 'region': 'Rabat'},
    {'id': 3, 'name': 'Sara Mounir', 'phone': '06 55 44 33 22', 'date': '2025-11-20', 'bookings': 22, 'status': 'Actif', 'avatar': 'SM', 'region': 'Marrakech'},
    {'id': 4, 'name': 'Karim Hajji', 'phone': '06 11 22 33 44', 'date': '2026-03-01', 'bookings': 1, 'status': 'Suspendu', 'avatar': 'KH', 'region': 'Fès'},
    {'id': 5, 'name': 'Hana Bouzid', 'phone': '06 77 88 99 00', 'date': '2025-12-10', 'bookings': 8, 'status': 'Actif', 'avatar': 'HB', 'region': 'Tanger'},
    {'id': 6, 'name': 'Youssef Alami', 'phone': '06 33 44 55 66', 'date': '2026-01-28', 'bookings': 3, 'status': 'Actif', 'avatar': 'YA', 'region': 'Casablanca'},
  ];

  final List<Map<String, dynamic>> userBookings = [
    {'id': 1, 'provider': 'Ahmed K.', 'service': 'Plomberie', 'date': '2026-03-05', 'status': 'Terminée', 'price': '250 DH'},
    {'id': 2, 'provider': 'Fatima A.', 'service': 'Ménage', 'date': '2026-03-02', 'status': 'Confirmée', 'price': '300 DH'},
    {'id': 3, 'provider': 'Rachid B.', 'service': 'Électricité', 'date': '2026-02-20', 'status': 'Annulée', 'price': '180 DH'},
  ];

  List<Map<String, dynamic>> get filteredUsers {
    return mockUsers.where((u) {
      final matchSearch = u['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
          u['phone'].toString().contains(_searchController.text);
      final matchStatus = _statusFilter == 'all' || u['status'] == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  void _showUserDetail(Map<String, dynamic> user) {
    setState(() => _selectedUser = user);
    showDialog(
      context: context,
      builder: (context) => _buildUserDetailDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Utilisateurs',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gestion des comptes clients',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),

            // Toolbar
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    hintText: 'Rechercher par nom ou téléphone...',
                    controller: _searchController,
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.mutedForeground),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                // Status filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      hint: const Text('Statut'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tous')),
                        DropdownMenuItem(value: 'Actif', child: Text('Actif')),
                        DropdownMenuItem(value: 'Suspendu', child: Text('Suspendu')),
                      ],
                      onChanged: (value) => setState(() => _statusFilter = value!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exporter CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Table
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.muted.withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Utilisateur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 2, child: Text('Téléphone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 2, child: Text('Inscription', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 1, child: Text('Réservations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 1, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                      ],
                    ),
                  ),
                  // Table body
                  ...filteredUsers.map((user) => _buildUserRow(user)),
                  // Pagination
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filteredUsers.length} utilisateur(s)',
                          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                        ),
                        Row(
                          children: [
                            _buildPageButton('Précédent', null),
                            _buildPageButton('1', AppColors.primary, isActive: true),
                            _buildPageButton('2', null),
                            _buildPageButton('Suivant', null),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final statusColor = user['status'] == 'Actif' ? AppColors.success : AppColors.destructive;

    return InkWell(
      onTap: () => _showUserDetail(user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        user['avatar'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        user['region'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                user['phone'] as String,
                style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                user['date'] as String,
                style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                user['bookings'].toString(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user['status'] as String,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.more_horiz, size: 20, color: AppColors.mutedForeground),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageButton(String label, Color? bgColor, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? AppColors.primary : null,
          foregroundColor: isActive ? Colors.white : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildUserDetailDialog() {
    if (_selectedUser == null) return const SizedBox.shrink();

    final user = _selectedUser!;
    final statusColor = user['status'] == 'Actif' ? AppColors.success : AppColors.destructive;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Text(
                'Détail utilisateur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.foreground),
              ),
              const SizedBox(height: 16),

              // Profile card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          user['avatar'] as String,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] as String,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.foreground),
                          ),
                          Text(
                            '${user['phone']} • ${user['region']}',
                            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                          ),
                          Text(
                            'Inscrit le ${user['date']}',
                            style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user['status'] as String,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tabs
              DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.muted.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const TabBar(
                        tabs: [
                          Tab(text: 'Réservations'),
                          Tab(text: 'Avis'),
                          Tab(text: 'Réclamations'),
                        ],
                        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: TabBarView(
                        children: [
                          // Bookings tab
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: userBookings.length,
                            itemBuilder: (context, index) {
                              final booking = userBookings[index];
                              final bookingStatusColor = booking['status'] == 'Terminée'
                                  ? AppColors.success
                                  : booking['status'] == 'Confirmée'
                                      ? AppColors.info
                                      : AppColors.mutedForeground;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.muted.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            booking['service'] as String,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
                                          ),
                                          Text(
                                            '${booking['provider']} • ${booking['date']}',
                                            style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          booking['price'] as String,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: bookingStatusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            booking['status'] as String,
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: bookingStatusColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          // Reviews tab
                          const Center(child: Text('Aucun avis pour le moment', style: TextStyle(color: AppColors.mutedForeground))),
                          // Claims tab
                          const Center(child: Text('Aucune réclamation', style: TextStyle(color: AppColors.mutedForeground))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Suspendre'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete, size: 18, color: AppColors.destructive),
                      label: const Text('Supprimer', style: TextStyle(color: AppColors.destructive)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset MDP'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
