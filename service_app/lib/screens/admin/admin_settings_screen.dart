import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';
import '../../services/admin_dashboard_service.dart';
import '../../services/cloudinary_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminDashboardService _adminService = AdminDashboardService();

  // CGU Controllers
  final TextEditingController _expertCguController = TextEditingController();
  final TextEditingController _clientCguController = TextEditingController();
  final TextEditingController _expertVersionController = TextEditingController();
  final TextEditingController _clientVersionController = TextEditingController();
  final TextEditingController _maintenanceMessageController = TextEditingController();
  final TextEditingController _freeLimitController = TextEditingController();
  final TextEditingController _portfolioLimitController = TextEditingController();
  bool _isLoading = false;
  bool _isMaintenance = false;

  List<Map<String, dynamic>> _expertHistory = [];
  List<Map<String, dynamic>> _clientHistory = [];
  String _cguTypeView = "EXPERT";

  // Services State
  List<Map<String, dynamic>> _services = [];
  Map<String, dynamic>? _selectedService;
  List<Map<String, dynamic>> _tasks = [];
  bool _isServicesLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
    _loadServices();
  }


  Future<void> _saveFreeLimit() async {
    final limit = int.tryParse(_freeLimitController.text);
    if (limit == null || limit < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer un nombre valide")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _adminService.updateFreePackLimit(limit);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Limite du pack free mise à jour avec succès")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePortfolioLimit() async {
    final limit = int.tryParse(_portfolioLimitController.text);
    if (limit == null || limit < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer un nombre valide")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _adminService.updateFreePortfolioLimit(limit);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Limite de photos portfolio mise à jour avec succès")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      // Load CGU
      final expertCgu = await _adminService.getActiveCgu("EXPERT");
      final clientCgu = await _adminService.getActiveCgu("CLIENT");

      if (expertCgu != null) {
        _expertCguController.text = expertCgu['content'] ?? "";
        _expertVersionController.text = expertCgu['version'] ?? "1.0";
      }
      if (clientCgu != null) {
        _clientCguController.text = clientCgu['content'] ?? "";
        _clientVersionController.text = clientCgu['version'] ?? "1.0";
      }

      _expertHistory = await _adminService.getCguHistory("EXPERT");
      _clientHistory = await _adminService.getCguHistory("CLIENT");

      // Load Maintenance & Limits
      final maint = await _adminService.getMaintenanceSettings();
      if (maint != null) {
        _isMaintenance = maint['is_maintenance'] ?? false;
        _maintenanceMessageController.text = maint['maintenance_message'] ?? "L'application est en maintenance. Nous serons bientôt de retour.";
        _freeLimitController.text = (maint['free_service_limit'] ?? 3).toString();
        _portfolioLimitController.text = (maint['free_portfolio_limit'] ?? 3).toString();
      } else {
        _freeLimitController.text = "3";
        _portfolioLimitController.text = "3";
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCgu(String type) async {
    final content = type == "EXPERT" ? _expertCguController.text : _clientCguController.text;
    final version = type == "EXPERT" ? _expertVersionController.text : _clientVersionController.text;

    if (content.isEmpty || version.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _adminService.createNewCguVersion(type, content, version);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("CGU $type mis à jour avec succès (v$version)")),
      );
      _loadSettings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMaintenance() async {
    setState(() => _isLoading = true);
    try {
      await _adminService.updateMaintenanceSettings(
        _isMaintenance,
        _maintenanceMessageController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paramètres de maintenance mis à jour")),
      );
      _loadSettings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadServices() async {
    setState(() => _isServicesLoading = true);
    try {
      _services = await _adminService.getServices();
      if (_services.isNotEmpty && _selectedService == null) {
        _selectedService = _services.first;
        await _loadTasks(_selectedService!['id']);
      } else if (_selectedService != null) {
        // Refresh selected service data
        try {
          _selectedService = _services.firstWhere((s) => s['id'] == _selectedService!['id']);
          await _loadTasks(_selectedService!['id']);
        } catch (e) {
          _selectedService = _services.first;
          await _loadTasks(_selectedService!['id']);
        }
      }
    } catch (e) {
      debugPrint("Error loading services: $e");
    } finally {
      if (mounted) setState(() => _isServicesLoading = false);
    }
  }

  Future<void> _loadTasks(String serviceId) async {
    try {
      _tasks = await _adminService.getTasksByService(serviceId);
    } catch (e) {
      debugPrint("Error loading tasks: $e");
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expertCguController.dispose();
    _clientCguController.dispose();
    _expertVersionController.dispose();
    _clientVersionController.dispose();
    _maintenanceMessageController.dispose();
    _freeLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin/settings',
      child: Column(
        children: [
          _buildTopBar(isMobile),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabsSectionHeader(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                         _buildCguTab(),
                         _buildMaintenanceTab(),
                         _buildServicesTab(),
                      ],
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

  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(LucideIcons.menu, color: AppColors.foreground),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const Text('Paramètres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.foreground)),
          const Spacer(),
          IconButton(
            onPressed: () {
              _loadSettings();
              _loadServices();
            },
            icon: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

// _buildHeader completely removed because Top Bar replaces it

  Widget _buildCguTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(
        children: [
          _buildCguTypeSelector(),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                if (_cguTypeView == "EXPERT")
                  _buildCguSection(
                    title: "CGU Experts",
                    contentController: _expertCguController,
                    versionController: _expertVersionController,
                    history: _expertHistory,
                    onSave: () => _saveCgu("EXPERT"),
                  )
                else
                  _buildCguSection(
                    title: "CGU Clients",
                    contentController: _clientCguController,
                    versionController: _clientVersionController,
                    history: _clientHistory,
                    onSave: () => _saveCgu("CLIENT"),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCguTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelectorButton("EXPERT", "Experts", LucideIcons.userCheck),
          _buildSelectorButton("CLIENT", "Clients", LucideIcons.users),
        ],
      ),
    );
  }

  Widget _buildSelectorButton(String type, String label, IconData icon) {
    final bool isSelected = _cguTypeView == type;
    return GestureDetector(
      onTap: () => setState(() => _cguTypeView = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.primary : AppColors.mutedForeground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.foreground : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCguSection({
    required String title,
    required TextEditingController contentController,
    required TextEditingController versionController,
    required List<Map<String, dynamic>> history,
    required VoidCallback onSave,
  }) {
    return _buildCard(
      title: title,
      children: [
        _buildInputFieldWithController(
          label: 'Version',
          controller: versionController,
          width: 150,
        ),
        const SizedBox(height: 8),
        _buildLabel('Contenu des CGU'),
        TextField(
          controller: contentController,
          maxLines: 8,
          style: const TextStyle(fontSize: 14, color: AppColors.foreground),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(16),
            fillColor: AppColors.muted.withOpacity(0.1),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: _buildSaveButton(
            label: 'Publier cette version',
            onPressed: onSave,
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        _buildLabel('Historique des versions'),
        const SizedBox(height: 12),
        _buildHistoryTable(history),
      ],
    );
  }

  Widget _buildHistoryTable(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text("Aucun historique disponible", style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: MediaQuery.of(context).size.width < 600 ? 500 : null,
        decoration: BoxDecoration(
          color: AppColors.muted.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.3)),
        ),
        child: Table(
        columnWidths: const {
          0: FixedColumnWidth(70),
          1: FlexColumnWidth(),
          2: FixedColumnWidth(100),
          3: FixedColumnWidth(50),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.muted.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            children: const [
              Padding(padding: EdgeInsets.all(12), child: Text("Version", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedForeground))),
              Padding(padding: EdgeInsets.all(12), child: Text("Date", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedForeground))),
              Padding(padding: EdgeInsets.all(12), child: Text("Statut", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedForeground))),
              Padding(padding: EdgeInsets.all(12), child: Text("Voir", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedForeground))),
            ],
          ),
          ...history.map((h) {
            final date = (h['created_at'] as Timestamp?)?.toDate();
            final dateStr = date != null ? "${date.day}/${date.month}/${date.year}" : "N/A";
            final isActive = h['is_active'] == true;

            return TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(12), child: Text(h['version'] ?? "1.0", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                Padding(padding: const EdgeInsets.all(12), child: Text(dateStr, style: const TextStyle(fontSize: 12))),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isActive ? "Actif" : "Archivé",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.grey),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: const Icon(LucideIcons.eye, size: 14),
                    onPressed: () => _viewOldCgu(h),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    ),
  );
}

  void _viewOldCgu(Map<String, dynamic> cgu) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Version ${cgu['version']} (${cgu['type']})"),
        content: SingleChildScrollView(
          child: Text(cgu['content'] ?? ""),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFieldWithController({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    double? width,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        SizedBox(
          width: width,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
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

  // ==== TABS SECTIONS ====

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
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.fileText, size: 14), SizedBox(width: 8), Text("CGU")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.settings, size: 14), SizedBox(width: 8), Text("Maintenance")])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.layers, size: 14), SizedBox(width: 8), Text("Services")])),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView(
        children: [
          _buildCard(
            title: 'Mode Maintenance',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Activer le mode maintenance",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Bloque l'accès à l'application pour les utilisateurs",
                          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isMaintenance,
                    onChanged: (v) => setState(() => _isMaintenance = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel('Message de maintenance'),
              TextField(
                controller: _maintenanceMessageController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                decoration: InputDecoration(
                  hintText: "Expliquez pourquoi l'application est en maintenance...",
                  contentPadding: const EdgeInsets.all(16),
                  fillColor: AppColors.muted.withOpacity(0.1),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildSaveButton(
                  label: 'Mettre à jour la maintenance',
                  onPressed: _saveMaintenance,
                ),
              ),
            ],
          ),
          if (_isMaintenance)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Attention : Le mode maintenance est actuellement actif. Les utilisateurs ne pourront pas utiliser l'application.",
                        style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),
          _buildFreeLimitConfig(),
        ],
      ),
    );
  }

  // ==== SERVICES TAB ====

  Widget _buildServicesTab() {
    if (_isServicesLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: _buildServiceListColumn(),
            ),
            const SizedBox(height: 24),
            _selectedService == null
                ? const Center(child: Padding(padding: EdgeInsets.all(48), child: Text("Sélectionnez un service pour voir les tâches")))
                : _buildServiceDetailCard(_selectedService!),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: _buildServiceListColumn(),
        ),
        const SizedBox(width: 24),
        // Right Column: Service Details & Tasks
        Expanded(
          child: _selectedService == null
              ? const Center(child: Text("Sélectionnez un service pour voir les tâches"))
              : _buildServiceDetailCard(_selectedService!),
        ),
      ],
    );
  }

  Widget _buildServiceListColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Services", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(LucideIcons.plusCircle, size: 20, color: AppColors.primary),
              onPressed: () => _showServiceDialog(),
              tooltip: "Ajouter un service",
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.muted.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: _services.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final service = _services[index];
                final isSelected = _selectedService?['id'] == service['id'];
                return _buildServiceItem(service, isSelected);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> service, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() => _selectedService = service);
        _loadTasks(service['id']);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.muted.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                image: service['image'] != null && (service['image'] as String).isNotEmpty
                    ? _buildDecorationImage(service['image'])
                    : null,
              ),
              child: service['image'] == null || (service['image'] as String).isEmpty
                  ? Icon(LucideIcons.briefcase, size: 14, color: isSelected ? Colors.white : AppColors.mutedForeground)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                service['nom'] ?? "Sans nom",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.foreground,
                ),
              ),
            ),
            if (isSelected)
              const Icon(LucideIcons.chevronRight, size: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDetailCard(Map<String, dynamic> service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (service['image'] != null && (service['image'] as String).isNotEmpty)
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: _buildDecorationImage(service['image']),
                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service['nom'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        service['description'] ?? "Aucune description",
                        style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: service['estActive'] ?? true,
                      activeColor: Colors.green,
                      onChanged: (bool value) async {
                        await _adminService.updateService(service['id'], {'estActive': value});
                        setState(() {
                          service['estActive'] = value;
                        });
                        // Reload tasks to reflect the cascaded status change
                        _loadTasks(service['id']);
                      },
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.edit2, size: 18, color: AppColors.primary),
                      onPressed: () => _showServiceDialog(service: service),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),
            _buildTasksSection(service['id']),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection(String serviceId) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Tâches associées", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(LucideIcons.plusCircle, size: 20, color: AppColors.primary),
              onPressed: () => _showTaskDialog(serviceId: serviceId),
              tooltip: "Ajouter une tâche",
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tasks.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("Aucune tâche pour ce service")))
        else
          _buildResponsiveTable(
            columns: const [
              DataColumn(label: Text("Nom")),
              DataColumn(label: Text("Description")),
              DataColumn(label: Text("Statut")),
              DataColumn(label: Text("Actions")),
            ],
            rows: _tasks.map((task) {
              return DataRow(cells: [
                DataCell(SizedBox(
                  width: 150,
                  child: Text(task['nom'] ?? "", 
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), 
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(SizedBox(
                  width: 250,
                  child: Text(task['description'] ?? "", 
                    style: const TextStyle(fontSize: 13),
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(
                  Switch(
                    value: task['estActive'] ?? true,
                    activeColor: Colors.green,
                    onChanged: (bool value) async {
                      await _adminService.updateTask(task['id'], {'estActive': value});
                      _loadTasks(serviceId);
                    },
                  ),
                ),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.edit2, size: 14, color: AppColors.primary),
                      onPressed: () => _showTaskDialog(serviceId: serviceId, task: task),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
      ],
    );
  }

  // ==== DIALOGS & ACTIONS ====

  void _showServiceDialog({Map<String, dynamic>? service}) {
    final nameController = TextEditingController(text: service?['nom'] ?? "");
    final descController = TextEditingController(text: service?['description'] ?? "");
    String? currentImage = service?['image'];
    bool isUploading = false;
    dynamic pickedFileData; // Can be bytes or base64 for preview

    showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(service == null ? "Ajouter un service" : "Modifier le service"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: isUploading ? null : () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
                  if (pickedFile != null) {
                    final bytes = await pickedFile.readAsBytes();
                    setDialogState(() {
                      pickedFileData = bytes;
                      currentImage = base64Encode(bytes); // For preview via _buildDecorationImage
                    });
                  }
                },
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    image: currentImage != null && currentImage!.isNotEmpty
                        ? _buildDecorationImage(currentImage!)
                        : null,
                  ),
                  child: currentImage == null || currentImage!.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.image, color: AppColors.mutedForeground),
                            SizedBox(height: 8),
                            Text("Cliquer pour ajouter une image", style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          ],
                        )
                      : isUploading 
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                enabled: !isUploading,
                decoration: const InputDecoration(labelText: "Nom du service"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                enabled: !isUploading,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context), 
              child: const Text("Annuler")
            ),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (nameController.text.isEmpty) return;

                setDialogState(() => isUploading = true);

                try {
                  String? imageUrl = service?['image'];
                  String? publicId = service?['publicId'];

                  // If a new image was picked, upload it
                  if (pickedFileData != null) {
                    final uploadedUrl = await CloudinaryService.uploadImage(pickedFileData);
                    if (uploadedUrl != null) {
                      imageUrl = uploadedUrl;
                      // Extract publicId from URL: https://res.cloudinary.com/cloud/image/upload/v123/public_id.jpg
                      publicId = uploadedUrl.split('/').last.split('.').first;
                    } else {
                      throw Exception("Échec du téléchargement de l'image sur Cloudinary");
                    }
                  }

                  final data = {
                    'nom': nameController.text,
                    'description': descController.text,
                    'image': imageUrl,
                    'publicId': publicId,
                    'storageType': imageUrl != null && imageUrl.startsWith('http') ? 'cloudinary' : null,
                    if (service == null) 'estActive': true,
                  };

                  if (service == null) {
                    await _adminService.addService(data);
                  } else {
                    await _adminService.updateService(service['id'], data);
                  }
                  Navigator.pop(context);
                  _loadServices();
                } catch (e) {
                  setDialogState(() => isUploading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur : $e")),
                  );
                }
              },
              child: Text(isUploading ? "Enregistrement..." : "Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }

  DecorationImage _buildDecorationImage(String imageStr) {
    if (imageStr.startsWith('http')) {
      return DecorationImage(image: NetworkImage(imageStr), fit: BoxFit.cover);
    } else {
      try {
        return DecorationImage(image: MemoryImage(base64Decode(imageStr)), fit: BoxFit.cover);
      } catch (e) {
        return const DecorationImage(image: AssetImage('assets/placeholder.png'), fit: BoxFit.cover);
      }
    }
  }

  void _confirmDeleteService(Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer le service ?"),
        content: Text("Cela supprimera également toutes les tâches associées au service '${service['nom']}'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () async {
              await _adminService.deleteService(service['id']);
              Navigator.pop(context);
              setState(() => _selectedService = null);
              _loadServices();
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTaskDialog({required String serviceId, Map<String, dynamic>? task}) {
    final nameController = TextEditingController(text: task?['nom'] ?? "");
    final descController = TextEditingController(text: task?['description'] ?? "");
    bool isActive = task?['estActive'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(task == null ? "Ajouter une tâche" : "Modifier la tâche"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nom de la tâche"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("Active"),
                value: isActive,
                onChanged: (v) => setDialogState(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'nom': nameController.text,
                  'description': descController.text,
                  'idService': serviceId,
                  'estActive': isActive,
                };
                if (task == null) {
                  await _adminService.addTask(data);
                } else {
                  await _adminService.updateTask(task['id'], data);
                }
                Navigator.pop(context);
                _loadTasks(serviceId);
              },
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTask(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer la tâche ?"),
        content: Text("Voulez-vous vraiment supprimer la tâche '${task['nom']}' ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () async {
              await _adminService.deleteTask(task['id']);
              Navigator.pop(context);
              _loadTasks(task['idService']);
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
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

  Widget _buildSaveButton({String label = 'Enregistrer', VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed ?? () {},
      icon: const Icon(LucideIcons.save, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 14)),
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
        child: DataTable(
          headingRowHeight: 48,
          dataRowMaxHeight: 72,
          dividerThickness: 0.5,
          horizontalMargin: 20,
          columnSpacing: 20,
          showCheckboxColumn: false,
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  Widget _buildFreeLimitConfig() {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;
    return _buildCard(
      title: 'Gestion des Plans',
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputFieldWithController(
                label: 'Nombre max de services (Pack Free)',
                controller: _freeLimitController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              _buildSaveButton(
                label: 'Enregistrer la limite services',
                onPressed: _saveFreeLimit,
              ),
              const SizedBox(height: 24),
              _buildInputFieldWithController(
                label: 'Nombre max de photos portfolio (Pack Free)',
                controller: _portfolioLimitController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              _buildSaveButton(
                label: 'Enregistrer la limite photos',
                onPressed: _savePortfolioLimit,
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildInputFieldWithController(
                      label: 'Nombre max de services (Pack Free)',
                      controller: _freeLimitController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildSaveButton(
                      label: 'Enregistrer la limite services',
                      onPressed: _saveFreeLimit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildInputFieldWithController(
                      label: 'Nombre max de photos portfolio (Pack Free)',
                      controller: _portfolioLimitController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildSaveButton(
                      label: 'Enregistrer la limite photos',
                      onPressed: _savePortfolioLimit,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
