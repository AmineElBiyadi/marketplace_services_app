import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/booking_detail_dialog.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() => _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  bool _loading = true;
  List<Map<String, dynamic>> _reservations = [];
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedStatus = 'TOUS';
  DateTimeRange? _selectedDateRange;
  final List<String> _statuses = ['TOUS', 'EN_ATTENTE', 'ACCEPTEE', 'EN_COURS', 'TERMINEE', 'ANNULEE', 'REFUSEE'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getFilteredReservations(
        status: _selectedStatus,
        dateRange: _selectedDateRange,
        query: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _reservations = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              onSurface: _textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin/reservations',
      child: Column(
        children: [
          _buildTopBar(isMobile),
          _buildFilters(isMobile),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _buildMainContent(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(LucideIcons.menu, color: _textPrimary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const Text(
            'Gestion des Réservations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              _searchController.clear();
              _selectedStatus = 'TOUS';
              _selectedDateRange = null;
              _loadData();
            },
            icon: const Icon(LucideIcons.refreshCw, size: 18, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtres avancés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 300,
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadData(),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par Client, Expert ou Service...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () { _searchController.clear(); _loadData(); }) 
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 200,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedStatus = v);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 240,
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(LucideIcons.calendar, size: 18),
                  label: Text(
                    _selectedDateRange == null 
                      ? 'Toutes les dates' 
                      : '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: _selectedDateRange == null ? _border : _primary),
                    foregroundColor: _selectedDateRange == null ? _textSecondary : _primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    if (_reservations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            children: [
              Icon(LucideIcons.calendarX, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('Aucune réservation trouvée', style: TextStyle(color: _textSecondary, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservations.length,
        itemBuilder: (context, index) => _buildMobileReservationCard(_reservations[index]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),   // ID
            1: FlexColumnWidth(2),   // Service
            2: FlexColumnWidth(1.5), // Client
            3: FlexColumnWidth(1.5), // Expert
            4: FlexColumnWidth(1.5), // Date
            5: FlexColumnWidth(1.2), // Montant
            6: FlexColumnWidth(1.2), // Statut
            7: FixedColumnWidth(60), // Actions
          },
          children: [
            _buildTableHeader(),
            ..._reservations.map((r) => _buildTableRow(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileReservationCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: InkWell(
        onTap: () => _showReservationDetail(r['id']),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ID: ${r['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _primary)),
                _buildStatusBadge(r['status']),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['service'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('${r['date']} à ${r['time']}', style: const TextStyle(fontSize: 13, color: _textSecondary)),
                    ],
                  ),
                ),
                Text('${r['amount']} DH', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniProfile(LucideIcons.user, r['clientName']),
                _miniProfile(LucideIcons.wrench, r['expertName']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniProfile(IconData icon, String name) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: _border))),
      children: [
        _headerCell('ID #'),
        _headerCell('Service'),
        _headerCell('Client'),
        _headerCell('Expert'),
        _headerCell('Date / Heure'),
        _headerCell('Prix'),
        _headerCell('Statut'),
        _headerCell(''),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textSecondary)),
    );
  }

  TableRow _buildTableRow(Map<String, dynamic> r) {
    return TableRow(
      children: [
        _dataCell(Text(r['id'].toString().substring(0, 8), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _primary))),
        _dataCell(Text(r['service'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        _dataCell(Text(r['clientName'], style: const TextStyle(fontSize: 13))),
        _dataCell(Text(r['expertName'], style: const TextStyle(fontSize: 13))),
        _dataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(r['date'], style: const TextStyle(fontSize: 12)),
            Text(r['time'], style: const TextStyle(fontSize: 10, color: _textSecondary)),
          ],
        )),
        _dataCell(Text('${r['amount']} DH', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13))),
        _dataCell(_buildStatusBadge(r['status'])),
        IconButton(
          icon: const Icon(LucideIcons.maximize2, size: 16, color: _primary),
          onPressed: () => _showReservationDetail(r['id']),
        ),
      ],
    );
  }

  Widget _dataCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: child,
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'ACCEPTEE': color = Colors.green; break;
      case 'TERMINEE': color = Colors.blue; break;
      case 'EN_ATTENTE': color = Colors.orange; break;
      case 'REFUSEE': color = Colors.red; break;
      case 'ANNULEE': color = Colors.grey; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showReservationDetail(String id) {
    showDialog(
      context: context,
      builder: (context) => BookingDetailDialog(bookingId: id),
    ).then((_) => _loadData());
  }
}
