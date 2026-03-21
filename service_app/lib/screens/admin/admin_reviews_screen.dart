import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/admin_dashboard_service.dart';
import '../../layouts/admin_layout.dart';
import 'package:intl/intl.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> with SingleTickerProviderStateMixin {
  final AdminDashboardService _service = AdminDashboardService();
  late TabController _tabController;

  static const Color _primary = Color(0xFF3D5A99);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  bool _loading = true;
  AdminDashboardStats? _stats;
  List<Map<String, dynamic>> _allReviews = [];
  List<Map<String, dynamic>> _filteredReviews = [];
  List<Map<String, dynamic>> _allClaims = [];
  List<Map<String, dynamic>> _filteredClaims = [];

  // Filters
  double? _selectedRating;
  String _reviewSearch = '';
  String _claimSearch = '';
  String _selectedClaimStatus = 'TOUS';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    // Simulate a network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
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
        _applyFilters();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      // Filter Reviews
      _filteredReviews = _allReviews.where((r) {
        final ratingMatches = _selectedRating == null || (r['note'] as double).toInt() == _selectedRating!.toInt();
        final searchMatches = _reviewSearch.isEmpty || 
            r['commentaire'].toLowerCase().contains(_reviewSearch.toLowerCase()) ||
            r['clientName'].toLowerCase().contains(_reviewSearch.toLowerCase()) ||
            r['expertName'].toLowerCase().contains(_reviewSearch.toLowerCase());
        return ratingMatches && searchMatches;
      }).toList();

      // Filter Claims
      _filteredClaims = _allClaims.where((c) {
        final statusMatches = _selectedClaimStatus == 'TOUS' || c['etat'] == _selectedClaimStatus;
        final searchMatches = _claimSearch.isEmpty || 
            c['description'].toLowerCase().contains(_claimSearch.toLowerCase()) ||
            c['clientName'].toLowerCase().contains(_claimSearch.toLowerCase()) ||
            c['expertName'].toLowerCase().contains(_claimSearch.toLowerCase());
        return statusMatches && searchMatches;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return AdminLayout(
      activeRoute: '/admin/reviews',
      child: Column(
        children: [
          _buildTopBar(isMobile),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDashboardTab(isMobile),
                      _buildReviewsTab(isMobile),
                      _buildClaimsTab(isMobile),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isMobile)
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(LucideIcons.menu, color: _textPrimary),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              const Text('Avis & Réclamations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
              const Spacer(),
              IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 18, color: _textSecondary)),
            ],
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: _primary,
            unselectedLabelColor: _textSecondary,
            indicatorColor: _primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Avis (évaluations)'),
              Tab(text: 'Réclamations'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(bool isMobile) {
    if (_stats == null) return const Center(child: Text('Erreur de chargement des stats'));
    
    final treatedCount = _allClaims.where((c) => c['etat'] == 'TRAITEE').length;
    final treatmentRate = _allClaims.isEmpty ? 100 : (treatedCount / _allClaims.length * 100).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildStatCard('Total Avis', _allReviews.length.toString(), LucideIcons.star, Colors.blue),
              _buildStatCard('Note Moyenne', '${_stats?.averageRating.toStringAsFixed(1)} ⭐', LucideIcons.trendingUp, Colors.amber),
              _buildStatCard('Réclamations', _allClaims.length.toString(), LucideIcons.alertCircle, Colors.orange),
              _buildStatCard('Taux de Traitement', '$treatmentRate%', LucideIcons.checkCircle, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 13, color: _textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(bool isMobile) {
    return Column(
      children: [
        _buildReviewFilters(isMobile),
        Expanded(
          child: _filteredReviews.isEmpty
              ? const Center(child: Text('Aucun avis trouvé'))
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _filteredReviews.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _buildReviewCard(_filteredReviews[index], isMobile),
                ),
        ),
      ],
    );
  }

  Widget _buildReviewFilters(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _border))),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: TextField(
              onChanged: (v) {
                _reviewSearch = v;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un avis...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          // Rating Filter
          const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ToggleButtons(
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: _primary,
            onPressed: (index) {
              setState(() {
                if (_selectedRating == (index + 1).toDouble()) {
                  _selectedRating = null;
                } else {
                  _selectedRating = (index + 1).toDouble();
                }
                _applyFilters();
              });
            },
            isSelected: List.generate(5, (i) => _selectedRating == (i + 1).toDouble()),
            children: List.generate(5, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${i + 1} ⭐', style: const TextStyle(fontSize: 12)),
            )),
          ),
          if (_selectedRating != null)
            TextButton(
              onPressed: () => setState(() { _selectedRating = null; _applyFilters(); }),
              child: const Text('Réinitialiser', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isMobile) {
    final bool isHidden = review['isHidden'] ?? false;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHidden ? Colors.grey.withOpacity(0.05) : _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHidden ? Colors.red.withOpacity(0.2) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildRatingStars(review['note'] ?? 0),
              const Spacer(),
              _buildReviewActions(review),
            ],
          ),
          const SizedBox(height: 12),
          Text(review['commentaire'] ?? 'Pas de commentaire', style: TextStyle(fontSize: 14, color: isHidden ? _textSecondary : _textPrimary, fontStyle: isHidden ? FontStyle.italic : null)),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniProfile('Client', review['clientName']),
              const SizedBox(width: 24),
              _miniProfile('Expert', review['expertName']),
              const Spacer(),
              Text(review['date'], style: const TextStyle(fontSize: 11, color: _textSecondary)),
            ],
          ),
          if (isHidden)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: const Text('MASQUÉ POUR LES UTILISATEURS', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double note) {
    return Row(
      children: List.generate(5, (i) => Icon(
        i < note ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 16,
      )),
    );
  }

  Widget _buildReviewActions(Map<String, dynamic> review) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(review['isHidden'] ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: _primary),
          onPressed: () => _toggleReviewVisibility(review),
          tooltip: review['isHidden'] ? 'Afficher' : 'Masquer',
        ),
        IconButton(
          icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
          onPressed: () => _deleteReview(review),
          tooltip: 'Supprimer',
        ),
      ],
    );
  }

  Widget _miniProfile(String label, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _textSecondary)),
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Future<void> _toggleReviewVisibility(Map<String, dynamic> review) async {
    final int index = _allReviews.indexWhere((r) => r['id'] == review['id']);
    if (index != -1) {
      setState(() {
        _allReviews[index]['isHidden'] = !(_allReviews[index]['isHidden'] ?? false);
        _applyFilters();
      });
    }
  }

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'avis ?'),
        content: const Text('Cette action est irréversible (Mode Démo Front-end).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirm) {
      setState(() {
        _allReviews.removeWhere((r) => r['id'] == review['id']);
        _applyFilters();
      });
    }
  }

  Widget _buildClaimsTab(bool isMobile) {
    return Column(
      children: [
        _buildClaimFilters(isMobile),
        Expanded(
          child: _filteredClaims.isEmpty
              ? const Center(child: Text('Aucune réclamation trouvée'))
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _filteredClaims.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _buildClaimCard(_filteredClaims[index], isMobile),
                ),
        ),
      ],
    );
  }

  Widget _buildClaimFilters(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _border))),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: TextField(
              onChanged: (v) {
                _claimSearch = v;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher une réclamation...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          DropdownButton<String>(
            value: _selectedClaimStatus,
            underline: const SizedBox(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _selectedClaimStatus = v;
                  _applyFilters();
                });
              }
            },
            items: ['TOUS', 'EN_ATTENTE', 'TRAITEE'].map((s) => DropdownMenuItem(
              value: s,
              child: Text(s == 'TOUS' ? 'Tous les statuts' : s.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusBadge(claim['etat']),
              Text(claim['date'], style: const TextStyle(fontSize: 11, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(claim['description'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          Text('Par ${claim['clientName']} (${claim['typeReclamateur']})', style: const TextStyle(fontSize: 12, color: _textSecondary)),
          const Divider(height: 32),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _viewClaimDetail(claim),
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: const Text('Voir détails', style: TextStyle(fontSize: 13)),
              ),
              const Spacer(),
              if (claim['etat'] == 'EN_ATTENTE')
                ElevatedButton(
                  onPressed: () => _markClaimAsTreated(claim),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, elevation: 0),
                  child: const Text('Traiter', style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _deleteClaim(claim),
                icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final bool isTreated = status == 'TRAITEE';
    final Color color = isTreated ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _viewClaimDetail(Map<String, dynamic> claim) {
    showDialog(
      context: context,
      builder: (context) => _ClaimDetailModal(claim: claim, onUpdate: _loadData),
    );
  }

  Future<void> _markClaimAsTreated(Map<String, dynamic> claim) async {
    final int index = _allClaims.indexWhere((c) => c['id'] == claim['id']);
    if (index != -1) {
      setState(() {
        _allClaims[index]['etat'] = 'TRAITEE';
        _applyFilters();
      });
    }
  }

  Future<void> _deleteClaim(Map<String, dynamic> claim) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la réclamation ?'),
        content: const Text('Cette action est irréversible (Mode Démo Front-end).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirm) {
      setState(() {
        _allClaims.removeWhere((c) => c['id'] == claim['id']);
        _applyFilters();
      });
    }
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
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.alertCircle, color: Colors.orange),
                const SizedBox(width: 12),
                const Text('Détails Réclamation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
              ],
            ),
            const Divider(height: 32),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Text(widget.claim['description'], style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _info('Demandeur', widget.claim['clientName'])),
                Expanded(child: _info('Type', widget.claim['typeReclamateur'])),
              ],
            ),
            const SizedBox(height: 16),
            _info('Intervention liée', widget.claim['idIntervention'] ?? 'N/A'),
            const Divider(height: 48),
            const Text('Réponse Administrateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _responseController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Votre réponse...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.claim['etat'] == 'EN_ATTENTE')
                  ElevatedButton(
                    onPressed: _loading ? null : () => _submit(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Traiter & Répondre'),
                  )
                else
                  ElevatedButton(
                    onPressed: _loading ? null : () => _submit(false),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A99)),
                    child: const Text('Mettre à jour la réponse'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Future<void> _submit(bool markTreated) async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    // En mode Mock, on simule l'update locally via le dialogue qui n'a pas accès direct à la liste 
    // On ferme juste et l'utilisateur devra rafraîchir ou on pourrait passer un callback plus complexe.
    widget.onUpdate(); 
    if (mounted) Navigator.pop(context);
  }
}
