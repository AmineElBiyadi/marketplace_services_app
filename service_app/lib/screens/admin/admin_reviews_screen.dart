import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
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
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final mockStats = AdminDashboardStats(
      totalUsers: 156,
      totalClients: 120,
      totalProviders: 36,
      pendingProviders: 5,
      totalReservations: 450,
      reservationsThisMonth: 42,
      openClaims: 4,
      averageRating: 4.5,
      freeProviders: 20,
      premiumProviders: 16,
      totalRevenue: 25000,
      unreadNotifications: 12,
      userGrowth: '+12%',
      revenueGrowth: '+8%',
      cancelledReservations: 15,
      totalFinishedReservations: 380,
    );

    final mockReviews = [
      {'id': '1', 'note': 5.0, 'commentaire': 'Excellent service, très professionnel !', 'clientName': 'Hicham Amrani', 'expertName': 'Youssef El Fassi', 'date': '20/03/2024', 'isHidden': false},
      {'id': '2', 'note': 4.0, 'commentaire': 'Bonne prestation mais un peu de retard.', 'clientName': 'Selma Benani', 'expertName': 'Mina Chafik', 'date': '19/03/2024', 'isHidden': false},
      {'id': '3', 'note': 2.0, 'commentaire': 'Le travail n\'est pas fini correctement.', 'clientName': 'Karim Tadlaoui', 'expertName': 'Ahmed Said', 'date': '18/03/2024', 'isHidden': true},
      {'id': '4', 'note': 5.0, 'commentaire': 'Ponctuelle et efficace. Je recommande.', 'clientName': 'Ines Mansouri', 'expertName': 'Mina Chafik', 'date': '17/03/2024', 'isHidden': false},
      {'id': '5', 'note': 3.0, 'commentaire': 'Moyen, peut mieux faire.', 'clientName': 'Ali Fassi', 'expertName': 'Youssef El Fassi', 'date': '16/03/2024', 'isHidden': false},
    ];

    final mockClaims = [
      {'id': 'c1', 'description': 'Retard de plus de 2 heures sans prévenir.', 'typeReclamateur': 'CLIENT', 'etat': 'EN_ATTENTE', 'idIntervention': 'INT-9921', 'clientName': 'Omar Tazi', 'expertName': 'Said Bakkali', 'adminResponse': null, 'date': '20/03/2024'},
      {'id': 'c2', 'description': 'Dommage causé sur le matériel pendant l\'intervention.', 'typeReclamateur': 'CLIENT', 'etat': 'TRAITEE', 'idIntervention': 'INT-8834', 'clientName': 'Lina Filali', 'expertName': 'Driss Houari', 'adminResponse': 'Une compensation a été accordée.', 'date': '15/03/2024'},
      {'id': 'c3', 'description': 'Client agressif et refuse de payer le surplus.', 'typeReclamateur': 'EXPERT', 'etat': 'EN_ATTENTE', 'idIntervention': 'INT-7721', 'clientName': 'Majid Kadiri', 'expertName': 'Ahmed Slimani', 'adminResponse': null, 'date': '21/03/2024'},
    ];
    
    if (mounted) {
      setState(() {
        _stats = mockStats;
        _allReviews = mockReviews;
        _allClaims = mockClaims;
        _loading = false;
      });
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
            _buildPremiumHeader(isMobile),
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

  Widget _buildPremiumHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(builder: (context) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(icon: const Icon(LucideIcons.menu), onPressed: () => Scaffold.of(context).openDrawer()),
            )),
          const Text('Avis & Réclamations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
          const Spacer(),
          IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 20)),
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
      width: width,
      padding: const EdgeInsets.all(20),
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
                  child: CircularProgressIndicator(value: 0.9, strokeWidth: 12, backgroundColor: _primary.withOpacity(0.05), color: _primary, strokeCap: StrokeCap.round),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('4.5', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primary)),
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
          ..._allReviews.take(3).map((r) => _buildReviewCard(r)),
          const SizedBox(height: 32),
          _sectionSubHeader('Réclamations Prioritaires', LucideIcons.alertTriangle, Colors.redAccent, () => _showAllClaimsModal()),
          ..._allClaims.take(3).map((c) => _buildClaimCard(c)),
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
              ..._allReviews.take(3).map((r) => _buildReviewCard(r)),
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
              ..._allClaims.take(3).map((c) => _buildClaimCard(c)),
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
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
        const Spacer(),
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
              _miniIconAction(isHidden ? LucideIcons.eye : LucideIcons.eyeOff, isHidden ? Colors.green : _primary, () => _toggleVisibility(review)),
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
    final data = [{'stars': '5★', 'count': 320}, {'stars': '4★', 'count': 180}, {'stars': '3★', 'count': 45}, {'stars': '2★', 'count': 15}, {'stars': '1★', 'count': 8}];
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround, maxY: 320,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(data[v.toInt()]['stars'] as String, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 80, reservedSize: 30, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(color: _textSecondary, fontSize: 10)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: true, horizontalInterval: 80, getDrawingHorizontalLine: (v) => FlLine(color: _border, strokeWidth: 1, dashArray: [5, 5]), getDrawingVerticalLine: (v) => FlLine(color: _border, strokeWidth: 1, dashArray: [5, 5])),
          borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: _primary.withOpacity(0.5)), left: BorderSide(color: _primary.withOpacity(0.5)))),
          barGroups: data.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: (e.value['count'] as num).toDouble(), color: Colors.amber[300]!, width: isMobile ? 30 : 60, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))])).toList(),
        ),
      ),
    );
  }

  void _showAllReviewsModal() {
    showDialog(
      context: context,
      builder: (context) => _BaseFullListModal(
        title: 'Toutes les Évaluations',
        icon: LucideIcons.star,
        color: Colors.amber,
        items: _allReviews,
        itemBuilder: (context, item) => _buildReviewCard(item),
      ),
    );
  }

  void _showAllClaimsModal() {
    showDialog(
      context: context,
      builder: (context) => _BaseFullListModal(
        title: 'Toutes les Réclamations',
        icon: LucideIcons.alertTriangle,
        color: Colors.redAccent,
        items: _allClaims,
        itemBuilder: (context, item) => _buildClaimCard(item),
      ),
    );
  }

  void _toggleVisibility(Map<String, dynamic> r) => setState(() { final idx = _allReviews.indexOf(r); if (idx != -1) _allReviews[idx]['isHidden'] = !(_allReviews[idx]['isHidden'] ?? false); });
  void _deleteReview(Map<String, dynamic> r) => setState(() => _allReviews.remove(r));
  void _markAsTreated(Map<String, dynamic> c) => setState(() { final idx = _allClaims.indexOf(c); if (idx != -1) _allClaims[idx]['etat'] = 'TRAITEE'; });
  void _deleteClaim(Map<String, dynamic> c) => setState(() => _allClaims.remove(c));
  void _viewClaimDetail(Map<String, dynamic> claim) => showDialog(context: context, builder: (context) => _ClaimDetailModal(claim: claim, onUpdate: _loadData));
}

class _BaseFullListModal extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;

  const _BaseFullListModal({required this.title, required this.icon, required this.color, required this.items, required this.itemBuilder});

  @override
  State<_BaseFullListModal> createState() => _BaseFullListModalState();
}

class _BaseFullListModalState extends State<_BaseFullListModal> {
  String _search = '';
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  void _applyFilter() {
    setState(() {
      _filtered = widget.items.where((item) {
        final content = (item['commentaire'] ?? item['description'] ?? '').toString().toLowerCase();
        final name = (item['clientName'] ?? '').toString().toLowerCase();
        return content.contains(_search.toLowerCase()) || name.contains(_search.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 800, height: 750,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Row(
              children: [
                Icon(widget.icon, color: widget.color),
                const SizedBox(width: 12),
                Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              onChanged: (v) { _search = v; _applyFilter(); },
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true, fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _responseController.text = widget.claim['adminResponse'] ?? '';
  }

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
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _loading ? null : () => _submit(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A99), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Enregistrer la réponse'))),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async { setState(() => _loading = true); await Future.delayed(const Duration(milliseconds: 500)); widget.onUpdate(); if (mounted) Navigator.pop(context); }
}
