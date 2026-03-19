import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';

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
          
          final subscription = snapshot.data; // null = free, or Map with id, type, dateDebut, etc.
          final isPremium = subscription != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Mon abonnement",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                Text(
                  isPremium ? "Découvrez votre impact et vos statistiques" : "Gérez votre pack et vos paiements",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                
                _buildCurrentPlanCard(isPremium),
                const SizedBox(height: 24),

                if (isPremium) ...[
                  // Subscription details card
                  _buildSubscriptionDetailsCard(subscription),
                  const SizedBox(height: 24),
                  const Text(
                    "Statistiques de performance",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  _buildPremiumStats(subscription),
                  const SizedBox(height: 32),
                  // Cancel subscription button
                  _buildCancelButton(subscription['id'] as String),
                ] else ...[
                  const Text(
                    "Avantages du plan Gratuit",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  _buildFreeAdvantages(),
                  const SizedBox(height: 32),
                  const Text(
                    "Comparer les plans",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  _buildComparisonTable(),
                  const SizedBox(height: 24),
                  _buildUpgradeButton(),
                ],
                
                const SizedBox(height: 32),
                const Text(
                  "Historique des paiements",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                _buildPaymentHistory(isPremium),
              ],
            ),
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
      dateTxt = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    final type = sub['type'] ?? 'PREMIUM';
    final montant = sub['montant'] ?? 99;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4A90D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.crown, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('Abonnement $type', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text('ACTIF', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _subDetailItem(LucideIcons.calendar, 'Début', dateTxt.isEmpty ? '--' : dateTxt),
              _subDetailItem(LucideIcons.banknote, 'Montant', '$montant DH/mois'),
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
        label: const Text("Annuler mon abonnement", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  void _showCancelModal(String subscriptionId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 22),
          SizedBox(width: 10),
          Text("Confirmer l'annulation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          "Êtes-vous sûr de vouloir annuler votre abonnement Premium ?\nVous reviendrez au plan Gratuit immédiatement.",
          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Non, garder Premium", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestoreService.cancelSubscription(subscriptionId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Abonnement annulé."), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Oui, annuler"),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard(bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isPremium ? AppColors.accent : AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? AppColors.accent : AppColors.primary).withOpacity(0.1), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPremium ? AppColors.accent : AppColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Plan actuel",
                  style: TextStyle(
                    color: isPremium ? AppColors.accent : AppColors.primary, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPremium ? "Premium ⭐" : "Gratuit",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              Text(
                isPremium ? "99 DH/mois" : "0 DH/mois",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          Text(isPremium ? "🌟" : "📦", style: const TextStyle(fontSize: 40)),
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

            // ── Subscription Revenue Summary ───────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.trendingUp, color: Colors.green, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Revenu total abonnement', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '${totalRevenue.toStringAsFixed(0)} DH',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          '$monthsElapsed mois × $pricePerMonth DH',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
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
                  const Text('Revenus d\'abonnement par mois', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const Text('(99 DH/mois)', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
        onPressed: _showPaymentModal,
        icon: const Icon(LucideIcons.crown, size: 20),
        label: const Text("Passer Premium — 99 DH/mois", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _showPaymentModal() {
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text("Paiement sécurisé", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Entrez vos informations de carte pour passer Premium (99 DH/mois).", style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: cardNumberController,
                    decoration: InputDecoration(
                      labelText: "Numéro de carte",
                      hintText: "0000 0000 0000 0000",
                      prefixIcon: const Icon(LucideIcons.creditCard),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: expiryController,
                          decoration: InputDecoration(
                            labelText: "MM/AA",
                            hintText: "12/28",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cvvController,
                          decoration: InputDecoration(
                            labelText: "CVV",
                            hintText: "123",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      // 2. Create premium subscription in abonnements
                      await _firestoreService.subscribeToPremium(_resolvedExpertId!);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Félicitations ! Vous êtes maintenant Premium 🌟"),
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
}
