import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';
import '../../widgets/admin/booking_detail_dialog.dart';
import '../../widgets/admin/user_profile_detail_dialog.dart';
import '../../utils/admin_export_util.dart';
import 'package:intl/intl.dart';

class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key});

  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  bool _loading = true;
  List<Map<String, dynamic>> _allProviders = [];
  List<Map<String, dynamic>> _filteredProviders = [];
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedStatus = 'Tous';
  String _selectedSub = 'Tous';
  String _selectedSort = 'Plus récents';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getAllProviders();
      if (mounted) {
        setState(() {
          _allProviders = data;
          _filteredProviders = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProviders = _allProviders.where((p) {
        final nameMatches = p['name'].toString().toLowerCase().contains(query);
        final statusMatches = _selectedStatus == 'Tous' || p['status'] == _selectedStatus;
        final subMatches = _selectedSub == 'Tous' || 
            (_selectedSub == 'Premium' && p['hasSubscription'] == true) ||
            (_selectedSub == 'Gratuit' && p['hasSubscription'] == false);
        return nameMatches && statusMatches && subMatches;
      }).toList();
      
      if (_selectedSort == 'Plus récents') {
        _filteredProviders.sort((a, b) => (b['rawDate'] as DateTime).compareTo(a['rawDate'] as DateTime));
      } else if (_selectedSort == 'Plus anciens') {
        _filteredProviders.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate'] as DateTime));
      }
    });
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await _service.updateProviderStatus(id, newStatus);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour : $newStatus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin/providers',
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
          const Text('Gestion des Prestataires', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _exportProviders,
            icon: const Icon(LucideIcons.fileText, size: 14),
            label: const Text('Exporter PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _textPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 18, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
            child: isMobile
              ? Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un prestataire...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownFilter(
                            value: _selectedStatus,
                            items: ['Tous', 'ACTIVE', 'DESACTIVE', 'SUSPENDUE'],
                            label: 'Statut',
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedStatus = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdownFilter(
                            value: _selectedSub,
                            items: ['Tous', 'Premium', 'Gratuit'],
                            label: 'Offre',
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSub = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownFilter(
                      value: _selectedSort,
                      items: ['Plus récents', 'Plus anciens'],
                      label: 'Tri',
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSort = val);
                          _applyFilters();
                        }
                      },
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _applyFilters(),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un prestataire...',
                          prefixIcon: const Icon(LucideIcons.search, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownFilter(
                        value: _selectedStatus,
                        items: ['Tous', 'ACTIVE', 'DESACTIVE', 'SUSPENDUE'],
                        label: 'Statut',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownFilter(
                        value: _selectedSub,
                        items: ['Tous', 'Premium', 'Gratuit'],
                        label: 'Offre',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedSub = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownFilter(
                        value: _selectedSort,
                        items: ['Plus récents', 'Plus anciens'],
                        label: 'Tri',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedSort = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 24),
          // Table
          if (_filteredProviders.isEmpty)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Aucun prestataire trouvé')))
          else if (isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredProviders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildProviderCard(_filteredProviders[index]),
            )
          else
            Container(
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 340),
                      child: DataTable(
                        columnSpacing: 24,
                        showCheckboxColumn: false,
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: _textSecondary),
                        columns: const [
                          DataColumn(label: Text('Prestataire')),
                          DataColumn(label: Text('Services')),
                          DataColumn(label: Text('Abonnement')),
                          DataColumn(label: Text('Interventions')),
                          DataColumn(label: Text('Note')),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filteredProviders.map((p) {
                          return DataRow(
                            onSelectChanged: (_) {
                              showDialog(
                                context: context,
                                builder: (context) => UserProfileDetailDialog(id: p['id'], role: 'Prestataire'),
                              );
                            },
                            cells: _buildCells(p), // Helper or inline cells
                          );
                        }).toList(),
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

  List<DataCell> _buildCells(Map<String, dynamic> p) {
    final status = p['status'] ?? 'DESACTIVE';
    final services = (p['services'] as List).take(2).join(', ');
    final moreServices = (p['services'] as List).length > 2 ? '...' : '';
    return [
      DataCell(
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: p['imageUrl'] != null 
                  ? Image.network(
                      p['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(child: Text(p['avatar'] ?? '??', style: const TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.bold))),
                    )
                  : Center(child: Text(p['avatar'] ?? '??', style: const TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.bold))),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
      DataCell(Text('$services$moreServices', style: const TextStyle(fontSize: 12))),
      DataCell(_badge(p['pack'] ?? 'Gratuit', p['hasSubscription'] ? Colors.purple : _textSecondary)),
      DataCell(Center(child: Text(p['interventionsCount'].toString()))),
      DataCell(Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(p['rating'].toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      )),
      DataCell(_statusBadge(status)),
      DataCell(
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.eye, size: 18, color: _primary),
              tooltip: 'Détails',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => UserProfileDetailDialog(id: p['id'], role: 'Prestataire'),
                );
              },
            ),
            if (status != 'ACTIVE')
              IconButton(
                icon: const Icon(LucideIcons.checkCircle, size: 18, color: Colors.green),
                tooltip: 'Activer',
                onPressed: () => _updateStatus(p['id'], 'ACTIVE'),
              ),
            if (status == 'ACTIVE')
              IconButton(
                icon: const Icon(LucideIcons.xCircle, size: 18, color: Colors.orange),
                tooltip: 'Désactiver',
                onPressed: () => _updateStatus(p['id'], 'DESACTIVE'),
              ),
            if (status != 'SUSPENDUE')
              IconButton(
                icon: const Icon(LucideIcons.alertTriangle, size: 18, color: Colors.red),
                tooltip: 'Suspendre',
                onPressed: () => _updateStatus(p['id'], 'SUSPENDUE'),
              ),
          ],
        ),
      ),
    ];
  }

  DataRow _buildDataRow(Map<String, dynamic> p) {
    return DataRow(cells: _buildCells(p));
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green;
        label = 'Actif';
        break;
      case 'SUSPENDUE':
        color = Colors.red;
        label = 'Suspendu';
        break;
      default:
        color = Colors.orange;
        label = 'Désactivé';
    }
    return _badge(label, color);
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _textSecondary),
          style: const TextStyle(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
          items: items.map((item) {
            String display = item;
            if (item == 'Tous') display = '$label: Tous';
            else if (item == 'ACTIVE') display = 'Actif';
            else if (item == 'DESACTIVE') display = 'Désactivé';
            else if (item == 'SUSPENDUE') display = 'Suspendu';
            return DropdownMenuItem(value: item, child: Text(display));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> p) {
    final status = p['status'] ?? 'DESACTIVE';
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => UserProfileDetailDialog(id: p['id'], role: 'Prestataire'),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _primary.withOpacity(0.1),
                  backgroundImage: p['imageUrl'] != null ? NetworkImage(p['imageUrl']) : null,
                  child: p['imageUrl'] == null
                      ? Text(p['avatar'] ?? '??', style: const TextStyle(fontSize: 14, color: _primary, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Note', style: TextStyle(fontSize: 10, color: _textSecondary)),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(p['rating'].toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Offre', style: TextStyle(fontSize: 10, color: _textSecondary)),
                    _badge(p['pack'] ?? 'Gratuit', p['hasSubscription'] ? Colors.purple : _textSecondary),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Interventions', style: TextStyle(fontSize: 10, color: _textSecondary)),
                    Text(p['interventionsCount'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.eye, size: 20, color: _primary),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => UserProfileDetailDialog(id: p['id'], role: 'Prestataire'),
                    );
                  },
                ),
                const Spacer(),
                if (status != 'ACTIVE')
                  IconButton(
                    icon: const Icon(LucideIcons.checkCircle, size: 20, color: Colors.green),
                    onPressed: () => _updateStatus(p['id'], 'ACTIVE'),
                  ),
                if (status == 'ACTIVE')
                  IconButton(
                    icon: const Icon(LucideIcons.xCircle, size: 20, color: Colors.orange),
                    onPressed: () => _updateStatus(p['id'], 'DESACTIVE'),
                  ),
                if (status != 'SUSPENDUE')
                  IconButton(
                    icon: const Icon(LucideIcons.alertTriangle, size: 20, color: Colors.red),
                    onPressed: () => _updateStatus(p['id'], 'SUSPENDUE'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _exportProviders() async {
    final headers = ['Nom', 'Pack', 'Évaluations', 'Interventions', 'Statut'];
    final rows = _filteredProviders.map((p) => [
      p['name'] ?? '',
      p['pack'] ?? '',
      p['rating']?.toStringAsFixed(1) ?? '0.0',
      p['interventionsCount']?.toString() ?? '0',
      p['status'] ?? '',
    ]).toList();

    await AdminExportUtil.exportPageToPdf(
      filename: 'providers_presto_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      title: 'Registre des Prestataires',
      subtitle: 'Liste des experts et professionnels inscrits sur Presto',
      kpis: [
        {'label': 'Total Experts', 'value': _allProviders.length.toString()},
        {'label': 'Premium', 'value': _allProviders.where((p) => p['pack'] == 'Premium').length.toString()},
        {'label': 'En Attente', 'value': _allProviders.where((p) => p['status'] == 'EN_ATTENTE' || p['status'] == 'En attente').length.toString()},
      ],
      tableHeaders: headers,
      tableRows: rows,
    );
  }
}

