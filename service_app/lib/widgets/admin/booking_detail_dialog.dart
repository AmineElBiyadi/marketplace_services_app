import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_dashboard_service.dart';
import '../../theme/app_colors.dart';

class BookingDetailDialog extends StatefulWidget {
  final String bookingId;
  const BookingDetailDialog({super.key, required this.bookingId});

  @override
  State<BookingDetailDialog> createState() => _BookingDetailDialogState();
}

class _BookingDetailDialogState extends State<BookingDetailDialog> {
  final AdminDashboardService _service = AdminDashboardService();
  bool _loading = true;
  Map<String, dynamic>? _booking;
  List<Map<String, dynamic>> _timeline = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await _service.getFilteredReservations(query: widget.bookingId, limit: 1);
      if (results.isNotEmpty) {
        _booking = results.first;
        _timeline = await _service.getReservationTimeline(widget.bookingId);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final TextEditingController reasonController = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Changer le statut en $status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Indiquez une raison pour ce changement :'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ex: Demande du client...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.isNotEmpty) {
      setState(() => _loading = true);
      try {
        await _service.updateReservationStatus(widget.bookingId, status, reason: reasonController.text);
        await _loadData();
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
           setState(() => _loading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1024;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: isMobile ? screenWidth : screenWidth * 0.75,
        height: MediaQuery.of(context).size.height * 0.9,
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            _buildHeader(isMobile),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : (_booking == null ? const Center(child: Text('Non trouvé')) : _buildContent(isMobile)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          const Icon(LucideIcons.calendarDays, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Réservation #${widget.bookingId.substring(0, 8)}', 
              style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (_booking != null) _buildStatusBadge(_booking!['status']),
          const SizedBox(width: 8),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, size: 20)),
        ],
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          if (isMobile) ...[
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildProfilesCard(),
            const SizedBox(height: 16),
            _buildActionsCard(),
            const SizedBox(height: 16),
            _buildTimelineCard(),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildInfoCard()),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildProfilesCard()),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildTimelineCard()),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildActionsCard()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return _cardWrapper(
      title: 'Informations',
      icon: LucideIcons.info,
      child: Column(
        children: [
          _infoRow('Service', _booking!['service']),
          _infoRow('Date & Heure', '${_booking!['date']} à ${_booking!['time']}'),
          _infoRow('Prix', '${_booking!['amount']} DH', isBold: true, valueColor: Colors.green),
          _infoRow('Urgence', _booking!['isUrgent'] ? 'URGENT' : 'NORMAL', valueColor: _booking!['isUrgent'] ? Colors.red : null),
          if ((_booking!['status'] == 'ANNULEE' || _booking!['status'] == 'REFUSEE') && 
              (_booking!['motifAnnulation'] != null || _booking!['motifRefus'] != null))
            _infoRow(
              'Motif', 
              _booking!['motifAnnulation'] ?? _booking!['motifRefus'] ?? 'N/A', 
              valueColor: Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return _cardWrapper(
      title: 'Suivi de l\'intervention',
      icon: LucideIcons.activity,
      child: _timeline.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Aucune action enregistrée pour le moment', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
              ),
            )
          : Column(
              children: List.generate(_timeline.length, (index) {
                return _buildTimelineItem(_timeline[index], index == _timeline.length - 1);
              }),
            ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> log, bool isLast) {
    final timestamp = log['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('dd/MM HH:mm').format(timestamp.toDate()) : '--:--';
    final status = log['toStatus'] ?? 'ACTION';
    
    Color statusColor = AppColors.primary;
    if (status == 'ACCEPTEE') statusColor = Colors.green;
    else if (status == 'ANNULEE' || status == 'REFUSEE') statusColor = Colors.red;
    else if (status == 'TERMINEE') statusColor = Colors.blue;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFFE2E8F0)),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        status.replaceAll('_', ' '), 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
                      ),
                      Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  if (log['note'] != null && log['note'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log['note'], 
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesCard() {
    return _cardWrapper(
      title: 'Contacts',
      icon: LucideIcons.users,
      child: Column(
        children: [
          _profileItem('Client', _booking!['clientName']),
          const Divider(height: 24),
          _profileItem('Expert', _booking!['expertName']),
        ],
      ),
    );
  }

  Widget _profileItem(String role, String name) {
    return Row(
      children: [
        const CircleAvatar(radius: 16, child: Icon(LucideIcons.user, size: 16)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return _cardWrapper(
      title: 'Actions',
      icon: LucideIcons.shieldCheck,
      child: Column(
        children: [
          _actionBtn('Accepter', Colors.green, () => _updateStatus('ACCEPTEE')),
          const SizedBox(height: 8),
          _actionBtn('Annuler', Colors.red, () => _updateStatus('ANNULEE')),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(side: BorderSide(color: color), foregroundColor: color),
        child: Text(label),
      ),
    );
  }

  Widget _cardWrapper({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: valueColor, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'ACCEPTEE') color = Colors.green;
    else if (status == 'TERMINEE') color = Colors.blue;
    else if (status == 'EN_ATTENTE') color = Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
