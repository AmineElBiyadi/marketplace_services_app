import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../models/booking.dart';

class ComplaintScreen extends StatefulWidget {
  final String interventionId;

  const ComplaintScreen({Key? key, required this.interventionId}) : super(key: key);

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
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
        const SnackBar(content: Text("Please describe your problem")),
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
        'typeReclamateur': 'CLIENT',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('reclamations').add(complaintData);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Complaint Submitted"),
            content: const Text("Our team will review your complaint and get back to you soon."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pop();
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _intervention == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Report a Problem")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Please describe the issue you're having with this booking."),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "Reason for complaint...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitComplaint,
                child: _isLoading ? const CircularProgressIndicator() : const Text("Submit Complaint"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
