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

class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key});

  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen> {
  final _searchController = TextEditingController();
  String _activeTab = 'all';
  Map<String, dynamic>? _selectedProvider;
  bool _showRejectModal = false;
  final _rejectReasonController = TextEditingController();

  final List<Map<String, dynamic>> mockProviders = [
    {'id': 1, 'name': 'Ahmed Khalil', 'category': 'Plomberie', 'pack': 'Premium', 'rating': 4.8, 'services': 8, 'bookings': 45, 'status': 'Validé', 'date': '2025-10-15', 'avatar': 'AK', 'zone': 'Casablanca'},
    {'id': 2, 'name': 'Fatima Alaoui', 'category': 'Ménage', 'pack': 'Gratuit', 'rating': 4.5, 'services': 3, 'bookings': 18, 'status': 'Validé', 'date': '2026-01-20', 'avatar': 'FA', 'zone': 'Rabat'},
    {'id': 3, 'name': 'Youssef Berrada', 'category': 'Électricité', 'pack': 'Gratuit', 'rating': 0.0, 'services': 0, 'bookings': 0, 'status': 'En attente', 'date': '2026-03-07', 'avatar': 'YB', 'zone': 'Casablanca'},
    {'id': 4, 'name': 'Rachid Kabbaj', 'category': 'Jardinage', 'pack': 'Gratuit', 'rating': 0.0, 'services': 0, 'bookings': 0, 'status': 'En attente', 'date': '2026-03-06', 'avatar': 'RK', 'zone': 'Marrakech'},
    {'id': 5, 'name': 'Nadia Fassi', 'category': 'Coiffure', 'pack': 'Premium', 'rating': 4.9, 'services': 12, 'bookings': 60, 'status': 'Validé', 'date': '2025-08-10', 'avatar': 'NF', 'zone': 'Tanger'},
    {'id': 6, 'name': 'Hassan Idrissi', 'category': 'IT Support', 'pack': 'Gratuit', 'rating': 3.2, 'services': 2, 'bookings': 5, 'status': 'Suspendu', 'date': '2025-12-01', 'avatar': 'HI', 'zone': 'Fès'},
    {'id': 7, 'name': 'Laila Chraibi', 'category': 'Ménage', 'pack': 'Gratuit', 'rating': 0.0, 'services': 0, 'bookings': 0, 'status': 'Rejeté', 'date': '2026-02-15', 'avatar': 'LC', 'zone': 'Agadir'},
  ];

  final List<Map<String, dynamic>> statusTabs = [
    {'value': 'all', 'label': 'Tous', 'count': 7},
    {'value': 'En attente', 'label': 'En attente', 'count': 2},
    {'value': 'Validé', 'label': 'Validés', 'count': 3},
    {'value': 'Suspendu', 'label': 'Suspendus', 'count': 1},
    {'value': 'Rejeté', 'label': 'Rejetés', 'count': 1},
  ];

  List<Map<String, dynamic>> get filteredProviders {
    return mockProviders.where((p) {
      final matchSearch = p['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
          p['category'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
      final matchTab = _activeTab == 'all' || p['status'] == _activeTab;
      return matchSearch && matchTab;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Validé':
        return AppColors.success;
      case 'En attente':
        return AppColors.warning;
      case 'Suspendu':
        return AppColors.destructive;
      case 'Rejeté':
        return AppColors.mutedForeground;
      default:
        return AppColors.mutedForeground;
    }
  }

  void _showProviderDetail(Map<String, dynamic> provider) {
    setState(() => _selectedProvider = provider);
    showDialog(
      context: context,
      builder: (context) => _buildProviderDetailDialog(),
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rejeter le prestataire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _rejectReasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Raison du rejet (sera envoyée par SMS)...',
                filled: true,
                fillColor: AppColors.muted.withOpacity(0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmer le rejet'),
          ),
        ],
      ),
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
              'Prestataires',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gestion et validation des comptes prestataires',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),

            // Status tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statusTabs.map((tab) {
                  final isActive = _activeTab == tab['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      onPressed: () => setState(() => _activeTab = tab['value'] as String),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? AppColors.primary : AppColors.card,
                        foregroundColor: isActive ? Colors.white : AppColors.mutedForeground,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isActive ? AppColors.primary : AppColors.border),
                        ),
                      ),
                      child: Text('${tab['label']} (${tab['count']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Toolbar
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    hintText: 'Rechercher...',
                    controller: _searchController,
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.mutedForeground),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exporter'),
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
                        Expanded(flex: 3, child: Text('Prestataire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 2, child: Text('Catégorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 2, child: Text('Pack', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 1, child: Text('Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 1, child: Text('Services', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                        Expanded(flex: 2, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                      ],
                    ),
                  ),
                  // Table body
                  ...filteredProviders.map((p) => _buildProviderRow(p)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderRow(Map<String, dynamic> p) {
    final statusColor = _getStatusColor(p['status'] as String);
    final packColor = p['pack'] == 'Premium' ? AppColors.accent : AppColors.mutedForeground;

    return InkWell(
      onTap: () => _showProviderDetail(p),
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
                        p['avatar'] as String,
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
                        p['name'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        '${p['zone']} • ${p['date']}',
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
                p['category'] as String,
                style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: packColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p['pack'] == 'Premium') ...[
                      Icon(Icons.star, size: 12, color: packColor),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      p['pack'] as String,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: packColor),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: (p['rating'] as double) > 0
                  ? Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.premium),
                        const SizedBox(width: 2),
                        Text(
                          p['rating'].toString(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground),
                        ),
                      ],
                    )
                  : const Text('—', style: TextStyle(color: AppColors.mutedForeground)),
            ),
            Expanded(
              flex: 1,
              child: Text(
                p['services'].toString(),
                style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
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
                  p['status'] as String,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: p['status'] == 'En attente'
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, size: 18, color: AppColors.success),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.destructive),
                          onPressed: _showRejectDialog,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderDetailDialog() {
    if (_selectedProvider == null) return const SizedBox.shrink();

    final provider = _selectedProvider!;
    final statusColor = _getStatusColor(provider['status'] as String);
    final packColor = provider['pack'] == 'Premium' ? AppColors.accent : AppColors.mutedForeground;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Text(
                'Détail prestataire',
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
                          provider['avatar'] as String,
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
                            provider['name'] as String,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.foreground),
                          ),
                          Text(
                            '${provider['category']} • ${provider['zone']}',
                            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: packColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (provider['pack'] == 'Premium') ...[
                                      Icon(Icons.star, size: 12, color: packColor),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      provider['pack'] as String,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: packColor),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  provider['status'] as String,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tabs
              DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.muted.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const TabBar(
                        tabs: [
                          Tab(text: 'Documents'),
                          Tab(text: 'Services'),
                          Tab(text: 'Réservations'),
                          Tab(text: 'Finances'),
                        ],
                        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: TabBarView(
                        children: [
                          // Documents tab
                          Column(
                            children: [
                              _buildDocumentItem('CIN (Recto/Verso)', 'Uploadé le 2026-03-07', 'En attente'),
                              const SizedBox(height: 8),
                              _buildDocumentItem('Certificat de bonne conduite', 'Uploadé le 2026-03-07', 'En attente'),
                              if (provider['status'] == 'En attente') ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Valider le compte'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _showRejectDialog,
                                        icon: const Icon(Icons.close, size: 18),
                                        label: const Text('Rejeter'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.destructive,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          // Services tab
                          Center(child: Text('${provider['services']} service(s) enregistré(s)', style: TextStyle(color: AppColors.mutedForeground))),
                          // Bookings tab
                          Center(child: Text('${provider['bookings']} réservation(s)', style: TextStyle(color: AppColors.mutedForeground))),
                          // Finances tab
                          const Center(child: Text('Données financières', style: TextStyle(color: AppColors.mutedForeground))),
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
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Voir profil public'),
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
                      icon: const Icon(Icons.block, size: 18, color: AppColors.destructive),
                      label: const Text('Suspendre', style: TextStyle(color: AppColors.destructive)),
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

  Widget _buildDocumentItem(String title, String date, String status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, size: 20, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                Text(date, style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}
