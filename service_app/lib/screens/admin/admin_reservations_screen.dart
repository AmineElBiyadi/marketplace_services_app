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
            if (item == 'TOUS') display = '$label: Tous';
            else display = item.replaceAll('_', ' ');
            return DropdownMenuItem(value: item, child: Text(display));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    onSubmitted: (_) => _loadData(),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un client, expert ou service...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
                            },
                          )
                        : IconButton(
                            icon: const Icon(LucideIcons.arrowRight, size: 16, color: _primary),
                            onPressed: _loadData,
                          ),
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
                    items: _statuses,
                    label: 'Statut',
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedStatus = v);
                        _loadData();
                      }
                    },
                  ),
                ),
                if (isMobile) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _selectDateRange,
                    icon: Icon(LucideIcons.calendar, color: _selectedDateRange == null ? _textSecondary : _primary),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime _viewMonth = DateTime.now();

  Widget _buildSideCalendar() {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 24, top: 24, bottom: 24, right: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 18, color: _primary),
                const SizedBox(width: 10),
                const Text('Période', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (_selectedDateRange != null)
                  IconButton(
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    onPressed: () {
                      setState(() => _selectedDateRange = null);
                      _loadData();
                    },
                    tooltip: 'Réinitialiser',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildCalendarHeader(),
          _buildCalendarGrid(),
          const Divider(height: 1),
          _buildLegendSection(),
        ],
      ),
    ),
  );
}

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
            onPressed: () => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy', 'fr').format(_viewMonth).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary),
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 18),
            onPressed: () => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday; // 1 = Monday, 7 = Sunday

    final List<String> weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((d) => SizedBox(width: 32, child: Center(child: Text(d, style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.bold))))).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, 
              mainAxisSpacing: 6, 
              crossAxisSpacing: 6,
              childAspectRatio: 1, // Ensure square cells
            ),
            itemCount: 42, // 6 weeks
            itemBuilder: (context, index) {
              final dayIndex = index - (firstWeekday - 1);
              if (dayIndex < 0 || dayIndex >= daysInMonth) return const SizedBox();

              final date = DateTime(_viewMonth.year, _viewMonth.month, dayIndex + 1);
              final isSelected = _selectedDateRange != null && (date.isAtSameMomentAs(_selectedDateRange!.start) || date.isAtSameMomentAs(_selectedDateRange!.end) || (date.isAfter(_selectedDateRange!.start) && date.isBefore(_selectedDateRange!.end)));
              
              final isStart = _selectedDateRange != null && date.isAtSameMomentAs(_selectedDateRange!.start);
              final isEnd = _selectedDateRange != null && date.isAtSameMomentAs(_selectedDateRange!.end);
              final isToday = DateUtils.isSameDay(date, DateTime.now());

              return GestureDetector(
                onTap: () => _handleDateSelection(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? _primary.withOpacity(isStart || isEnd ? 1.0 : 0.2) : Colors.transparent,
                    shape: isStart || isEnd ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: isSelected && !isStart && !isEnd ? null : (isStart || isEnd ? null : BorderRadius.circular(4)),
                    border: isToday ? Border.all(color: _primary, width: 1) : null,
                  ),
                  child: Center(
                    child: Text(
                      '${dayIndex + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        color: isStart || isEnd ? Colors.white : (isSelected ? _primary : _textPrimary),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleDateSelection(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    setState(() {
      if (_selectedDateRange == null || !DateUtils.isSameDay(_selectedDateRange!.start, _selectedDateRange!.end)) {
        _selectedDateRange = DateTimeRange(start: startOfDay, end: endOfDay);
      } else {
        if (startOfDay.isBefore(_selectedDateRange!.start)) {
          _selectedDateRange = DateTimeRange(start: startOfDay, end: _selectedDateRange!.end);
        } else {
          _selectedDateRange = DateTimeRange(start: _selectedDateRange!.start, end: endOfDay);
        }
      }
    });
    _loadData();
  }

  Widget _buildLegendSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Légende', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textSecondary)),
          const SizedBox(height: 8),
          _buildLegendItem(Colors.orange, 'En attente'),
          _buildLegendItem(Colors.green, 'Acceptée'),
          _buildLegendItem(Colors.blue, 'Terminée'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    if (isMobile) {
      if (_reservations.isEmpty) {
        return _buildEmptyState();
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservations.length,
        itemBuilder: (context, index) => _buildMobileReservationCard(_reservations[index]),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSideCalendar(),
        Expanded(
          child: _reservations.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
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
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.calendarX, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Aucune réservation trouvée', style: TextStyle(color: _textSecondary, fontSize: 16)),
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
