import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../models/booking.dart';
import '../../services/notification_service.dart';

class BookingDetailScreen extends StatelessWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('interventions').doc(bookingId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Booking not found"));
          }

          final intervention = InterventionModel.fromFirestore(snapshot.data!);
          final status = intervention.statut;
          
          final expertSnap = intervention.expertSnapshot ?? {};
          final expertName = expertSnap['nom'] ?? 'Unknown Expert';
          final expertPhoto = expertSnap['photo'] ?? '';

          final tacheSnap = intervention.tacheSnapshot ?? {};
          final serviceName = tacheSnap['nom'] ?? 'Unspecified Service';

          final adresseSnap = intervention.adresseSnapshot ?? {};
          final fullAddress = "${adresseSnap['Quartier'] ?? ''}, ${adresseSnap['Ville'] ?? ''}";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Status card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _statusColor(status).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(_statusIcon(status), size: 48, color: _statusColor(status)),
                      const SizedBox(height: 12),
                      Text(
                        _formatStatusLabel(status),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _statusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Validation Code (if confirmed)
                if (status == 'ACCEPTEE' && intervention.codeValidationExpert != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3F64B5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3F64B5).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'VALIDATION CODE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          intervention.codeValidationExpert!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Give this code to the provider upon arrival",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Service details
                _buildSectionCard(
                  title: 'Service Details',
                  children: [
                    _buildDetailRow('Service', serviceName),
                    _buildDetailRow('Date', _formatDate(intervention.dateDebutIntervention)),
                    _buildDetailRow('Address', fullAddress),
                    if (status == 'ANNULEE' && (intervention.motifeAnnulation?.isNotEmpty ?? false))
                      _buildDetailRow('Cancellation Reason', intervention.motifeAnnulation!),
                  ],
                ),
                const SizedBox(height: 16),
                // Provider info
                _buildSectionCard(
                  title: 'Provider',
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                            image: expertPhoto.isNotEmpty
                                ? DecorationImage(image: NetworkImage(expertPhoto), fit: BoxFit.cover)
                                : null,
                          ),
                          child: expertPhoto.isEmpty
                              ? const Icon(Icons.person, color: AppColors.primary)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expertName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const Text(
                                'Verified Provider',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Actions
                if (status == 'ACCEPTEE' || status == 'EN_ATTENTE') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => _showCancelDialog(context, intervention),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Cancel Booking', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                if (status == 'TERMINEE') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.go('/review/$bookingId'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text('Leave a Review', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'EN_ATTENTE': return Colors.orange;
      case 'ACCEPTEE': return const Color(0xFF10B981);
      case 'TERMINEE': return const Color(0xFF3F64B5);
      case 'ANNULEE': return Colors.red;
      case 'REFUSEE': return Colors.grey;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'EN_ATTENTE': return Icons.timer_outlined;
      case 'ACCEPTEE': return Icons.check_circle_outline;
      case 'TERMINEE': return Icons.stars;
      case 'ANNULEE': return Icons.cancel_outlined;
      case 'REFUSEE': return Icons.block;
      default: return Icons.info_outline;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'EN_ATTENTE': return 'Pending';
      case 'ACCEPTEE': return 'Confirmed';
      case 'TERMINEE': return 'Completed';
      case 'ANNULEE': return 'Cancelled';
      case 'REFUSEE': return 'Refused';
      default: return status;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Not scheduled";
    return DateFormat('EEE d MMM yyyy, HH:mm').format(date);
  }

  Future<void> _showCancelDialog(BuildContext context, InterventionModel intervention) async {
    TextEditingController reasonController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Cancel Booking",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please provide a reason for cancellation.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Cancellation reason",
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final inputReason = reasonController.text.trim();
                          if (inputReason.isEmpty) {
                            setDialogState(() => errorText = "Reason is required");
                            return;
                          }
                          
                          try {
                            await FirebaseFirestore.instance.collection('interventions').doc(intervention.id).update({
                              'statut': 'ANNULEE',
                              'motifeAnnulation': inputReason,
                              'annulerPar': 'client',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            // Notify the Expert
                            try {
                              final expertDoc = await FirebaseFirestore.instance.collection('experts').doc(intervention.idExpert).get();
                              if (expertDoc.exists) {
                                final expertUid = expertDoc.data()?['idUtilisateur'];
                                if (expertUid != null) {
                                  final notificationService = NotificationService();
                                  await notificationService.sendNotification(
                                    idUtilisateur: expertUid,
                                    titre: "Réservation Annulée",
                                    corps: "Le client a annulé sa réservation pour '${intervention.tacheSnapshot?['nom'] ?? 'service'}'.",
                                    type: 'booking',
                                    relatedId: intervention.id,
                                  );
                                }
                              }
                            } catch (e) {
                              debugPrint('Error notifying expert on cancellation: $e');
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Booking cancelled successfully.")),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => errorText = "Connection error");
                          }
                        },
                        child: const Text("Confirm Cancellation", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Back", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
