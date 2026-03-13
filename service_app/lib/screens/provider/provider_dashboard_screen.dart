import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/badges.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';
import '../../models/booking.dart';
import '../../models/expert.dart';

class ProviderDashboardScreen extends StatefulWidget {
  final String expertId;
  const ProviderDashboardScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String get _expertId => widget.expertId;

  bool _isOnline = true;
  String _pack = "Gratuit";
  String _expertName = "Expert";

  @override
  void initState() {
    super.initState();
    _loadExpertData();
  }

  void _loadExpertData() async {
    final expert = await _firestoreService.getExpertProfile(_expertId);
    if (expert != null) {
      setState(() {
        _isOnline = expert.estDisponible;
        _expertName = expert.user?.nom ?? expert.user?.email.split('@')[0] ?? "Expert";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderLayout(
      activeRoute: '/provider/dashboard',
      expertId: _expertId,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // KPI Cards
                _buildKPISection(),

                const SizedBox(height: 24),

                // Pending Requests
                _buildPendingRequestsSection(),

                const SizedBox(height: 24),

                // Quick Access - Agenda
                _buildAgendaQuickAccess(),

                const SizedBox(height: 24),

                // Upcoming Bookings
                _buildUpcomingBookingsSection(),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _expertName.isNotEmpty ? _expertName[0].toUpperCase() : "A",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, $_expertName",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _pack,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => context.push('/provider/subscription'),
                          child: const Text(
                            "Upgrade",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFD700), // Gold/Yellow
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildNotificationIcon(),
            ],
          ),
          const SizedBox(height: 24),
          _buildOnlineSwitch(),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return GestureDetector(
      onTap: () => context.push('/provider/notifications'),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.greenAccent : Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isOnline ? "Available" : "Unavailable",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Switch(
            value: _isOnline,
            onChanged: (v) async {
              setState(() => _isOnline = v);
              await _firestoreService.updateExpertAvailability(_expertId, v);
            },
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF1E293B).withOpacity(0.5),
            inactiveTrackColor: Colors.black26,
          ),
        ],
      ),
    );
  }

  Widget _buildKPISection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _firestoreService.getExpertKPIs(_expertId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final kpis = snapshot.data ?? {
          "reservations_today": "0",
          "rating": "0.0",
          "revenue": "0 DH",
          "views": "0",
        };
        
        final List<Map<String, dynamic>> kpiItems = [
          {
            "label": "Bookings today",
            "value": kpis["reservations_today"] ?? "0",
            "icon": Icons.calendar_today_rounded,
            "color": AppColors.primary
          },
          {
            "label": "Average rating",
            "value": kpis["rating"] ?? "0.0",
            "icon": Icons.star_border_rounded,
            "color": Colors.amber
          },
          {
            "label": "Revenue this month",
            "value": kpis["revenue"] ?? "0 DH",
            "icon": Icons.attach_money_rounded,
            "color": Colors.green
          },
          {
            "label": "Profile views",
            "value": kpis["views"] ?? "0",
            "icon": Icons.visibility_rounded,
            "color": const Color(0xFF3F64B5)
          },
        ];

        return Column(
          children: [
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: kpiItems.length,
                itemExtent: 160,
                itemBuilder: (context, index) {
                  final kpi = kpiItems[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[50]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kpi["color"].withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(kpi["icon"], size: 24, color: kpi["color"]),
                        ),
                        const Spacer(),
                        Text(
                          kpi["value"],
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          kpi["label"],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_left, size: 20, color: Colors.grey[300]),
                Container(
                  width: 160,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 90,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                Icon(Icons.arrow_right, size: 20, color: Colors.grey[300]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Pending requests",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<InterventionModel>>(
          stream: _firestoreService.getPendingInterventions(_expertId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Firestore Error : ${snapshot.error}",
                  style: TextStyle(color: Colors.red[700], fontSize: 11),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ));
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    "No pending requests",
                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ),
              );
            }
            return Column(
              children: requests.map((req) => _buildPendingCard(req)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAgendaQuickAccess() {
    return GestureDetector(
      onTap: () => context.push('/provider/agenda'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "My Agenda",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    "Calendar, schedules & area",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Upcoming bookings",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<InterventionModel>>(
          stream: _firestoreService.getUpcomingInterventions(_expertId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Erreur Firestore : ${snapshot.error}",
                  style: TextStyle(color: Colors.red[700], fontSize: 11),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final bookings = snapshot.data ?? [];
            if (bookings.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    "No upcoming bookings",
                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ),
              );
            }
            return Column(
              children: bookings.map((booking) => _buildUpcomingCard(booking)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPendingCard(InterventionModel req) {
    final clientName = req.clientSnapshot?['nom'] ?? "Amina B.";
    final serviceName = req.tacheSnapshot?['nom'] ?? "Plomberie";
    final avatarText = clientName.isNotEmpty ? clientName.substring(0, 2).toUpperCase() : "AB";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                avatarText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  serviceName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      "Today, 14:00",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleActionButton(IconData icon, Color bgColor, Color iconColor) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: iconColor),
    );
  }

  Widget _buildUpcomingCard(InterventionModel booking) {
    final serviceName = booking.tacheSnapshot?['nom'] ?? "Service";
    final clientName = booking.clientSnapshot?['nom'] ?? "Client";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: const Border(
            left: BorderSide(color: AppColors.primary, width: 6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    clientName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        "Upcoming",
                        style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
