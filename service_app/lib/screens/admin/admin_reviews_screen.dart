import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/admin_dashboard_service.dart';
import '../../services/notification_service.dart';
import '../../layouts/admin_layout.dart';
import '../../widgets/admin/booking_detail_dialog.dart';
import '../../widgets/admin/user_profile_detail_dialog.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/admin_export_util.dart';
import 'package:intl/intl.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _bg = Color(0xFFF8FAFC);

  bool _loading = true;
  AdminDashboardStats? _stats;
  List<Map<String, dynamic>> _allReviews = [];
  List<Map<String, dynamic>> _allClaims = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final stats = await _service.getDashboardStats();
      final reviews = await _service.getAdminEvaluations();
      final claims = await _service.getAdminClaims();
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _allReviews = reviews;
          _allClaims = claims;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1100;

    return AdminLayout(
      activeRoute: '/admin/reviews',
      child: Container(
        color: _bg,
        child: Column(
          children: [
            _buildTopBar(isMobile),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 3))
                  : _buildUnifiedDashboard(isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _border.withOpacity(0.5)))),
      child: Row(
        children: [
          if (isMobile)
            Builder(builder: (context) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(icon: const Icon(LucideIcons.menu), onPressed: () => Scaffold.of(context).openDrawer()),
            )),
          Expanded(
            child: Text(
              'Avis & Réclamations', 
              style: TextStyle(
                fontSize: isMobile ? 18 : 22, 
                fontWeight: FontWeight.bold, 
                color: _textPrimary
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _exportData,
                icon: const Icon(LucideIcons.fileText, size: 14),
                label: const Text('Exporter PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 20)),
          ] else ...[
            IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 20)),
            IconButton(
              onPressed: _exportData,
              icon: const Icon(LucideIcons.fileText, size: 20, color: _textPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnifiedDashboard(bool isMobile) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildBentoKPIs(isMobile),
        const SizedBox(height: 32),
        _buildAnalyticsBento(isMobile),
        const SizedBox(height: 32),
        _buildIntegratedFeeds(isMobile),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildBentoKPIs(bool isMobile) {
    double cardWidth = isMobile ? 180 : 250;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard('Note Moyenne', '${_stats?.averageRating.toStringAsFixed(1)} ⭐', LucideIcons.star, Colors.amber, cardWidth),
        _buildStatCard('Réclamations', _allClaims.where((c) => c['etat'] == 'EN_ATTENTE').length.toString(), LucideIcons.alertCircle, Colors.orange, cardWidth),
        _buildStatCard('Total Avis', _allReviews.length.toString(), LucideIcons.messageSquare, Colors.blue, cardWidth),
        _buildStatCard('SLA Réponse', '98%', LucideIcons.shieldCheck, Colors.green, cardWidth),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color, double width) {
    return Container(
      width: width, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 16),
          Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary)),
          Text(title, style: const TextStyle(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsBento(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _bentoGridItem('Répartition des Étoiles', _buildRatingDistributionChart(true)),
          const SizedBox(height: 20),
          _bentoGridItem('Satisfaction Globale', _buildRadialGauge()),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _bentoGridItem('Distribution des Notes', _buildRatingDistributionChart(false))),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _bentoGridItem('Satisfaction Globale', _buildRadialGauge())),
      ],
    );
  }

  Widget _bentoGridItem(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildRadialGauge() {
    double score = _stats?.averageRating ?? 0.0;
    double progress = score / 5.0;
    return Center(
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140, height: 140,
                  child: CircularProgressIndicator(value: progress, strokeWidth: 12, backgroundColor: _primary.withOpacity(0.05), color: _primary, strokeCap: StrokeCap.round),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(score.toStringAsFixed(1), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primary)),
                    Text('/ 5.0', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSecondary.withOpacity(0.5))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildIntegratedFeeds(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _sectionSubHeader('Avis Récents', LucideIcons.star, Colors.amber, () => _showAllReviewsModal()),
          ..._allReviews.take(2).map((r) => _buildReviewCard(r)),
          const SizedBox(height: 32),
          _sectionSubHeader('Réclamations Prioritaires', LucideIcons.alertTriangle, Colors.redAccent, () => _showAllClaimsModal()),
          ..._allClaims.take(2).map((c) => _buildClaimCard(c)),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionSubHeader('Dernières Évaluations', LucideIcons.star, Colors.amber, () => _showAllReviewsModal()),
              const SizedBox(height: 16),
              ..._allReviews.take(2).map((r) => _buildReviewCard(r)),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionSubHeader('Réclamations en Cours', LucideIcons.alertTriangle, Colors.redAccent, () => _showAllClaimsModal()),
              const SizedBox(height: 16),
              ..._allClaims.take(2).map((c) => _buildClaimCard(c)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionSubHeader(String title, IconData icon, Color color, VoidCallback onSeeAll) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title, 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onSeeAll, child: const Text('Afficher tout', style: TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final bool isHidden = review['isHidden'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isHidden ? Colors.grey.withOpacity(0.04) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isHidden ? Colors.red.withOpacity(0.1) : _border.withOpacity(0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _profileCircle(review['clientName'][0], Colors.blueGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review['clientName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Expert: ${review['expertName']}', style: TextStyle(fontSize: 11, color: _textSecondary)),
                  ],
                ),
              ),
              _starBox(review['note'] ?? 0),
            ],
          ),
          const SizedBox(height: 16),
          Text(review['commentaire'], style: TextStyle(fontSize: 13, color: isHidden ? _textSecondary : _textPrimary, height: 1.4)),
          const Divider(height: 32),
          Row(
            children: [
              Text(review['date'], style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.bold)),
              const Spacer(),
              _miniIconAction(isHidden ? LucideIcons.eyeOff : LucideIcons.eye, isHidden ? Colors.orange : Colors.green, () => _toggleVisibility(review)),
              const SizedBox(width: 8),
              _miniIconAction(LucideIcons.trash2, Colors.redAccent, () => _deleteReview(review)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final statusColor = claim['etat'] == 'TRAITEE' ? Colors.green : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border.withOpacity(0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusBadge(claim['etat'], statusColor),
              Text(claim['date'], style: const TextStyle(fontSize: 10, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              const Text('Plaintif:', style: TextStyle(fontSize: 11, color: _textSecondary)),
              _clickableName(
                claim['typeReclamateur'] == 'EXPERT' ? claim['expertName'] : claim['clientName'], 
                claim['typeReclamateur'] == 'EXPERT' ? claim['idExpert'] : claim['idClient'], 
                claim['typeReclamateur'] == 'EXPERT' ? 'Prestataire' : 'Client'
              ),
              const SizedBox(width: 6),
              const Text('Contre:', style: TextStyle(fontSize: 11, color: _textSecondary)),
              _clickableName(
                claim['typeReclamateur'] == 'EXPERT' ? claim['clientName'] : claim['expertName'], 
                claim['typeReclamateur'] == 'EXPERT' ? claim['idClient'] : claim['idExpert'], 
                claim['typeReclamateur'] == 'EXPERT' ? 'Client' : 'Prestataire'
              ),
              if ((claim['targetClaimCount'] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('⚠ ${claim['targetClaimCount']} plaintes au total', style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(claim['description'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          Text('ID: ${claim['idIntervention']}', style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.bold)),
          const Divider(height: 32),
          Row(
            children: [
              _textAction('Gérer', () => _viewClaimDetail(claim)),
              const Spacer(),
              if (claim['etat'] == 'EN_ATTENTE')
                _miniIconAction(LucideIcons.check, Colors.green, () => _markAsTreated(claim)),
              const SizedBox(width: 8),
              _miniIconAction(LucideIcons.trash2, Colors.redAccent, () => _deleteClaim(claim)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clickableName(String name, String? id, String role) {
    return InkWell(
      onTap: id == null ? null : () {
        showDialog(
          context: context,
          builder: (ctx) => UserProfileDetailDialog(id: id, role: role),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
        child: Text(
          '$name ($role)',
          style: const TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _profileCircle(String char, Color color) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(char, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _starBox(double note) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text(note.toString(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _miniIconAction(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _textAction(String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Text(label, style: const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.bold)));
  }

  Widget _buildRatingDistributionChart(bool isMobile) {
    final Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var r in _allReviews) {
      int score = (r['note'] ?? 0).toInt();
      if (distribution.containsKey(score)) distribution[score] = distribution[score]! + 1;
    }
    final dataList = [
      {'stars': '5★', 'count': distribution[5]},
      {'stars': '4★', 'count': distribution[4]},
      {'stars': '3★', 'count': distribution[3]},
      {'stars': '2★', 'count': distribution[2]},
      {'stars': '1★', 'count': distribution[1]},
    ];
    double maxCount = dataList.map((e) => (e['count'] as int).toDouble()).reduce((a, b) => a > b ? a : b);
    if (maxCount < 10) maxCount = 10;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround, maxY: maxCount * 1.2,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(dataList[v.toInt()]['stars'] as String, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (maxCount / 4).clamp(1, 100).toDouble(), reservedSize: 30, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(color: _textSecondary, fontSize: 10)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: true, horizontalInterval: (maxCount / 4).clamp(1, 100).toDouble(), getDrawingHorizontalLine: (v) => FlLine(color: _border, strokeWidth: 1, dashArray: [5, 5]), getDrawingVerticalLine: (v) => FlLine(color: _border, strokeWidth: 1, dashArray: [5, 5])),
          borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: _primary.withOpacity(0.5)), left: BorderSide(color: _primary.withOpacity(0.5)))),
          barGroups: dataList.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: (e.value['count'] as num).toDouble(), color: Colors.amber[300]!, width: isMobile ? 30 : 60, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))])).toList(),
        ),
      ),
    );
  }

  void _showAllReviewsModal() => showDialog(context: context, builder: (context) => _BaseFullListModal(
    title: 'Toutes les Évaluations', 
    icon: LucideIcons.star, 
    color: Colors.amber, 
    items: _allReviews, 
    itemBuilder: (context, item) => _buildReviewCard(item),
    filterType: 'REVIEW',
  ));

  void _showAllClaimsModal() => showDialog(context: context, builder: (context) => _BaseFullListModal(
    title: 'Toutes les Réclamations', 
    icon: LucideIcons.alertTriangle, 
    color: Colors.redAccent, 
    items: _allClaims, 
    itemBuilder: (context, item) => _buildClaimCard(item),
    filterType: 'CLAIM',
  ));

  Future<void> _toggleVisibility(Map<String, dynamic> r) async {
    final bool newStatus = !(r['isHidden'] ?? false);
    await _service.updateEvaluationVisibility(r['id'], newStatus);
    _loadData();
  }

  Future<void> _deleteReview(Map<String, dynamic> r) async {
    final confirm = await _showConfirm('Supprimer cet avis ?');
    if (confirm == true) {
      await _service.deleteEvaluation(r['id']);
      _loadData();
    }
  }

  Future<void> _markAsTreated(Map<String, dynamic> c) async {
    await _service.updateClaim(c['id'], status: 'TRAITEE');
    _loadData();
  }

  Future<void> _deleteClaim(Map<String, dynamic> c) async {
    final confirm = await _showConfirm('Supprimer cette réclamation ?');
    if (confirm == true) {
      await _service.deleteClaim(c['id']);
      _loadData();
    }
  }

  Future<bool?> _showConfirm(String msg) => showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer'))]));

  void _viewClaimDetail(Map<String, dynamic> claim) => showDialog(context: context, builder: (context) => _ClaimDetailModal(claim: claim, onUpdate: _loadData));

  void _exportData() async {
    final headers = ['Type', 'Client', 'Expert / Sujet', 'Date', 'Statut / Info'];
    final reviewRows = _allReviews.map((r) => [
      'AVIS',
      r['clientName'] ?? '',
      r['expertName'] ?? '',
      r['date'] ?? '',
      'Note: ${(r['note'] ?? 0).toStringAsFixed(1)}/5',
    ]).toList();

    final claimRows = _allClaims.map((c) => [
      'RÉCLAMATION',
      c['clientName'] ?? '',
      c['description'] ?? '',
      c['date'] ?? '',
      c['status'] ?? 'EN ATTENTE',
    ]).toList();

    await AdminExportUtil.exportPageToPdf(
      filename: 'avis_et_reclamations_presto_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      title: 'Avis & Réclamations',
      subtitle: 'Synthèse des retours clients et réclamations de la plateforme Presto',
      kpis: [
        {'label': 'Total Avis', 'value': _allReviews.length.toString()},
        {'label': 'Note Moyenne', 'value': _stats != null ? '${_stats!.averageRating.toStringAsFixed(1)}/5' : 'N/A'},
        {'label': 'Réclamations', 'value': _allClaims.length.toString()},
        {'label': 'Note Globale', 'value': _stats != null ? _stats!.averageRating.toStringAsFixed(1) : '0.0'},
      ],
      tableHeaders: headers,
      tableRows: [...reviewRows, ...claimRows],
    );
  }
}

class _BaseFullListModal extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;
  final String filterType; // 'REVIEW' or 'CLAIM'

  const _BaseFullListModal({
    required this.title, 
    required this.icon, 
    required this.color, 
    required this.items, 
    required this.itemBuilder,
    required this.filterType,
  });

  @override
  State<_BaseFullListModal> createState() => _BaseFullListModalState();
}

class _BaseFullListModalState extends State<_BaseFullListModal> {
  String _search = '';
  String _selectedFilter = 'TOUT'; // 'TOUT', or 1-5 for reviews, or 'EN_ATTENTE'/'TRAITEE' for claims
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  void _applyFilter() {
    setState(() {
      _filtered = widget.items.where((item) {
        // Search filter
        final content = (item['commentaire'] ?? item['description'] ?? '').toString().toLowerCase();
        final client = (item['clientName'] ?? '').toString().toLowerCase();
        final expert = (item['expertName'] ?? '').toString().toLowerCase();
        final matchesSearch = content.contains(_search.toLowerCase()) || 
                             client.contains(_search.toLowerCase()) || 
                             expert.contains(_search.toLowerCase());

        if (!matchesSearch) return false;

        // Custom filter
        if (_selectedFilter == 'TOUT') return true;

        if (widget.filterType == 'REVIEW') {
          return item['note'].toString() == _selectedFilter;
        } else {
          return item['etat'] == _selectedFilter;
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final modalWidth = isMobile ? screenWidth * 0.95 : (screenWidth < 1024 ? 600.0 : 800.0);
    final modalHeight = isMobile ? MediaQuery.of(context).size.height * 0.85 : 750.0;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: modalWidth,
        height: modalHeight,
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(widget.icon, color: widget.color, size: isMobile ? 20 : 24),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(
                    widget.title, 
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20, 
                      fontWeight: FontWeight.bold
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context), 
                  icon: const Icon(LucideIcons.x),
                  iconSize: isMobile ? 18 : 24,
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),
            
            // Search & Filters Row
            Row(
              children: [
                Expanded(
                  flex: isMobile ? 2 : 3,
                  child: TextField(
                    onChanged: (v) { _search = v; _applyFilter(); },
                    decoration: InputDecoration(
                      hintText: isMobile ? 'Rechercher...' : 'Rechercher un mot-clé, client...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16, 
                        vertical: 0
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: BorderSide.none
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 16),
                Expanded(
                  flex: isMobile ? 1 : 2,
                  child: _buildFilterDropdown(isMobile),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),
            
            // List
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('Aucun résultat trouvé'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) => widget.itemBuilder(context, _filtered[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(bool isMobile) {
    List<DropdownMenuItem<String>> menuItems = [
      DropdownMenuItem(
        value: 'TOUT', 
        child: Text(
          isMobile ? 'Tous' : 'Tous les éléments',
          style: TextStyle(fontSize: isMobile ? 12 : 14),
        ),
      ),
    ];

    if (widget.filterType == 'REVIEW') {
      menuItems.addAll([
        DropdownMenuItem(
          value: '5', 
          child: Text(
            isMobile ? '⭐⭐⭐⭐⭐' : '⭐⭐⭐⭐⭐ (5)',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
        DropdownMenuItem(
          value: '4', 
          child: Text(
            isMobile ? '⭐⭐⭐⭐' : '⭐⭐⭐⭐ (4)',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
        DropdownMenuItem(
          value: '3', 
          child: Text(
            isMobile ? '⭐⭐⭐' : '⭐⭐⭐ (3)',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
        DropdownMenuItem(
          value: '2', 
          child: Text(
            isMobile ? '⭐⭐' : '⭐⭐ (2)',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
        DropdownMenuItem(
          value: '1', 
          child: Text(
            isMobile ? '⭐' : '⭐ (1)',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
      ]);
    } else {
      menuItems.addAll([
        DropdownMenuItem(
          value: 'EN_ATTENTE', 
          child: Text(
            'En attente',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
        DropdownMenuItem(
          value: 'TRAITEE', 
          child: Text(
            'Traitées',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
      ]);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          isExpanded: true,
          items: menuItems,
          onChanged: (v) {
            if (v != null) {
              setState(() => _selectedFilter = v);
              _applyFilter();
            }
          },
        ),
      ),
    );
  }
}

class _ClaimDetailModal extends StatefulWidget {
  final Map<String, dynamic> claim;
  final VoidCallback onUpdate;
  const _ClaimDetailModal({required this.claim, required this.onUpdate});
  @override
  State<_ClaimDetailModal> createState() => _ClaimDetailModalState();
}

class _ClaimDetailModalState extends State<_ClaimDetailModal> {
  final TextEditingController _responseController = TextEditingController();
  final AdminDashboardService _service = AdminDashboardService();
  final NotificationService _notificationService = NotificationService();
  bool _submitting = false;
  @override
  void initState() { super.initState(); _responseController.text = widget.claim['adminResponse'] ?? ''; }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 500, padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestion de Réclamation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text(widget.claim['description'], style: const TextStyle(fontSize: 14, height: 1.5)),
            const Divider(height: 48),
            const Text('Réponse Administrateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: _responseController, maxLines: 3, decoration: InputDecoration(hintText: 'Votre message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: const Color(0xFFF8FAFC))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _submitting ? null : () => _submit(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A99), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Enregistrer la réponse'))),
          ],
        ),
      ),
    );
  }
  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _service.updateClaim(
        widget.claim['id'], 
        response: _responseController.text, 
        status: 'TRAITEE' // Automatically mark as processed
      );
      
      // Notify the person who made the claim
      final String? userId = widget.claim['typeReclamateur'] == 'EXPERT' 
          ? widget.claim['idExpert'] 
          : widget.claim['idClient'];

      if (userId != null) {
        await _notificationService.sendNotification(
          idUtilisateur: userId,
          titre: "Réponse à votre réclamation",
          corps: "Un administrateur a répondu à votre réclamation concernant l'intervention ${widget.claim['idIntervention']}.",
          type: 'claim',
          relatedId: widget.claim['id'],
        );
      }

      widget.onUpdate();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
