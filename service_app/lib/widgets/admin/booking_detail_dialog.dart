import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../services/admin_dashboard_service.dart';
import '../../theme/app_colors.dart';
import 'user_profile_detail_dialog.dart';

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
  
  bool get isMobile => MediaQuery.of(context).size.width < 768;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final result = await _service.getReservationById(widget.bookingId);
      if (mounted) setState(() { _booking = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 1024;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : (isTablet ? screenWidth * 0.85 : 800),
        height: isMobile ? screenHeight * 0.85 : (isTablet ? screenHeight * 0.8 : 600),
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.95 : 800.0,
          maxHeight: isMobile ? screenHeight * 0.85 : 600.0,
        ),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(isMobile),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : (_booking == null ? const Center(child: Text('Booking not found')) : _buildContent(isMobile)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32, vertical: 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(LucideIcons.calendarDays, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Booking Details',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#${widget.bookingId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_booking != null) ...[
                      const SizedBox(width: 8),
                      _buildStatusBadge(_booking!['status'] ?? 'N/A'),
                    ],
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.calendarDays, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Booking Details', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      Text(
                        '#${widget.bookingId.substring(0, 8).toUpperCase()}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (_booking != null) _buildStatusBadge(_booking!['status'] ?? 'N/A'),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCancelBanner(),
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildProfilesCard(),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          _buildCancelBanner(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildInfoCard()),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildProfilesCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelBanner() {
    if ((_booking!['status'] != 'ANNULEE' && _booking!['status'] != 'CANCELLED') || (_booking!['cancelCount'] ?? 0) <= 0) return const SizedBox.shrink();
    
    final role = _booking!['cancelRole'] == 'expert' ? 'provider' : 'customer';
    final count = _booking!['cancelCount'];
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Warning: This $role has canceled $count reservation${count > 1 ? 's' : ''} this month.',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardWrapper({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return _cardWrapper(
      title: 'General Information',
      icon: LucideIcons.info,
      child: Column(
        children: [
          _modernInfoRow('Service', _booking!['service'] ?? 'N/A', LucideIcons.briefcase, isMobile: isMobile),
          _modernInfoRow('Date & Time', '${_booking!['date'] ?? 'N/A'} at ${_booking!['time'] ?? '--:--'}', LucideIcons.clock, isMobile: isMobile),
          _modernInfoRow('Service Price', '${_booking!['amount'] ?? 0} DH', LucideIcons.creditCard, isBold: true, valueColor: Colors.green, isLarge: true, isMobile: isMobile),
          if ((_booking!['status'] == 'ANNULEE' || _booking!['status'] == 'REFUSEE') && 
              (_booking!['motifAnnulation'] != null || _booking!['motifRefus'] != null))
            _modernInfoRow(
              'Reason', 
              _booking!['motifAnnulation'] ?? _booking!['motifRefus'] ?? 'N/A', 
              LucideIcons.fileWarning,
              valueColor: Colors.red,
              isMobile: isMobile,
            ),
        ],
      ),
    );
  }

  Widget _modernInfoRow(String label, String value, IconData icon, {bool isBold = false, Color? valueColor, bool isLarge = false, bool isMobile = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Row(
        children: [
          Icon(icon, size: isMobile ? 14 : 16, color: const Color(0xFF64748B)),
          SizedBox(width: isMobile ? 6 : 8),
          Expanded(
            flex: 2,
            child: Text(
              label, 
              style: TextStyle(
                color: const Color(0xFF64748B), 
                fontSize: isMobile ? 10 : 12
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Expanded(
            flex: 3,
            child: Text(
              value, 
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500, 
                color: valueColor ?? const Color(0xFF0F172A), 
                fontSize: isMobile ? (isLarge ? 13 : 11) : (isLarge ? 14 : 12),
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: isMobile ? 2 : 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesCard() {
    return _cardWrapper(
      title: 'Stakeholders',
      icon: LucideIcons.users,
      child: Column(
        children: [
          _modernProfileItem('Customer', _booking!['clientName'] ?? 'N/A', _booking!['idClient'], LucideIcons.user, isMobile: isMobile),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
          _modernProfileItem('Provider', _booking!['expertName'] ?? 'N/A', _booking!['idExpert'], LucideIcons.briefcase, isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _modernProfileItem(String role, String name, String? id, IconData icon, {bool isMobile = false}) {
    return InkWell(
      onTap: id != null ? () => _showUserProfileModal(id, role == 'Customer' ? 'Customer' : 'Provider') : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8, horizontal: isMobile ? 6 : 8),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 8 : 10),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: Icon(icon, size: isMobile ? 16 : 18, color: AppColors.primary),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role, 
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11, 
                      color: const Color(0xFF64748B), 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 0.5
                    )
                  ),
                  SizedBox(height: 2),
                  Text(
                    name, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: isMobile ? 13 : 15, 
                      color: const Color(0xFF0F172A)
                    ), 
                    overflow: TextOverflow.ellipsis,
                    maxLines: isMobile ? 2 : 1,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(isMobile ? 4 : 6),
              decoration: BoxDecoration(
                color: Colors.white, 
                border: Border.all(color: const Color(0xFFE2E8F0)), 
                shape: BoxShape.circle
              ),
              child: Icon(LucideIcons.chevronRight, size: isMobile ? 12 : 14, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserProfileModal(String id, String role) {
    showDialog(
      context: context,
      builder: (context) => UserProfileDetailDialog(id: id, role: role),
    );
  }

  Widget _buildStatusBadge(String status) {
    String label = status;
    Color color = Colors.grey;

    final s = status.toUpperCase();
    if (s == 'ACCEPTED' || s == 'ACCEPTEE' || s == 'CONFIRMEE') {
      label = 'ACCEPTED';
      color = Colors.green;
    } else if (s == 'COMPLETED' || s == 'TERMINEE') {
      label = 'COMPLETED';
      color = Colors.blue;
    } else if (s == 'PENDING' || s == 'EN_ATTENTE' || s == 'EN ATTENTE') {
      label = 'PENDING';
      color = Colors.orange;
    } else if (s == 'REJECTED' || s == 'REFUSEE') {
      label = 'REJECTED';
      color = Colors.red;
    } else if (s == 'CANCELLED' || s == 'ANNULEE' || s == 'CANCELED') {
      label = 'CANCELLED';
      color = Colors.grey;
    } else if (s == 'IN_PROGRESS' || s == 'EN_COURS') {
      label = 'IN PROGRESS';
      color = Colors.indigo;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
