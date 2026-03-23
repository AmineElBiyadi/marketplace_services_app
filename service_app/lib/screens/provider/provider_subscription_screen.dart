import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';
import 'dart:convert';

class ProviderSubscriptionScreen extends StatefulWidget {
  final String expertId;
  
  const ProviderSubscriptionScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderSubscriptionScreen> createState() => _ProviderSubscriptionScreenState();
}

class _ProviderSubscriptionScreenState extends State<ProviderSubscriptionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Stream<bool>? _isPremiumStream;
  String? _resolvedExpertId;
  bool _isSubscribing = false;
  bool _isReactivating = false;
  bool _isLoading = false;
  Map<String, dynamic>? _suspendedSub; // cached suspended subscription for reactivation

  @override
  void initState() {
    super.initState();
    _resolveAndInit();
  }

  Future<void> _resolveAndInit() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      try {
        final expertId = await _firestoreService.getExpertIdByEmail(currentUser.email!);
        if (expertId != null) {
          _resolvedExpertId = expertId;
        } else {
          _resolvedExpertId = widget.expertId;
        }
      } catch (e) {
        _resolvedExpertId = widget.expertId;
      }
    } else {
      _resolvedExpertId = widget.expertId;
    }
    
    if (mounted) {
      setState(() {
        _isPremiumStream = _firestoreService.isExpertPremium(_resolvedExpertId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedExpertId == null || _isPremiumStream == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return ProviderLayout(
      activeRoute: '/provider/subscriptions',
      expertId: _resolvedExpertId!,
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: _firestoreService.getActiveSubscription(_resolvedExpertId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final subscription = snapshot.data; // null = free, or Map with id, type, statut, etc.
          final statut = (subscription?['statut'] ?? '').toString().toUpperCase();
          final isPremium = subscription != null; // ACTIVE or GRACE
          final isGrace = statut == 'GRACE';

          // When subscription is null, also check for SUSPENDU
          return FutureBuilder<QuerySnapshot>(
            future: subscription == null
                ? FirebaseFirestore.instance
                    .collection('abonnements')
                    .where('idExpert', isEqualTo: _resolvedExpertId!)
                    .where('statut', isEqualTo: 'SUSPENDU')
                    .limit(1)
                    .get()
                : null,
            builder: (context, suspendedSnap) {
              Map<String, dynamic>? suspendedSub;
              if (subscription == null &&
                  suspendedSnap.hasData &&
                  suspendedSnap.data!.docs.isNotEmpty) {
                final doc = suspendedSnap.data!.docs.first;
                suspendedSub = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
              }
              _suspendedSub = suspendedSub;
              final isSuspended = suspendedSub != null;

              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mon abonnement",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B)),
                    ),
                    Text(
                      isPremium
                          ? "Découvrez votre impact et vos statistiques"
                          : isSuspended
                              ? "Votre abonnement est suspendu"
                              : "Gérez votre pack et vos paiements",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // ── Plan card ──
                    if (isPremium)
                      _buildCurrentPlanCard(true, isGrace: isGrace)
                    else if (isSuspended)
                      _buildSuspendedCard(suspendedSub)
                    else
                      _buildCurrentPlanCard(false),

                    const SizedBox(height: 24),

                    if (isPremium) ...[
                      if (isGrace) _buildGraceBanner(),
                      if (isGrace) const SizedBox(height: 16),
                      _buildSubscriptionDetailsCard(subscription),
                      const SizedBox(height: 16),
                      _buildPaymentMethodSection(),
                      const SizedBox(height: 24),
                      const Text(
                        "Statistiques de performance",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      _buildPremiumStats(subscription),
                      const SizedBox(height: 32),
                      _buildCancelButton(subscription['id'] as String),
                    ] else if (!isSuspended) ...[
                      const Text(
                        "Avantages du plan Gratuit",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      _buildFreeAdvantages(),
                      const SizedBox(height: 32),
                      const Text(
                        "Comparer les plans",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      _buildComparisonTable(),
                      const SizedBox(height: 24),
                      _buildUpgradeButton(),
                    ],

                    const SizedBox(height: 32),
                    const Text(
                      "Historique des paiements",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentHistory(isPremium || isSuspended),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionDetailsCard(Map<String, dynamic> sub) {
    final dateDebut = sub['dateDebut'];
    String dateTxt = '';
    if (dateDebut is Timestamp) {
      final d = dateDebut.toDate();
      dateTxt =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    final type = sub['type'] ?? 'PREMIUM';
    final montant = sub['montant'] ?? 99;
    final statut = (sub['statut'] ?? 'ACTIVE').toString().toUpperCase();
    final isGrace = statut == 'GRACE';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGrace
              ? [const Color(0xFFD97706), const Color(0xFFF59E0B)]
              : [const Color(0xFF6C63FF), const Color(0xFF4A90D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: (isGrace ? const Color(0xFFD97706) : const Color(0xFF6C63FF))
                  .withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isGrace ? LucideIcons.alertTriangle : LucideIcons.crown,
                  color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('Abonnement $type',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  isGrace ? 'GRÂCE' : 'ACTIF',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _subDetailItem(LucideIcons.calendar, 'Début',
                  dateTxt.isEmpty ? '--' : dateTxt),
              _subDetailItem(
                  LucideIcons.banknote, 'Montant', '$montant DH/mois'),
              _subDetailItem(LucideIcons.refreshCw, 'Renouvellement', 'Auto'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subDetailItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildCancelButton(String subscriptionId) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _showCancelModal(subscriptionId),
        icon: const Icon(LucideIcons.xCircle, size: 18, color: Colors.red),
        label: const Text("Suspendre mon abonnement",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _firestoreService.getStoredCard(_resolvedExpertId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final card = snapshot.data;
        final cardNumber = card?['CardNumber'] ?? 'Aucune carte enregistrée';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.creditCard, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Moyen de paiement', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      cardNumber,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showPaymentModal(isUpdate: true),
                child: const Text('Mettre à jour', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCancelModal(String subscriptionId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Row(children: const [
          Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text("Suspendre l'abonnement",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: const Text(
          "Votre accès Premium sera coupé.\nVos données sont conservées (réactivation possible sans carte).",
          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Non, garder Premium",
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final services = await _firestoreService.getExpertServicesDetailed(_resolvedExpertId!);
                
                // 1. Check if services > 3
                if (services.length > 3) {
                  if (mounted) _showServiceSelectionDialog(subscriptionId, services);
                  return;
                }
                
                // 2. Check if any of these services has > 3 photos
                final allImages = await _firestoreService.getExpertPortfolioImagesWithDetails(_resolvedExpertId!);
                final Map<String, List<Map<String, dynamic>>> grouped = {};
                for (var img in allImages) {
                  grouped.putIfAbsent(img['idServiceExpert'], () => []).add(img);
                }
                final hasExceedingService = grouped.values.any((imgs) => imgs.length > 3);

                if (hasExceedingService) {
                  if (mounted) _showPhotoSelectionDialog(subscriptionId, allImages);
                  return;
                }
                
                await _firestoreService.cancelSubscription(subscriptionId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Abonnement suspendu."),
                        backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Erreur: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Oui, suspendre"),
          ),
        ],
      ),
    );
  }

  void _showServiceSelectionDialog(String subscriptionId, List<Map<String, dynamic>> services) {
    List<String> selectedIds = [];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isSelectionValid = selectedIds.length == 3;
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            titlePadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text("Sélectionnez 3 services", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                  ),
                ],
              ),
            ),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "En passant au plan gratuit, seuls 3 services resteront visibles. Les autres seront masqués pour vos clients.",
                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("${selectedIds.length}/3 sélectionnés", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelectionValid ? Colors.green : AppColors.primary)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final s = services[index];
                        final id = s['id'] as String;
                        final isSelected = selectedIds.contains(id);
                        
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          title: Text(s['serviceName'] ?? 'Service', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(s['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          value: isSelected,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                if (selectedIds.length < 3) selectedIds.add(id);
                              } else {
                                selectedIds.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: isSelectionValid ? () async {
                  Navigator.pop(ctx);
                  try {
                    // After services are hidden, check for photos
                    // After services are hidden, check for photos within the KEPT services
                    final allImages = await _firestoreService.getExpertPortfolioImagesWithDetails(_resolvedExpertId!);
                    final keptImages = allImages.where((img) => selectedIds.contains(img['idServiceExpert'])).toList();
                    
                    final Map<String, List<Map<String, dynamic>>> grouped = {};
                    for (var img in keptImages) {
                      grouped.putIfAbsent(img['idServiceExpert'], () => []).add(img);
                    }
                    final hasExceedingService = grouped.values.any((imgs) => imgs.length > 3);

                    if (hasExceedingService) {
                       if (mounted) _showPhotoSelectionDialog(subscriptionId, allImages, keptServiceIds: selectedIds);
                       return;
                    }

                    await _firestoreService.cancelSubscriptionAndSetVisibility(subscriptionId, _resolvedExpertId!, selectedIds);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Abonnement suspendu. Vos 3 services ont été conservés."), backgroundColor: Colors.orange),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
                      );
                    }
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Confirmer"),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildCurrentPlanCard(bool isPremium, {bool isGrace = false}) {
    Color accent;
    String planLabel;
    String emoji;
    String price;
    if (isPremium && !isGrace) {
      accent = AppColors.accent;
      planLabel = 'Premium ⭐';
      emoji = '🌟';
      price = '99 DH/mois';
    } else if (isPremium && isGrace) {
      accent = const Color(0xFFD97706);
      planLabel = 'Premium (Paiement en attente)';
      emoji = '⏳';
      price = '99 DH/mois';
    } else {
      accent = AppColors.primary;
      planLabel = 'Gratuit';
      emoji = '📦';
      price = '0 DH/mois';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Plan actuel",
                  style: TextStyle(
                      color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                planLabel,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B)),
              ),
              Text(
                price,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          Text(emoji, style: const TextStyle(fontSize: 40)),
        ],
      ),
    );
  }

  /// Card shown when the expert's subscription is SUSPENDU
  Widget _buildSuspendedCard(Map<String, dynamic>? sub) {
    final montant = (sub ?? {})['montant'] ?? 99;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEF4444), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Plan actuel",
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SUSPENDU',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Premium ⭐ — Suspendu',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B)),
                  ),
                  Text(
                    '$montant DH/mois',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const Text('🔒', style: TextStyle(fontSize: 36)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isReactivating ? null : _reactivateSubscription,
              icon: _isReactivating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(
                _isReactivating ? 'Réactivation...' : 'Réactiver mon abonnement',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Orange banner shown at the top of the premium section when statut == GRACE
  Widget _buildGraceBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Paiement en cours de traitement',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E)),
                ),
                SizedBox(height: 2),
                Text(
                  'Votre accès Premium est maintenu pendant 7 jours, le temps que Stripe réessaie le prélèvement (3 tentatives max).',
                  style:
                      TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeAdvantages() {
    final advantages = [
      {"icon": LucideIcons.checkCircle, "text": "Visibilité basique sur la plateforme"},
      {"icon": LucideIcons.checkCircle, "text": "Jusqu'à 3 services listés"},
      {"icon": LucideIcons.checkCircle, "text": "Statistiques simples dans le tableau de bord"},
      {"icon": LucideIcons.checkCircle, "text": "Notifications des nouvelles demandes"},
    ];

    return Column(
      children: advantages.map((adv) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(adv['icon'] as IconData, size: 18, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                adv['text'] as String,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPremiumStats(Map<String, dynamic> subscription) {
    // Calculate months elapsed from subscription createdAt
    final createdAtRaw = subscription['createdAt'];
    final DateTime subStart = (createdAtRaw is Timestamp)
        ? createdAtRaw.toDate()
        : DateTime.now();

    final now = DateTime.now();
    // Months elapsed since subscription started (at least 1)
    int monthsElapsed = ((now.year - subStart.year) * 12 + (now.month - subStart.month)) + 1;
    if (monthsElapsed < 1) monthsElapsed = 1;

    const double pricePerMonth = 99;
    final double totalRevenue = monthsElapsed * pricePerMonth;

    // Build bar data: one bar per month, going backwards from now
    // Show up to 6 months
    final int barsToShow = monthsElapsed.clamp(1, 6);
    final List<BarChartGroupData> barGroups = List.generate(barsToShow, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: pricePerMonth,
            color: i == barsToShow - 1 ? AppColors.primary : AppColors.primary.withOpacity(0.5),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });

    // Month labels for x-axis
    final List<String> monthLabels = List.generate(barsToShow, (i) {
      final d = DateTime(now.year, now.month - (barsToShow - 1 - i), 1);
      return '${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
    });

        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            _firestoreService.getExpertKPIs(_resolvedExpertId!),
            _firestoreService.getExpertPerformanceHistory(_resolvedExpertId!),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ));
            }

            // ignore: unused_local_variable
            final kpis = (snapshot.data?[0] as Map<String, dynamic>?) ?? {
              'reservations_today': '0', 'rating': '0.0', 'revenue': '0 DH', 'views': '0'
            };
            final history = (snapshot.data?[1] as List<Map<String, dynamic>>?) ?? [];

            // Convert history to LineChart data
            final List<FlSpot> spots = [];
            for (int i = 0; i < history.length; i++) {
              spots.add(FlSpot(i.toDouble(), (history[i]['count'] as int).toDouble()));
            }

            // Max value for Y axis
            double maxY = 5.0;
            for (var h in history) {
               if ((h['count'] as int) > maxY) maxY = (h['count'] as int).toDouble();
            }
            maxY = (maxY * 1.2).ceilToDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Performance Chart
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Évolution des réservations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              Text('Impact sur les 6 derniers mois', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const Icon(LucideIcons.barChart3, color: AppColors.primary, size: 24),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 220,
                        child: LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                tooltipBgColor: AppColors.primary,
                                tooltipRoundedRadius: 8,
                                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                                  return touchedBarSpots.map((barSpot) {
                                    return LineTooltipItem(
                                      '${barSpot.y.toInt()} Bookings',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (val, meta) {
                                    final idx = val.toInt();
                                    if (idx < 0 || idx >= history.length) return const SizedBox();
                                    final monthParts = history[idx]['month'].split('-');
                                    final mStr = _monthAbbr(int.parse(monthParts[1]));
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(mStr, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  interval: 1,
                                  getTitlesWidget: (v, meta) {
                                    if (v % 1 != 0) return const SizedBox();
                                    return Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0,
                            maxX: (history.length - 1).toDouble(),
                            minY: 0,
                            maxY: maxY,
                            lineBarsData: [
                              LineChartBarData(
                                shadow: const Shadow(color: Colors.black12, offset: Offset(0, 10), blurRadius: 8),
                                spots: spots,
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.white,
                                    strokeWidth: 3,
                                    strokeColor: AppColors.primary,
                                  ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.2),
                                      AppColors.primary.withOpacity(0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 24),


            // ── Bar Chart ──────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Coût mensuel de votre abonnement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const Text('Prélèvements de 99 DH/mois', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY: pricePerMonth * 1.3,
                        minY: 0,
                        barGroups: barGroups,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 50,
                              getTitlesWidget: (v, meta) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= monthLabels.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(monthLabels[idx], style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                              '${rod.toY.toInt()} DH',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _monthAbbr(int m) {
    const abbrs = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return abbrs[(m - 1).clamp(0, 11)];
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    final features = [
      {"name": "Nb services", "free": "3 max", "premium": "Illimité"},
      {"name": "Gestion d'agenda", "free": false, "premium": true},
      {"name": "Boost profil", "free": false, "premium": true},
      {"name": "Statistiques", "free": "Simples", "premium": "Avancées"},
      {"name": "Prix", "free": "0 DH", "premium": "99 DH/mois"},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("Fonctionnalité", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(child: Text("Gratuit", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(child: Text("Premium ⭐", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary))),
              ],
            ),
          ),
          ...features.map((f) => Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(f['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                Expanded(child: _buildValueCell(f['free'])),
                Expanded(child: _buildValueCell(f['premium'], isPremium: true)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildValueCell(dynamic value, {bool isPremium = false}) {
    if (value is bool) {
      return value 
        ? const Icon(LucideIcons.check, color: Colors.green, size: 16)
        : const Icon(LucideIcons.x, color: Colors.grey, size: 16);
    }
    return Text(
      value.toString(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12, 
        fontWeight: isPremium ? FontWeight.bold : FontWeight.normal,
        color: isPremium ? AppColors.primary : const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _checkCardAndUpgrade,
        icon: const Icon(LucideIcons.crown, size: 20),
        label: const Text("Passer Premium — 99 DH/mois",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Future<void> _checkCardAndUpgrade() async {
    final hasCard = await _firestoreService.hasStoredCard(_resolvedExpertId!);
    if (!mounted) return;
    if (hasCard) {
      // Card already on file — subscribe directly without re-entering card details
      setState(() => _isSubscribing = true);
      try {
        await _firestoreService.subscribeToPremium(_resolvedExpertId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Félicitations ! Vous êtes à nouveau Premium 🌟"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Erreur: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubscribing = false);
      }
    } else {
      // First time — show card entry form
      _showPaymentModal();
    }
  }

  Future<void> _reactivateSubscription() async {
    if (_suspendedSub == null) return;
    final subId = _suspendedSub!['id'] as String;
    setState(() => _isReactivating = true);
    try {
      final hasCard = await _firestoreService.hasStoredCard(_resolvedExpertId!);
      if (!mounted) return;
      if (hasCard) {
        await _firestoreService.reactivateSubscription(subId, _resolvedExpertId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Abonnement réactivé avec succès 🌟"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // No card on file → show payment modal for new card entry
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Votre carte a expiré. Veuillez saisir une nouvelle carte."),
              backgroundColor: Colors.orange,
            ),
          );
          _showPaymentModal();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isReactivating = false);
    }
  }

  void _showPaymentModal({bool isUpdate = false}) {
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text("Paiement sécurisé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUpdate 
                      ? "Entrez les détails de votre nouvelle carte."
                      : "Entrez vos informations de carte pour passer Premium (99 DH/mois).", 
                    style: const TextStyle(fontSize: 13, color: Colors.grey)
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: cardNumberController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: "Numéro de carte",
                      hintText: "0000 0000 0000 0000",
                      prefixIcon: const Icon(LucideIcons.creditCard, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: expiryController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "MM/AA",
                            hintText: "12/28",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cvvController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "CVV",
                            hintText: "123",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: TextInputType.number,
                          obscureText: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("Annuler", style: TextStyle(color: Colors.grey))
              ),
              if (_isSubscribing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    if (cardNumberController.text.isEmpty || expiryController.text.isEmpty || cvvController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Veuillez remplir tous les champs"), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    
                    setModalState(() => _isSubscribing = true);
                    try {
                      // 1. Save card info to cartesBancaires (masked)
                      await _firestoreService.saveCardInfo(
                        expertId: _resolvedExpertId!,
                        cardNumber: cardNumberController.text,
                        expiryDate: expiryController.text,
                        cvv: cvvController.text,
                      );
                      
                      if (!isUpdate) {
                        // 2. Create premium subscription in abonnements
                        await _firestoreService.subscribeToPremium(_resolvedExpertId!);
                      } else {
                        // Force refresh so FutureBuilder sees the new card
                        setState(() {});
                      }
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isUpdate ? "Carte mise à jour avec succès ✅" : "Félicitations ! Vous êtes maintenant Premium 🌟"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur lors du paiement: $e"), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setModalState(() => _isSubscribing = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Je Valide"),
                ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildPaymentHistory(bool isPremium) {
    if (!isPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text("Aucun paiement enregistré", style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _firestoreService.getPaymentHistory(_resolvedExpertId!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          );
        }

        final history = snap.data ?? [];
        if (history.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text("Aucun paiement enregistré", style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          );
        }

        return Column(
          children: history.map((p) {
            final isPaid = (p['status'] ?? '') == 'Payé';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPaid ? LucideIcons.checkCircle : LucideIcons.clock,
                      size: 18,
                      color: isPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Abonnement Premium',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                        Text(p['date'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(p['amount'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p['status'] ?? '',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

void _showPhotoSelectionDialog(String subscriptionId, List<Map<String, dynamic>> allImages, {List<String>? keptServiceIds}) {
    // 1. Group images by idServiceExpert (only including those from kept services)
    final Map<String, List<Map<String, dynamic>>> groupedImages = {};
    for (var img in allImages) {
      final seId = img['idServiceExpert'] as String;
      groupedImages.putIfAbsent(seId, () => []).add(img);
    }

    // 2. Identify services that have more than 3 photos
    final Map<String, List<Map<String, dynamic>>> servicesToPickFor = {};
    final List<String> autoKeepImageIds = [];

    groupedImages.forEach((seId, serviceImgs) {
      if (serviceImgs.length > 3) {
        servicesToPickFor[seId] = serviceImgs;
      } else {
        autoKeepImageIds.addAll(serviceImgs.map((img) => img['id'] as String));
      }
    });

    // If no service has > 3 photos, we can just proceed with automatic keeping
    if (servicesToPickFor.isEmpty) {
      _finishDowngrade(subscriptionId, keptServiceIds, autoKeepImageIds);
      return;
    }

    // Map to track selections per service: {seId: [selectedImageIds]}
    final Map<String, List<String>> selectionsPerService = {};
    servicesToPickFor.forEach((seId, _) => selectionsPerService[seId] = []);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          bool allSelectionsValid = true;
          servicesToPickFor.forEach((seId, _) {
            if (selectionsPerService[seId]!.length != 3) allSelectionsValid = false;
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            titlePadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.image, color: Colors.blue, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text("Gestion du Portfolio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                  ),
                ],
              ),
            ),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "En plan gratuit, vous pouvez garder 3 photos visibles par service. Sélectionnez vos meilleures réalisations !",
                        style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    ...servicesToPickFor.entries.map((entry) {
                      final seId = entry.key;
                      final serviceImgs = entry.value;
                      final serviceName = serviceImgs.first['serviceName'] ?? "Service";
                      final selectedCount = selectionsPerService[seId]!.length;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                Text("$selectedCount / 3", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selectedCount == 3 ? Colors.green : AppColors.primary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: serviceImgs.length,
                            itemBuilder: (context, index) {
                              final img = serviceImgs[index];
                              final id = img['id'] as String;
                              final taskName = img['taskName'] ?? "";
                              final isSelected = selectionsPerService[seId]!.contains(id);
                              final imageData = img['image'] as String;
                              
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            selectionsPerService[seId]!.remove(id);
                                          } else if (selectionsPerService[seId]!.length < 3) {
                                            selectionsPerService[seId]!.add(id);
                                          }
                                        });
                                      },
                                      child: Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300, width: 2),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: imageData.startsWith('http')
                                                  ? Image.network(imageData, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                                  : Image.memory(base64Decode(imageData.contains(',') ? imageData.split(',').last : imageData), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Positioned(
                                              top: 4, right: 4,
                                              child: Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    taskName,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: allSelectionsValid ? () async {
                  Navigator.pop(ctx);
                  
                  // Combine all selected IDs + auto-kept IDs
                  final List<String> finalKeptImageIds = [...autoKeepImageIds];
                  selectionsPerService.values.forEach((list) => finalKeptImageIds.addAll(list));
                  
                  _finishDowngrade(subscriptionId, keptServiceIds, finalKeptImageIds);
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Confirmer"),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _finishDowngrade(String subscriptionId, List<String>? keptServiceIds, List<String> finalKeptImageIds) async {
    try {
      setState(() => _isLoading = true);
      
      // Update visibility for both services and photos
      List<String> servicesToKeep = keptServiceIds ?? [];
      if (servicesToKeep.isEmpty) {
        final currentServices = await _firestoreService.getExpertServicesDetailed(_resolvedExpertId!);
        servicesToKeep = currentServices.map((s) => s['id'] as String).toList();
      }

      await _firestoreService.cancelSubscriptionAndSetVisibility(
        subscriptionId, 
        _resolvedExpertId!, 
        servicesToKeep,
        keptImageIds: finalKeptImageIds
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Abonnement suspendu. Vos choix ont été enregistrés."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
