import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../models/booking.dart';
import '../../models/task_model.dart';
import '../../models/chat_model.dart';
import '../chat/chat_screen.dart';

const _tabs = ["Pending", "Confirmed", "Completed", "Cancelled", "Refused"];
const _tabStatusMap = {
  "Pending": "EN_ATTENTE",
  "Confirmed": "ACCEPTEE",
  "Completed": "TERMINEE",
  "Cancelled": "ANNULEE",
  "Refused": "REFUSEE",
};

class ProviderReservationsScreen extends StatefulWidget {
  final String expertId;
  const ProviderReservationsScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderReservationsScreen> createState() => _ProviderReservationsScreenState();
}

class _ProviderReservationsScreenState extends State<ProviderReservationsScreen> {
  int _selectedTab = 0;

  Color _statusColor(String status) {
    switch (status) {
      case "ACCEPTEE": return AppColors.primary;
      case "TERMINEE": return Colors.green;
      case "ANNULEE": return Colors.red;
      case "REFUSEE": return Colors.red.shade900;
      default: return const Color(0xFFF5C518); // EN_ATTENTE
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case "EN_ATTENTE": return const Color(0xFF7A5C00);
      case "ANNULEE": return Colors.red.shade700;
      case "REFUSEE": return Colors.red.shade100;
      default: return Colors.white;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case "EN_ATTENTE": return "Pending";
      case "ACCEPTEE": return "Confirmed";
      case "TERMINEE": return "Completed";
      case "ANNULEE": return "Cancelled";
      case "REFUSEE": return "Rejected";
      default: return "Pending";
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Not defined";
    final months = ["Jan", "Fév", "Mar", "Avr", "Mai", "Juin", "Juil", "Aoû", "Sep", "Oct", "Nov", "Déc"];
    final month = months[date.month - 1];
    return "${date.day} $month, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _handleChatTap(InterventionModel intervention) async {
    final clientId = intervention.idClient;
    final expertId = intervention.idExpert;
    
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('idIntervention', isEqualTo: intervention.id)
        .limit(1)
        .get();
        
    DocumentSnapshot chatDoc;
    if (chatQuery.docs.isNotEmpty) {
      chatDoc = chatQuery.docs.first;
    } else {
      final newChatRef = FirebaseFirestore.instance.collection('chats').doc();
      final data = {
        'idIntervention': intervention.id,
        'idClient': clientId,
        'idExpert': expertId,
        'estOuvert': true,
        'DateFin': null,
        'nbMessagesNonLus': 0,
        'clientSnapshot': intervention.clientSnapshot ?? {'nom': 'Client', 'photo': ''},
        'expertSnapshot': intervention.expertSnapshot ?? {'nom': 'Expert', 'photo': ''},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await newChatRef.set(data);
      chatDoc = await newChatRef.get();
    }
    
    if (mounted) {
      final chatModel = ChatModel.fromDoc(chatDoc);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chat: chatModel,
            currentUserRole: 'expert',
          ),
        ),
      );
    }
  }

  Future<void> _updateStatus(String interventionId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('interventions').doc(interventionId).update({
        'statut': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated ($newStatus)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showDetailsDialog(InterventionModel intervention) async {
    final dateDebut = intervention.dateDebutIntervention;
    final tacheSnap = intervention.tacheSnapshot ?? {};
    final taskName = tacheSnap['nom'] ?? 'Task not specified';

    final adresseSnap = intervention.adresseSnapshot ?? {};
    final fullAddress = "${adresseSnap['Quartier'] ?? ''}, ${adresseSnap['Ville'] ?? ''}".trim().replaceAll(RegExp(r'^,\s*|\s*,\s*$'), '');
    final displayAddress = fullAddress.isEmpty ? "Address not specified" : fullAddress;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Intervention Details",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (intervention.statut != 'REFUSEE') ...[
                  _buildDetailRow(Icons.calendar_today, "Date", _formatDate(dateDebut)),
                  const SizedBox(height: 12),
                ],
                _buildDetailRow(Icons.handyman_outlined, "Task", taskName),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.location_on_outlined, "Address", displayAddress),
                if (intervention.statut == 'ANNULEE' && intervention.motifeAnnulation != null && intervention.motifeAnnulation!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.cancel_outlined, "Cancellation reason", intervention.motifeAnnulation!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCancelDialog(InterventionModel intervention) async {
    TextEditingController reasonController = TextEditingController();
    String? errorText;

    if (!mounted) return;

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
                      "Cancel Intervention",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please provide a reason for cancellation (will be sent to admin).",
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
                              'annulerPar': 'expert',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Intervention cancelled successfully.")),
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

  Future<void> _showValidationCodeDialog(InterventionModel intervention) async {
    TextEditingController codeController = TextEditingController();
    String? errorText;

    if (!mounted) return;

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
                      "Validation Code",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Ask the client for the code to complete the intervention.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: "Code",
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
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final inputCode = codeController.text.trim();
                          if (inputCode.isEmpty) {
                            setDialogState(() => errorText = "Code is required");
                            return;
                          }
                          
                          if (inputCode == intervention.codeValidationExpert) {
                            try {
                              await FirebaseFirestore.instance.collection('interventions').doc(intervention.id).update({
                                'statut': 'TERMINEE',
                                'dateFinIntervention': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Status updated (TERMINEE)')),
                                );
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              setDialogState(() => errorText = "Error updating status: $e");
                            }
                          } else {
                            setDialogState(() => errorText = "Invalid code");
                          }
                        },
                        child: const Text("Confirm", style: TextStyle(color: Colors.white, fontSize: 16)),
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

  Future<void> _showAcceptDialog(InterventionModel intervention) async {
    DateTime? selectedDate;
    TextEditingController prixController = TextEditingController();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Accept Intervention",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      const Text("Date and Time", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            if (!mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setModalState(() {
                                selectedDate = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate == null ? "Select date" : _formatDate(selectedDate),
                                style: TextStyle(
                                  color: selectedDate == null ? Colors.grey.shade500 : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              Icon(Icons.calendar_month, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Negotiated Price (DH)", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: prixController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "Ex: 150",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Cette donnée est utilisée uniquement pour améliorer votre expérience.",
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            if (selectedDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select date')),
                              );
                              return;
                            }
                            
                            final prixStr = prixController.text.trim();
                            if (prixStr.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter the negotiated price')),
                              );
                              return;
                            }

                            final prix = double.tryParse(prixStr);
                            if (prix == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Valid price required')),
                              );
                              return;
                            }
                            
                            final updateData = {
                              'statut': 'ACCEPTEE',
                              'dateDebutIntervention': Timestamp.fromDate(selectedDate!),
                              'prixNegocie': prix,
                              'updatedAt': FieldValue.serverTimestamp(),
                            };
                            
                            try {
                              await FirebaseFirestore.instance.collection('interventions').doc(intervention.id).update(updateData);
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Intervention accepted')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          child: const Text("Confirm Acceptance", style: TextStyle(color: Colors.white, fontSize: 16)),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final selected = _selectedTab == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedTab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: selected
                        ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Text(
                    _tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(InterventionModel intervention) {
    final status = intervention.statut;
    final isPending = status == 'EN_ATTENTE';
    final isConfirmed = status == 'ACCEPTEE';
    final isCompleted = status == 'TERMINEE';
    final isCancelled = status == 'ANNULEE';
    final isRefused = status == 'REFUSEE';
    final hasDetails = isConfirmed || isCompleted || isCancelled;

    final clientSnap = intervention.clientSnapshot ?? {};
    final clientName = clientSnap['nom'] ?? 'Unknown Client';
    final clientPhoto = clientSnap['photo'] ?? '';

    final tacheSnap = intervention.tacheSnapshot ?? {};
    final serviceName = tacheSnap['serviceNom'] ?? 'Service not specified';
    final taskName = tacheSnap['nom'] ?? 'Task not specified';
    
    final adresseSnap = intervention.adresseSnapshot ?? {};
    final fullAddress = "${adresseSnap['Quartier'] ?? ''}, ${adresseSnap['Ville'] ?? ''}".trim().replaceAll(RegExp(r'^,\s*|\s*,\s*$'), '');
    final displayAddress = fullAddress.isEmpty ? "Address not specified" : fullAddress;

    final dateDebut = intervention.dateDebutIntervention;

    String avatarInitials = "C";
    if (clientName != null && clientName.isNotEmpty) {
      final parts = clientName.split(" ");
      if (parts.length > 1) {
        avatarInitials = "${parts[0][0]}${parts[1][0]}".toUpperCase();
      } else {
        avatarInitials = clientName.substring(0, 1).toUpperCase();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    image: clientPhoto.isNotEmpty
                        ? DecorationImage(image: NetworkImage(clientPhoto), fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: clientPhoto.isEmpty
                      ? Text(
                          avatarInitials,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              clientName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        serviceName == 'Service not specified' ? taskName : serviceName,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.handyman_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(taskName, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(displayAddress, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        ],
                      ),
                      if (!isPending && !isRefused) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(dateDebut),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    if (!isRefused) 
                      GestureDetector(
                        onTap: () => _handleChatTap(intervention),
                        child: Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AppColors.primary),
                      ),
                    if (!isRefused) const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(status == "EN_ATTENTE" ? 1.0 : 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatStatusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusTextColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (hasDetails) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Intervention details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  GestureDetector(
                    onTap: () => _showDetailsDialog(intervention),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.remove_red_eye_outlined, size: 20, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
            if (isConfirmed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: "Cancel",
                      icon: Icons.close,
                      color: Colors.red,
                      filled: false,
                      onTap: () => _showCancelDialog(intervention),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      label: "Complete",
                      icon: Icons.check_circle_outline,
                      color: AppColors.primary,
                      filled: true,
                      onTap: () => _showValidationCodeDialog(intervention),
                    ),
                  ),
                ],
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: "Accept",
                      icon: Icons.check,
                      color: Colors.green,
                      filled: true,
                      onTap: () => _showAcceptDialog(intervention),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      label: "Reject",
                      icon: Icons.close,
                      color: Colors.red,
                      filled: false,
                      onTap: () => _updateStatus(intervention.id!, "REFUSEE"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = _tabStatusMap[_tabs[_selectedTab]]!;
    final isWide = MediaQuery.of(context).size.width >= 700;

    double gridExtent = 250;
    switch (currentStatus) {
      case "EN_ATTENTE": gridExtent = 230; break;
      case "ACCEPTEE": gridExtent = 310; break; // +55 for the extra lines
      case "TERMINEE": 
      case "ANNULEE": 
        gridExtent = 220; // +55 for the extra lines
        break;
      case "REFUSEE": 
        gridExtent = 180; 
        break;
    }

    return ProviderLayout(
      activeRoute: '/provider/bookings',
      expertId: widget.expertId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isWide ? 32 : 20, 32, 20, 0),
            child: const Text(
              "Reservations",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 0),
            child: _buildTabBar(),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('interventions')
                  .where('idExpert', isEqualTo: widget.expertId)
                  .where('statut', isEqualTo: currentStatus)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                List<InterventionModel> interventions = docs
                    .map((doc) => InterventionModel.fromFirestore(doc))
                    .toList();
                
                interventions.sort((a, b) {
                  final t1 = a.updatedAt;
                  final t2 = b.updatedAt;
                  if (t1 == null && t2 == null) return 0;
                  if (t1 == null) return 1;
                  if (t2 == null) return -1;
                  return t2.compareTo(t1);
                });

                if (interventions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          "No reservations found",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Bookings with status \"${_tabs[_selectedTab]}\" will appear here.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (isWide) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(32, 4, 32, 24),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 480,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: gridExtent,
                    ),
                    itemCount: interventions.length,
                    itemBuilder: (_, i) => _buildCard(interventions[i]),
                  );
                } else {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: interventions.length,
                    itemBuilder: (_, i) => _buildCard(interventions[i]),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
