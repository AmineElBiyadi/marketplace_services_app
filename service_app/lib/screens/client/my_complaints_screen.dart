import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_colors.dart';
import '../../widgets/shared/client_header.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  final _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _allComplaints = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final clientQuery = await FirebaseFirestore.instance
          .collection('clients')
          .where('idUtilisateur', isEqualTo: uid)
          .limit(1)
          .get();

      if (clientQuery.docs.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final clientId = clientQuery.docs.first.id;
      final complaints = await _firestoreService.getClientComplaints(clientId, authUid: uid);
      if (mounted) {
        setState(() {
          _allComplaints = complaints;
          _filtered = complaints;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'ALL') {
        _filtered = _allComplaints;
      } else {
        _filtered = _allComplaints.where((c) => c['etat'] == filter).toList();
      }
    });
  }

  Widget build(BuildContext context) {
    const bgColor = Color(0xFFFBFBFB);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            ClientHeader(
              title: 'My Complaints',
              subtitle: 'Track issues you reported',
              showBackButton: true,
            ),
            const SizedBox(height: 16),
            // ── Filter chips ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  _buildChip('All', 'ALL'),
                  const SizedBox(width: 8),
                  _buildChip('Pending', 'EN_ATTENTE'),
                  const SizedBox(width: 8),
                  _buildChip('Resolved', 'TRAITEE'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── List ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildComplaintCard(_filtered[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    const primaryBlue = Color(0xFF2A4278);
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => _applyFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade300),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No complaints', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text("Complaints you make on bookings will appear here.", style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    const primaryBlue = Color(0xFF2A4278);
    final etat = complaint['etat'] as String? ?? 'EN_ATTENTE';
    final isResolved = etat == 'TRAITEE';
    final expertNom = complaint['expertNom'] as String? ?? 'Expert';
    final description = complaint['description'] as String? ?? '';
    final adminResponse = complaint['adminResponse'] as String? ?? '';
    final date = complaint['date'];

    String dateStr = '';
    if (date != null && date is Timestamp) {
      dateStr = DateFormat('dd MMM yyyy').format(date.toDate());
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(
          color: isResolved ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expertNom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryBlue)),
                    Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isResolved ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isResolved ? 'Resolved' : 'Pending',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isResolved ? const Color(0xFF065F46) : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
            ),
          ],
          if (adminResponse.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, size: 16, color: Color(0xFF0369A1)),
                      SizedBox(width: 8),
                      Text('Admin Response', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0369A1))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(adminResponse, style: const TextStyle(fontSize: 13, color: Color(0xFF0C4A6E), height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
