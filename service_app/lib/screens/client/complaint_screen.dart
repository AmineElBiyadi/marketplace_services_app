import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../models/booking.dart';
import '../../services/notification_service.dart';

class ComplaintScreen extends StatefulWidget {
  final String interventionId;
  // 'client' ou 'expert'
  final String role;

  const ComplaintScreen({
    Key? key,
    required this.interventionId,
    this.role = 'client',
  }) : super(key: key);

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  InterventionModel? _intervention;

  @override
  void initState() {
    super.initState();
    _loadIntervention();
  }

  Future<void> _loadIntervention() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('interventions')
          .doc(widget.interventionId)
          .get();
      if (doc.exists) {
        _intervention = InterventionModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Error loading intervention: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComplaint() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please describe your problem"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final complaintData = {
        'idIntervention': widget.interventionId,
        'idClient': _intervention?.idClient,
        'idExpert': _intervention?.idExpert,
        'description': description,
        'etatReclamation': 'EN_ATTENTE',
        'typeReclamateur': widget.role == 'expert' ? 'EXPERT' : 'CLIENT',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('reclamations').add(complaintData);

      // Notify Admin
      await _notificationService.sendNotification(
        idUtilisateur: 'user_admin_001',
        titre: "New Complaint",
        corps: "A new complaint has been filed by ${widget.role == 'expert' ? 'an expert' : 'a client'} for intervention ID: ${widget.interventionId}.",
        type: 'claim',
        relatedId: widget.interventionId,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                const SizedBox(height: 16),
                const Text(
                  "Complaint Submitted",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Our team will review your complaint and get back to you as soon as possible.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      context.pop();
                    },
                    child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _intervention == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Si l'expert réclame → afficher les infos du client, sinon les infos de l'expert
    final isExpert = widget.role == 'expert';
    final personSnap = isExpert
        ? (_intervention?.clientSnapshot ?? {})
        : (_intervention?.expertSnapshot ?? {});
    final personName = personSnap['nom'] ?? (isExpert ? 'Client' : 'Expert');
    final personPhoto = personSnap['photo'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Report a Problem", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isExpert ? "File a complaint" : "What went wrong?",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              isExpert
                  ? "Describe the problem encountered with this client. Our team will review your complaint."
                  : "We take your feedback seriously. Please tell us what happened with this booking.",
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 32),
            
            // Expert Card (Static info)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: personPhoto.isNotEmpty ? NetworkImage(personPhoto) : null,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: personPhoto.isEmpty ? const Icon(Icons.person, color: AppColors.primary) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(personName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          isExpert ? "Intervention ID: ${widget.interventionId}" : "Booking ID: ${widget.interventionId}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Text(
              "Issue details",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Tell us more about the problem...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitComplaint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        isExpert ? "Send Complaint" : "Submit Complaint",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
             const SizedBox(height: 24),
            const Center(
              child: Text(
                "Our support team will contact you within 24 hours.",
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
