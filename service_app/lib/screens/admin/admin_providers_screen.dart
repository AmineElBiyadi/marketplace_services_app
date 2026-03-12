import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';

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
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
            child: Row(
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
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Table
          Container(
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_filteredProviders.isEmpty)
                  const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Aucun prestataire trouvé')))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 340),
                      child: DataTable(
                        columnSpacing: 24,
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
                        rows: _filteredProviders.map((p) => _buildDataRow(p)).toList(),
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

  DataRow _buildDataRow(Map<String, dynamic> p) {
    final status = p['status'] ?? 'DESACTIVE';
    final services = (p['services'] as List).take(2).join(', ');
    final moreServices = (p['services'] as List).length > 2 ? '...' : '';

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _primary.withOpacity(0.1),
                backgroundImage: p['imageUrl'] != null ? NetworkImage(p['imageUrl']) : null,
                child: p['imageUrl'] == null
                    ? Text(p['avatar'] ?? '??', style: const TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(p['zone'] ?? '', style: const TextStyle(fontSize: 11, color: _textSecondary)),
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
                onPressed: () => _showDetailsDialog(p),
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
      ],
    );
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

  void _showDetailsDialog(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: p['imageUrl'] != null ? NetworkImage(p['imageUrl']) : null,
              child: p['imageUrl'] == null ? const Icon(LucideIcons.user) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(p['name'] ?? 'Détails du Prestataire')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Carte Nationale:', p['CarteNationale']),
              _detailRow('Casier Judiciaire:', p['CasierJudiciaire']),
              _detailRow('Expérience:', p['Experience']),
              _detailRow('Rayon de travail:', '${p['rayonTravaille']} km'),
              _detailRow('Vues du profil:', p['profileViews'].toString()),
              _detailRow('Note moyenne:', '${p['rating'].toStringAsFixed(1)} / 5'),
              _detailRow('Interventions:', p['interventionsCount'].toString()),
              const Divider(),
              const Text('Services:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text((p['services'] as List).join(', ')),
              const SizedBox(height: 8),
              const Text('Tâches:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text((p['tasks'] as List).join(', ')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }
}

