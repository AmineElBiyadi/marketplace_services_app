import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String premiumPrice = "99";
  String serviceLimit = "5";

  final List<Map<String, dynamic>> notifTemplates = [
    {'id': 1, 'name': "Confirmation d'inscription", 'content': "Bienvenue {nom} ! Votre compte a été créé avec succès.", 'variables': ["{nom}"]},
    {'id': 2, 'name': "Mise à jour réservation", 'content': "Votre réservation pour {service} le {date} a été {statut}.", 'variables': ["{service}", "{date}", "{statut}"]},
    {'id': 3, 'name': "Rappel de paiement", 'content': "{nom}, votre abonnement Premium expire le {date}. Renouvelez maintenant.", 'variables': ["{nom}", "{date}"]},
    {'id': 4, 'name': "Validation de compte", 'content': "Félicitations {nom} ! Votre compte prestataire a été validé.", 'variables': ["{nom}"]},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      activeRoute: '/admin/settings',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildTabsSectionHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPacksTab(),
                  _buildNotificationsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paramètres',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.foreground,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Configuration globale et gestion de la plateforme',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildTabsSectionHeader() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppColors.foreground,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelColor: AppColors.mutedForeground,
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.crown, size: 14), SizedBox(width: 8), Text("Packs")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.bell, size: 14), SizedBox(width: 8), Text("Notifications")])),
        ],
      ),
    );
  }

  Widget _buildPacksTab() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView(
        children: [
          _buildCard(
            title: 'Tarification et Limites',
            children: [
              _buildInputField(
                label: 'Prix Premium mensuel (DH)',
                initialValue: premiumPrice,
                onChanged: (v) => premiumPrice = v,
                keyboardType: TextInputType.number,
                width: 200,
              ),
              _buildInputField(
                label: 'Limite de services (Compte Gratuit)',
                initialValue: serviceLimit,
                onChanged: (v) => serviceLimit = v,
                keyboardType: TextInputType.number,
                width: 200,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Align(alignment: Alignment.centerLeft, child: _buildSaveButton()),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView(
        children: [
          ...notifTemplates.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: _buildCard(
                  title: t['name'],
                  children: [
                    TextField(
                      controller: TextEditingController(text: t['content']),
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(16),
                        fillColor: AppColors.muted.withOpacity(0.1),
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (t['variables'] as List<String>).map((v) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(v, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: _buildSaveButton(label: 'Enregistrer les templates')),
        ],
      ),
    );
  }

  // ==== HELPER WIDGETS (Consistent with Finances) ====

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.foreground, letterSpacing: -0.2)),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5)),
    );
  }

  Widget _buildInputField({
    required String label,
    required String initialValue,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    double? width,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        SizedBox(
          width: width,
          child: TextFormField(
            initialValue: initialValue,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: AppColors.foreground),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              fillColor: AppColors.muted.withOpacity(0.1),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        DropdownButtonFormField<String>(
          value: value,
          icon: const Icon(LucideIcons.chevronDown, size: 16),
          style: const TextStyle(fontSize: 14, color: AppColors.foreground),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            fillColor: AppColors.muted.withOpacity(0.1),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
          ),
          items: items,
          onChanged: onChanged,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSaveButton({String label = 'Enregistrer'}) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(LucideIcons.save, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.foreground,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 0,
      ),
    );
  }

  Widget _buildResponsiveTable({required List<DataColumn> columns, required List<DataRow> rows}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: DataTable(
            headingRowHeight: 52,
            dataRowMaxHeight: 64,
            dividerThickness: 0.5,
            horizontalMargin: 20,
            columnSpacing: 20,
            showCheckboxColumn: false,
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    );
  }
}
