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

const List<String> _categories = [
  "Plomberie",
  "Électricité",
  "Ménage",
  "Jardinage",
  "Coiffure",
  "Informatique",
  "Peinture",
  "Climatisation"
];

class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({Key? key}) : super(key: key);

  @override
  State<ProviderServicesScreen> createState() =>
      _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  final List<Map<String, dynamic>> _services = [
    {
      "id": 1,
      "title": "Réparation robinet",
      "category": "Plomberie",
      "price": "150 DH",
      "active": true
    },
    {
      "id": 2,
      "title": "Installation chauffe-eau",
      "category": "Plomberie",
      "price": "À partir de 300 DH",
      "active": true
    },
    {
      "id": 3,
      "title": "Débouchage canalisation",
      "category": "Plomberie",
      "price": "Sur devis",
      "active": false
    },
  ];

  final String _pack = "Gratuit";
  final int _maxServices = 5;

  void _toggleService(int id) {
    setState(() {
      final service = _services.firstWhere((s) => s["id"] == id);
      service["active"] = !service["active"];
    });
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Nouveau service",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                hint: "Titre du service",
              ),
              const SizedBox(height: 16),
              _buildDropdownField("Catégorie", _categories),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Description du service...",
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      hint: "Prix (DH)",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdownField(
                        "Type", ["Fixe", "À partir de", "Sur devis"]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdownField("Durée estimée", [
                "30 min",
                "1 heure",
                "2 heures",
                "Demi-journée",
                "Journée complète"
              ]),
              const SizedBox(height: 16),
              GlassContainer(
                borderStyle: BorderStyle.solid,
                borderColor: AppColors.divider,
                borderWidth: 2,
                child: Column(
                  children: [
                    Icon(
                      Icons.image,
                      size: 32,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ajouter des photos (max 5)",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: "Enregistrer le service",
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String hint, List<String> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: AppColors.textSecondary)),
          icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )).toList(),
          onChanged: (value) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_services.length / _maxServices) * 100;

    return ProviderLayout(
      currentIndex: 1,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Mes Services",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    CustomButton(
                      text: "Ajouter",
                      icon: Icons.add,
                      isCompact: true,
                      onPressed: _showAddSheet,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Limit indicator
                if (_pack == "Gratuit") ...[
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${_services.length}/$_maxServices services utilisés",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  context.push('/provider/subscription'),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Upgrade",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: AppColors.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Service Cards
                ..._services.map((service) => _buildServiceCard(service)),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.image,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service["title"],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        service["category"],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        service["price"],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: service["active"],
                  onChanged: (_) => _toggleService(service["id"]),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                StatusBadge(
                  text: service["active"] ? "Actif" : "Inactif",
                  type: service["active"] ? BadgeType.success : BadgeType.basic,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.edit,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.delete,
                    size: 20,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
