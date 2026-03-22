import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/firestore_service.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      // Get the clientId from the clients collection
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
      final reviews = await _firestoreService.getClientReviews(clientId);
      if (mounted) setState(() { _reviews = reviews; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2A4278);
    const bgColor = Color(0xFFF8F9FC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Reviews', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildReviewCard(_reviews[index]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No reviews yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text("Reviews you leave on experts will appear here.", style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    const primaryBlue = Color(0xFF2A4278);
    final note = (review['note'] as double?) ?? 0.0;
    final expertNom = review['expertNom'] as String? ?? 'Expert';
    final expertPhoto = review['expertPhoto'] as String? ?? '';
    final tacheNom = review['tacheNom'] as String? ?? '';
    final commentaire = review['commentaire'] as String? ?? '';
    final date = review['date'];

    String dateStr = '';
    if (date != null && date is Timestamp) {
      dateStr = DateFormat('dd MMM yyyy').format(date.toDate());
    }

    ImageProvider? avatarImg;
    if (expertPhoto.isNotEmpty) {
      avatarImg = NetworkImage(expertPhoto);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expert header
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFDCDFEA),
                backgroundImage: avatarImg,
                child: avatarImg == null ? Text(expertNom[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBlue)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expertNom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryBlue)),
                    if (tacheNom.isNotEmpty)
                      Text(tacheNom, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 12),
          // Star rating
          Row(
            children: List.generate(5, (i) => Icon(
              i < note.round() ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFFBBF24),
              size: 20,
            )),
          ),
          if (commentaire.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(commentaire, style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
