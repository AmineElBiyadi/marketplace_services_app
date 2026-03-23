import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../services/firestore_service.dart';

class ClientCguScreen extends StatefulWidget {
  const ClientCguScreen({super.key});

  @override
  State<ClientCguScreen> createState() => _ClientCguScreenState();
}

class _ClientCguScreenState extends State<ClientCguScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "CGU / Confidentialité",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: false,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _firestoreService.fetchActiveCGU('CLIENT'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                "Aucune condition d'utilisation disponible.",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
              ),
            );
          }

          final cguData = snapshot.data!;
          final String content = cguData['content'] ?? '';
          final String version = cguData['version'] ?? 'Unknown';
          
          String dateFormatted = "Unknown date";
          if (cguData['created_at'] != null) {
            final DateTime date = (cguData['created_at'] as Timestamp).toDate();
            dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(date);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Conditions Générales d'Utilisation",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Version $version • Mis à jour le $dateFormatted",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF334155),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
