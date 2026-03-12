import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/badges.dart';
import '../../widgets/common_widgets.dart';
import '../../layouts/provider_layout.dart';

final Map<String, List<Map<String, dynamic>>> _reservations = {
  "pending": [
    {
      "id": 1,
      "client": "Amina B.",
      "avatar": "AB",
      "service": "Plomberie",
      "date": "12 Mars, 14:00",
      "status": "En attente"
    },
    {
      "id": 2,
      "client": "Karim L.",
      "avatar": "KL",
      "service": "Réparation",
      "date": "13 Mars, 10:00",
      "status": "En attente"
    },
  ],
  "confirmed": [
    {
      "id": 3,
      "client": "Omar H.",
      "avatar": "OH",
      "service": "Ménage",
      "date": "14 Mars, 09:00",
      "status": "Confirmée",
      "phone": "0612345678"
    },
  ],
  "completed": [
    {
      "id": 4,
      "client": "Sara M.",
      "avatar": "SM",
      "service": "Jardinage",
      "date": "10 Mars, 15:00",
      "status": "Terminée"
    },
  ],
  "cancelled": [
    {
      "id": 5,
      "client": "Youssef K.",
      "avatar": "YK",
      "service": "Électricité",
      "date": "8 Mars, 11:00",
      "status": "Annulée"
    },
  ],
};

final Map<String, Color> _statusColors = {
  "En attente": AppColors.accent,
  "Confirmée": AppColors.primary,
  "Terminée": Colors.green,
  "Annulée": Colors.red,
};

class ProviderReservationsScreen extends StatefulWidget {
  final String expertId;
  const ProviderReservationsScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderReservationsScreen> createState() =>
      _ProviderReservationsScreenState();
}

class _ProviderReservationsScreenState
    extends State<ProviderReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Widget _buildCard(Map<String, dynamic> res,
      {bool showActions = false, bool showPhone = false}) {
    return GlassContainer(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    res["avatar"],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          res["client"],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              context.push('/chat/${res["id"]}'),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      res["service"],
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          res["date"],
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: res["status"],
                type: BadgeType.custom,
                customColor: _statusColors[res["status"]],
              ),
            ],
          ),
          if (showPhone && res["phone"] != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  res["phone"],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
          if (showActions) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: "Accepter",
                    icon: Icons.check,
                    backgroundColor: Colors.green,
                    isCompact: true,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomButton(
                    text: "Refuser",
                    icon: Icons.close,
                    isOutlined: true,
                    textColor: Colors.red,
                    borderColor: Colors.red,
                    isCompact: true,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ],
          if (res["status"] == "Confirmée") ...[
            const Divider(height: 24),
            CustomButton(
              text: "Marquer comme terminée",
              isCompact: true,
              onPressed: () {},
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderLayout(
      activeRoute: '/provider/bookings',
      expertId: widget.expertId,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: Text(
              "Réservations",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Tabs
          Container(
            padding: const EdgeInsets.all(20),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              tabs: const [
                Tab(text: "En attente"),
                Tab(text: "Confirmées"),
                Tab(text: "Terminées"),
                Tab(text: "Annulées"),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Pending
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _reservations["pending"]!.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCard(_reservations["pending"]![index],
                        showActions: true),
                  ),
                ),
                // Confirmed
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _reservations["confirmed"]!.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCard(_reservations["confirmed"]![index],
                        showPhone: true),
                  ),
                ),
                // Completed
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _reservations["completed"]!.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCard(_reservations["completed"]![index]),
                  ),
                ),
                // Cancelled
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _reservations["cancelled"]!.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCard(_reservations["cancelled"]![index]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
