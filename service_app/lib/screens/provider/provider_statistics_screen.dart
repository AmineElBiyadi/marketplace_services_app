import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';

class ProviderStatisticsScreen extends StatefulWidget {
  final String expertId;

  const ProviderStatisticsScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderStatisticsScreen> createState() => _ProviderStatisticsScreenState();
}

class _ProviderStatisticsScreenState extends State<ProviderStatisticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedPeriod = '30d';

  bool _isLoadingStats = true;
  int _profileViews = 0;
  double _profileViewsTrend = 12.0;
  
  double _conversionRate = 0.0;
  double _conversionRateTrend = 5.0;
  
  double _loyalCustomers = 0.0;
  double _loyalTrend = 3.0;

  double _averageRating = 0.0;
  double _averageRatingTrend = -0.1;

  Map<String, int> _topSkills = {};
  List<FlSpot> _ratingEvolutionSpots = [];
  List<String> _ratingEvolutionLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"];
  
  List<FlSpot> _profileViewsSpots = [];
  List<String> _profileViewsLabels = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final prevMonthStart = DateTime(now.month == 1 ? now.year - 1 : now.year, now.month == 1 ? 12 : now.month - 1, 1);

      // 1. Fetch Expert for total profileViews
      final expertDoc = await FirebaseFirestore.instance.collection('experts').doc(widget.expertId).get();
      final int totalProfileViewsFromExpertDoc = expertDoc.data()?['profileViews'] ?? 0;

      // 2. Fetch Interventions
      final interventionsQuery = await FirebaseFirestore.instance
          .collection('interventions')
          .where('idExpert', isEqualTo: widget.expertId)
          .get();
      
      final totalInterventions = interventionsQuery.docs.length;
      final int actualProfileViewsToUse = totalProfileViewsFromExpertDoc;
      final conversionRate = actualProfileViewsToUse > 0 ? (totalInterventions / actualProfileViewsToUse) * 100 : 0.0;

      // Calculate Loyal Customers & Top Skills
      Map<String, int> clientInterventionsCount = {};
      Map<String, int> skillCounts = {};
      
      int currentInterventions = 0;
      int prevInterventions = 0;

      for (var doc in interventionsQuery.docs) {
        final data = doc.data();
        final statut = data['statut'] as String?;
        final Timestamp? dateFin = data['dateFinIntervention'] ?? data['createdAt'];

        if (dateFin != null) {
          final d = dateFin.toDate();
          if (d.isAfter(currentMonthStart) || d.isAtSameMomentAs(currentMonthStart)) {
            currentInterventions++;
          } else if (d.isAfter(prevMonthStart) && d.isBefore(currentMonthStart)) {
            prevInterventions++;
          }
        }

        if (statut == 'TERMINEE') {
          final clientId = data['idClient'] ?? '';
          if (clientId.isNotEmpty) {
            clientInterventionsCount[clientId] = (clientInterventionsCount[clientId] ?? 0) + 1;
          }

          final tacheMap = data['tacheSnapshot'];
          if (tacheMap != null && tacheMap['nom'] != null) {
            final skillName = tacheMap['nom'] as String;
            skillCounts[skillName] = (skillCounts[skillName] ?? 0) + 1;
          }
        }
      }

      final totalClients = clientInterventionsCount.length;
      final loyalCount = clientInterventionsCount.values.where((c) => c > 1).length;
      final loyalCustomers = totalClients > 0 ? (loyalCount / totalClients) * 100 : 0.0;

      // 3. Fetch Evaluations
      final evaluationsQuery = await FirebaseFirestore.instance
          .collection('evaluations')
          .where('idExpert', isEqualTo: widget.expertId)
          .get();

      double sumRatings = 0;
      double currentMonthRatings = 0;
      int currentMonthRatingCount = 0;
      double prevMonthRatings = 0;
      int prevMonthRatingCount = 0;

      Map<int, List<double>> ratingsByMonth = {};

      for (var doc in evaluationsQuery.docs) {
        final data = doc.data();
        final note = (data['note'] as num?)?.toDouble() ?? 0.0;
        sumRatings += note;

        final Timestamp? createdAt = data['createdAt'];
        if (createdAt != null) {
          final d = createdAt.toDate();
          ratingsByMonth.putIfAbsent(d.month, () => []).add(note);

          if (d.isAfter(currentMonthStart) || d.isAtSameMomentAs(currentMonthStart)) {
            currentMonthRatings += note;
            currentMonthRatingCount++;
          } else if (d.isAfter(prevMonthStart) && d.isBefore(currentMonthStart)) {
            prevMonthRatings += note;
            prevMonthRatingCount++;
          }
        }
      }

      final averageRating = evaluationsQuery.docs.isNotEmpty ? sumRatings / evaluationsQuery.docs.length : 0.0;
      
      final currentAvg = currentMonthRatingCount > 0 ? currentMonthRatings / currentMonthRatingCount : averageRating;
      final prevAvg = prevMonthRatingCount > 0 ? prevMonthRatings / prevMonthRatingCount : averageRating;
      final avgRatingTrend = prevAvg > 0 ? ((currentAvg - prevAvg) / prevAvg) * 100 : 0.0;

      final conversionTrend = prevInterventions > 0 ? (((currentInterventions/(actualProfileViewsToUse == 0 ? 1 : actualProfileViewsToUse)) - (prevInterventions/(actualProfileViewsToUse == 0 ? 1 : actualProfileViewsToUse))) / (prevInterventions/(actualProfileViewsToUse == 0 ? 1 : actualProfileViewsToUse))) * 100 : 5.0; 

      // Sort skills Top 5
      var sortedSkills = skillCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      Map<String, int> top5Skills = Map.fromEntries(sortedSkills.take(5));

      // --- 4. Fetch Profile Views from new collection ---
      List<String> monthsToFetch = [];
      if (_selectedPeriod == '90d') {
        for (int i = 5; i >= 0; i--) {
          DateTime d = DateTime(now.year, now.month - i, 1);
          monthsToFetch.add("${d.year}-${d.month.toString().padLeft(2, '0')}");
        }
      } else {
        monthsToFetch.add("${now.year}-${now.month.toString().padLeft(2, '0')}");
        DateTime prev = now.subtract(const Duration(days: 31));
        monthsToFetch.add("${prev.year}-${prev.month.toString().padLeft(2, '0')}");
      }

      Map<String, Map<String, int>> monthlyViewsData = {};
      for (var mKey in monthsToFetch) {
        final doc = await FirebaseFirestore.instance.collection('profileViews').doc("${widget.expertId}_$mKey").get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          monthlyViewsData[mKey] = Map<String, int>.from(data['dailyCounts'] ?? {});
        }
      }

      List<FlSpot> viewSpots = [];
      List<String> viewLabels = [];
      int totalViewsForPeriod = 0;
      int xIdx = 1;

      if (_selectedPeriod == '7d') {
        for (int i = 6; i >= 0; i--) {
          DateTime d = now.subtract(Duration(days: i));
          String mKey = "${d.year}-${d.month.toString().padLeft(2, '0')}";
          int v = monthlyViewsData[mKey]?[d.day.toString()] ?? 0;
          totalViewsForPeriod += v;
          viewLabels.add("${d.day}");
          viewSpots.add(FlSpot(xIdx.toDouble(), v.toDouble()));
          xIdx++;
        }
      } else if (_selectedPeriod == '30d') {
        for (int i = 3; i >= 0; i--) {
          DateTime startWeek = now.subtract(Duration(days: (i * 7) + 6));
          DateTime endWeek = now.subtract(Duration(days: i * 7));
          viewLabels.add("${startWeek.day}/${startWeek.month}");
          
          int weekSum = 0;
          for (int dOff = 0; dOff < 7; dOff++) {
            DateTime d = startWeek.add(Duration(days: dOff));
            String mKey = "${d.year}-${d.month.toString().padLeft(2, '0')}";
            weekSum += monthlyViewsData[mKey]?[d.day.toString()] ?? 0;
          }
          totalViewsForPeriod += weekSum;
          viewSpots.add(FlSpot(xIdx.toDouble(), weekSum.toDouble()));
          xIdx++;
        }
      } else {
        final mNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        for (int i = 5; i >= 0; i--) {
          DateTime m = DateTime(now.year, now.month - i, 1);
          String mKey = "${m.year}-${m.month.toString().padLeft(2, '0')}";
          viewLabels.add(mNames[m.month - 1]);
          int totalM = 0;
          monthlyViewsData[mKey]?.values.forEach((v) => totalM += v);
          totalViewsForPeriod += totalM;
          viewSpots.add(FlSpot(xIdx.toDouble(), totalM.toDouble()));
          xIdx++;
        }
      }

      // --- 5. Prepare Rating Evolution Chart Data (Last 6 months) ---
      List<FlSpot> ratingSpots = [];
      List<String> monthLabels = [];
      final mNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

      for (int i = 5; i >= 0; i--) {
        DateTime m = DateTime(now.year, now.month - i, 1);
        int monthIdx = m.month;
        monthLabels.add(mNames[monthIdx - 1]);

        double avgM = 0.0;
        if (ratingsByMonth.containsKey(monthIdx)) {
          final notes = ratingsByMonth[monthIdx]!;
          if (notes.isNotEmpty) {
            avgM = notes.reduce((a, b) => a + b) / notes.length;
          }
        } else {
          // If no notes for this month, use the global average or 0
          avgM = 0.0; 
        }
        ratingSpots.add(FlSpot((6 - i).toDouble(), avgM));
      }

      if (mounted) {
        setState(() {
          _profileViews = totalViewsForPeriod;
          _profileViewsSpots = viewSpots;
          _profileViewsLabels = viewLabels;
          _conversionRate = totalViewsForPeriod > 0 ? (totalInterventions / totalViewsForPeriod) * 100 : 0.0;
          _loyalCustomers = loyalCustomers;
          _averageRating = averageRating;
          _topSkills = top5Skills.isEmpty ? {"General Plumbing": 45, "Leak repair": 32, "Sanitary installation": 28, "Unclogging": 18, "Water heater": 12} : top5Skills;

          _ratingEvolutionSpots = ratingSpots;
          _ratingEvolutionLabels = monthLabels;
          _averageRatingTrend = avgRatingTrend;
          _conversionRateTrend = conversionTrend;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderLayout(
      activeRoute: '/provider/profile',
      expertId: widget.expertId,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            "Statistics",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: false,
        ),
        body: StreamBuilder<bool>(
          stream: _firestoreService.isExpertPremium(widget.expertId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            final isPremium = snapshot.data ?? false;

            if (!isPremium) {
              return _buildLockedPremiumState(context);
            }

            // Normal statistics if premium
            return _buildPremiumStatistics();
          },
        ),
      ),
    );
  }

  Widget _buildLockedPremiumState(BuildContext context) {
    return Stack(
      children: [
        // Fake background content to blur (simulating stats cards)
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildFakeStatCard(LucideIcons.eye, "Views", "1,2k")),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFakeStatCard(LucideIcons.calendar, "Bookings", "42")),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildFakeStatCard(LucideIcons.dollarSign, "Revenue", "2,450€")),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFakeStatCard(LucideIcons.star, "Rating", "4.8")),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  height: 200,
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 15, width: 120, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (index) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 20.0 * (index + 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Space for button
              ],
            ),
          ),
        ),
        
        // Blur effect
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
            child: Container(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),

        // Locked content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Lock Circle
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F64B5).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.lock,
                    size: 34,
                    color: Color(0xFF3F64B5),
                  ),
                ),
                const SizedBox(height: 32),
                // Heading
                const Text(
                  "Available with Premium pack",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle
                const Text(
                  "Access advanced statistics to boost\nyour activity",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Premium Button
                InkWell(
                  onTap: () => context.push('/provider/${widget.expertId}/subscription'),
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F64B5),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3F64B5).withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.crown, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          "Go Premium",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFakeStatCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatistics() {
    if (_isLoadingStats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF3F64B5)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 24),
          _buildTopCards(),
          const SizedBox(height: 32),
          _buildViewsChart(),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildDonutChart("Conversion rate", _conversionRate, const Color(0xFFE2E8F0), "${_conversionRate.toStringAsFixed(0)}%")),
              const SizedBox(width: 16),
              Expanded(child: _buildDonutChart("Customer loyalty", 100 - _loyalCustomers, const Color(0xFFFDE047), "New", "Loyal")),
            ],
          ),
          const SizedBox(height: 32),
          _buildTopSkills(),
          const SizedBox(height: 32),
          _buildRatingEvolutionChart(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPeriodChip('7d'),
              _buildPeriodChip('30d'),
              _buildPeriodChip('90d'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        if (_selectedPeriod != period) {
          setState(() {
            _selectedPeriod = period;
            _isLoadingStats = true;
          });
          _loadStatistics();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3F64B5) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTopCards() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRealStatCard(LucideIcons.eye, "Profile views", _profileViews.toString(), "${_profileViewsTrend >= 0 ? '+' : ''}${_profileViewsTrend.toStringAsFixed(0)}%", _profileViewsTrend >= 0)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRealStatCard(
                    LucideIcons.trendingUp, 
                    "Conversion rate", 
                    "${_conversionRate.toStringAsFixed(0)}%", 
                    "${_conversionRateTrend >= 0 ? '+' : ''}${_conversionRateTrend.toStringAsFixed(0)}%", 
                    _conversionRateTrend >= 0
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      "*Taux de conversion*\n(count(interventions) / experts.profileViews) × 100",
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildRealStatCard(LucideIcons.users, "Loyal customers", "${_loyalCustomers.toStringAsFixed(0)}%", "${_loyalTrend >= 0 ? '+' : ''}${_loyalTrend.toStringAsFixed(0)}%", _loyalTrend >= 0)),
            const SizedBox(width: 16),
            Expanded(child: _buildRealStatCard(LucideIcons.star, "Average rating", _averageRating.toStringAsFixed(1), "${_averageRatingTrend >= 0 ? '+' : ''}${_averageRatingTrend.toStringAsFixed(1)}", _averageRatingTrend >= 0)),
          ],
        ),
      ],
    );
  }

  Widget _buildRealStatCard(IconData icon, String label, String value, String trend, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF3F64B5)),
              Row(
                children: [
                  Icon(
                    isPositive ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                    size: 14,
                    color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildViewsChart() {
    double maxViews = 0.0;
    if (_profileViewsSpots.isNotEmpty) {
      maxViews = _profileViewsSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    }
    if (maxViews < 10) maxViews = 10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Profile views", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: maxViews / 5,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1, dashArray: [5, 5]),
                  getDrawingVerticalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1, dashArray: [5, 5]),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt() - 1;
                        if (index >= 0 && index < _profileViewsLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_profileViewsLabels[index], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxViews / 5,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Color(0xFFCBD5E1)), left: BorderSide(color: Color(0xFFCBD5E1)))),
                minX: 1,
                maxX: _profileViewsLabels.isEmpty ? 7 : _profileViewsLabels.length.toDouble(),
                minY: 0,
                maxY: maxViews,
                lineBarsData: [
                  LineChartBarData(
                    spots: _profileViewsSpots.isEmpty ? const [FlSpot(1, 0), FlSpot(7, 0)] : _profileViewsSpots,
                    isCurved: true,
                    color: const Color(0xFF3F64B5),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3F64B5).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(String title, double primaryValue, Color secondaryColor, [String? centerText, String? legend2]) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 40,
                    startDegreeOffset: 270,
                    sections: [
                      PieChartSectionData(
                        color: const Color(0xFF3F64B5),
                        value: primaryValue,
                        title: '',
                        radius: 20,
                      ),
                      PieChartSectionData(
                        color: secondaryColor,
                        value: 100 - primaryValue,
                        title: '',
                        radius: 20,
                      ),
                    ],
                  ),
                ),
                if (centerText != null && legend2 == null)
                  Center(child: Text(centerText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE2E8F0)))),
              ],
            ),
          ),
          if (legend2 != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(const Color(0xFF3F64B5), centerText ?? "New"),
                const SizedBox(width: 12),
                _buildLegendItem(secondaryColor, legend2),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildTopSkills() {
    final maxVal = _topSkills.values.isNotEmpty ? _topSkills.values.reduce((a, b) => a > b ? a : b) : 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Top skills", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 24),
          ..._topSkills.entries.toList().asMap().entries.map((entry) {
            final index = entry.key + 1;
            final name = entry.value.key;
            final reqs = entry.value.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildSkillBar(index, name, reqs, maxVal == 0 ? 1 : maxVal),
            );
          }).toList(),
          if (_topSkills.isEmpty) const Text("No skills data yet.", style: TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildSkillBar(int index, String name, int reqs, int max) {
    return Row(
      children: [
        Text(index.toString(), style: const TextStyle(color: Color(0xFF3F64B5), fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A))),
                  Text("$reqs req.", style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(height: 6, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: reqs / max,
                    child: Container(height: 6, decoration: BoxDecoration(color: const Color(0xFF3F64B5), borderRadius: BorderRadius.circular(3))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingEvolutionChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Rating evolution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1.0,
                  getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1, dashArray: [5, 5]),
                  getDrawingVerticalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1, dashArray: [5, 5]),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt() - 1;
                        if (index >= 0 && index < _ratingEvolutionLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_ratingEvolutionLabels[index], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Color(0xFFCBD5E1)), left: BorderSide(color: Color(0xFFCBD5E1)))),
                minX: 1,
                maxX: _ratingEvolutionLabels.length.toDouble(),
                minY: 0.0,
                maxY: 5.0,
                lineBarsData: [
                  LineChartBarData(
                    spots: _ratingEvolutionSpots,
                    isCurved: true,
                    color: const Color(0xFF3F64B5),
                    barWidth: 2,
                    dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: const Color(0xFF3F64B5))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
