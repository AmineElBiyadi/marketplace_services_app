import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/booking_detail_dialog.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  bool _loading = true;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'Tous';
  String _selectedStatus = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final users = await _service.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
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
      _filteredUsers = _allUsers.where((user) {
        final nameMatches = (user['name'] ?? '').toLowerCase().contains(query);
        final roleMatches = _selectedRole == 'Tous' || (user['type'] == _selectedRole);
        final statusMatches = _selectedStatus == 'Tous' || (user['status'] == _selectedStatus);
        return nameMatches && roleMatches && statusMatches;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin/users',
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
          const Text('Gestion des Utilisateurs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const Spacer(),
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
                        hintText: 'Rechercher par nom...',
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
                            value: _selectedRole,
                            items: ['Tous', 'Client', 'Prestataire'],
                            label: 'Rôle',
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRole = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdownFilter(
                            value: _selectedStatus,
                            items: ['Tous', 'Actif', 'Suspendu'],
                            label: 'Statut',
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedStatus = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                      ],
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
                          hintText: 'Rechercher par nom...',
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
                        value: _selectedRole,
                        items: ['Tous', 'Client', 'Prestataire'],
                        label: 'Rôle',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRole = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownFilter(
                        value: _selectedStatus,
                        items: ['Tous', 'Actif', 'Suspendu'],
                        label: 'Statut',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 24),
          if (_filteredUsers.isEmpty)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Aucun utilisateur trouvé')))
          else if (isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredUsers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
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
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: _textSecondary),
                        columns: const [
                          DataColumn(label: Text('Utilisateur')),
                          DataColumn(label: Text('Rôle')),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Créé le')),
                          DataColumn(label: Text('Mis à jour le')),
                        ],
                        rows: _filteredUsers.map((user) {
                          return DataRow(
                            onSelectChanged: (_) {
                              showDialog(
                                context: context,
                                builder: (context) => UserProfileDetailDialog(id: user['id'], role: user['type'] ?? 'Client'),
                              );
                            },
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _primary.withOpacity(0.1),
                                      backgroundImage: user['imageUrl'] != null ? NetworkImage(user['imageUrl']) : null,
                                      child: user['imageUrl'] == null
                                          ? Text(user['avatar'] ?? '??', style: const TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.bold))
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(user['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              DataCell(_badge(user['type'] ?? 'Client', user['type'] == 'Prestataire' ? Colors.purple : _primary)),
                              DataCell(_badge(user['status'] ?? 'Actif', user['status'] == 'Actif' ? Colors.green : Colors.red)),
                              DataCell(Text(user['createdAt'] ?? 'N/A', style: const TextStyle(color: _textSecondary))),
                              DataCell(Text(user['updatedAt'] ?? 'N/A', style: const TextStyle(color: _textSecondary))),
                            ],
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

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _textSecondary),
          style: const TextStyle(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item == 'Tous' ? '$label: $item' : item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => UserProfileDetailDialog(id: user['id'], role: user['type'] ?? 'Client'),
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
                  backgroundImage: user['imageUrl'] != null ? NetworkImage(user['imageUrl']) : null,
                  child: user['imageUrl'] == null
                      ? Text(user['avatar'] ?? '??', style: const TextStyle(fontSize: 14, color: _primary, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _badge(user['type'] ?? 'Client', user['type'] == 'Prestataire' ? Colors.purple : _primary),
                          const SizedBox(width: 8),
                          _badge(user['status'] ?? 'Actif', user['status'] == 'Actif' ? Colors.green : Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Créé le', style: TextStyle(fontSize: 10, color: _textSecondary)),
                    Text(user['createdAt'] ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Téléphone', style: TextStyle(fontSize: 10, color: _textSecondary)),
                    Text(user['phone'] ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
