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

  bool maintenanceMode = false;
  String maintenanceMsg = "La plateforme est en maintenance. Veuillez réessayer plus tard.";
  String premiumPrice = "99";
  String serviceLimit = "5";

  // Security preferences
  bool require2FA = true;
  String sessionTimeout = "30";
  String minPasswordLength = "8";

  // DB Backup
  String dbRetention = "30";

  final List<Map<String, dynamic>> notifTemplates = [
    {'id': 1, 'name': "Confirmation d'inscription", 'content': "Bienvenue {nom} ! Votre compte a été créé avec succès.", 'variables': ["{nom}"]},
    {'id': 2, 'name': "Mise à jour réservation", 'content': "Votre réservation pour {service} le {date} a été {statut}.", 'variables': ["{service}", "{date}", "{statut}"]},
    {'id': 3, 'name': "Rappel de paiement", 'content': "{nom}, votre abonnement Premium expire le {date}. Renouvelez maintenant.", 'variables': ["{nom}", "{date}"]},
    {'id': 4, 'name': "Validation de compte", 'content': "Félicitations {nom} ! Votre compte prestataire a été validé.", 'variables': ["{nom}"]},
  ];

  final List<Map<String, dynamic>> adminUsers = [
    {'name': "Super Admin", 'email': "admin@fixily.ma", 'role': "Super Admin", 'lastLogin': "2026-03-08 10:30"},
    {'name': "Modérateur 1", 'email': "mod1@fixily.ma", 'role': "Moderator", 'lastLogin': "2026-03-07 14:00"},
    {'name': "Finance", 'email': "finance@fixily.ma", 'role': "Finance", 'lastLogin': "2026-03-06 09:15"},
  ];

  final List<Map<String, dynamic>> auditLog = [
    {'admin': "Super Admin", 'action': "Validé le compte", 'entity': "Youssef B. (Prestataire)", 'time': "2026-03-08 10:30"},
    {'admin': "Modérateur 1", 'action': "Supprimé un avis", 'entity': "Avis #45", 'time': "2026-03-07 15:20"},
    {'admin': "Super Admin", 'action': "Suspendu un compte", 'entity': "Hassan I. (Prestataire)", 'time': "2026-03-07 11:00"},
    {'admin': "Finance", 'action': "Exporté rapport financier", 'entity': "Mars 2026", 'time': "2026-03-06 16:45"},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
                  _buildGeneralTab(),
                  _buildSecurityTab(),
                  _buildPacksTab(),
                  _buildNotificationsTab(),
                  _buildAdminsTab(),
                  _buildDatabaseTab(),
                  _buildAuditTab(),
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
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.settings, size: 14), SizedBox(width: 8), Text("Général")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.shield, size: 14), SizedBox(width: 8), Text("Sécurité")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.crown, size: 14), SizedBox(width: 8), Text("Packs")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.bell, size: 14), SizedBox(width: 8), Text("Notifications")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.users, size: 14), SizedBox(width: 8), Text("Admins")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.database, size: 14), SizedBox(width: 8), Text("Base de données")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.clock, size: 14), SizedBox(width: 8), Text("Audit")])),
        ],
      ),
    );
  }

  // ==== TAB WIDGETS (Refined) ====

  Widget _buildGeneralTab() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView(
        children: [
          _buildCard(
            title: 'Informations plateforme',
            children: [
              _buildInputField(label: 'Nom de la plateforme', initialValue: 'Fixily'),
              _buildInputField(label: 'Email de contact', initialValue: 'contact@fixily.ma'),
              _buildDropdownField(
                label: 'Langue par défaut',
                value: 'fr',
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) {},
              ),
              _buildLabel('Logo'),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.upload, size: 14),
                label: const Text('Changer le logo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCard(
            title: 'Mode maintenance',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Activer le mode maintenance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Empêche l\'accès aux utilisateurs', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                    ],
                  ),
                  Switch(
                    value: maintenanceMode,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => maintenanceMode = v),
                  ),
                ],
              ),
              if (maintenanceMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: maintenanceMsg),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(16),
                    fillColor: AppColors.muted.withOpacity(0.2),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                  ),
                  onChanged: (v) => maintenanceMsg = v,
                ),
              ]
            ],
          ),
          const SizedBox(height: 32),
          Align(alignment: Alignment.centerLeft, child: _buildSaveButton()),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView(
        children: [
          _buildCard(
            title: 'Authentification & Accès',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Double authentification (2FA)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Obligatoire pour tous les administrateurs', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                    ],
                  ),
                  Switch(
                    value: require2FA,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => require2FA = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDropdownField(
                label: 'Longueur minimale du mot de passe (Admin)',
                value: minPasswordLength,
                items: const [
                  DropdownMenuItem(value: '8', child: Text('8 caractères')),
                  DropdownMenuItem(value: '10', child: Text('10 caractères')),
                  DropdownMenuItem(value: '12', child: Text('12 caractères')),
                ],
                onChanged: (v) => setState(() => minPasswordLength = v!),
              ),
              _buildDropdownField(
                label: 'Expiration de la session',
                value: sessionTimeout,
                items: const [
                  DropdownMenuItem(value: '15', child: Text('15 minutes')),
                  DropdownMenuItem(value: '30', child: Text('30 minutes')),
                  DropdownMenuItem(value: '60', child: Text('1 heure')),
                  DropdownMenuItem(value: 'never', child: Text('Jamais')),
                ],
                onChanged: (v) => setState(() => sessionTimeout = v!),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCard(
            title: 'Restrictions IP',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Limiter l\'accès par IP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Sécurise l\'accès au dashboard', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                    ],
                  ),
                  Switch(value: false, onChanged: (v) {}),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('Ajouter une adresse IP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Align(alignment: Alignment.centerLeft, child: _buildSaveButton()),
        ],
      ),
    );
  }

  Widget _buildDatabaseTab() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView(
        children: [
          _buildCard(
            title: 'Maintenance & Sauvegardes',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dernière sauvegarde', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.mutedForeground)),
                      SizedBox(height: 6),
                      Text('2026-03-20 à 02:00 AM', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.foreground)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.download, size: 14),
                    label: const Text('Sauvegarder', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Divider(height: 1)),
              _buildDropdownField(
                label: 'Rétention des archives',
                value: dbRetention,
                items: const [
                  DropdownMenuItem(value: '30', child: Text('30 jours')),
                  DropdownMenuItem(value: '90', child: Text('90 jours')),
                  DropdownMenuItem(value: '365', child: Text('1 an')),
                ],
                onChanged: (v) => setState(() => dbRetention = v!),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.database, size: 14, color: AppColors.destructive),
                label: const Text('Optimiser la base de données', style: TextStyle(color: AppColors.destructive, fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: AppColors.destructive.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Align(alignment: Alignment.centerLeft, child: _buildSaveButton()),
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

  Widget _buildAdminsTab() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Administrateurs Actifs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.foreground)),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('Nouveau Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.foreground,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        _buildResponsiveTable(
          columns: const [
            DataColumn(label: Text('NOM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5))),
            DataColumn(label: Text('EMAIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5))),
            DataColumn(label: Text('RÔLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5))),
            DataColumn(label: Text('DERNIÈRE CONNEXION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5))),
          ],
          rows: adminUsers.map((a) {
            return DataRow(cells: [
              DataCell(Text(a['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.foreground))),
              DataCell(Text(a['email'], style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(a['role'], style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w800)),
                ),
              ),
              DataCell(Text(a['lastLogin'], style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground))),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAuditTab() {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 20.0),
          child: Text('Journal d\'Audit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.foreground)),
        ),
        _buildResponsiveTable(
          columns: const [
            DataColumn(label: Text('ADMINISTRATEUR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5))),
            DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5))),
            DataColumn(label: Text('CIBLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5))),
            DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5))),
          ],
          rows: auditLog.map((log) {
            return DataRow(cells: [
              DataCell(Text(log['admin'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.foreground))),
              DataCell(Text(log['action'], style: const TextStyle(fontSize: 13, color: AppColors.foreground))),
              DataCell(Text(log['entity'], style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13))),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.clock, size: 12, color: AppColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(log['time'], style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ],
              )),
            ]);
          }).toList(),
        ),
      ],
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
