import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';
import '../../models/booking.dart';

class ProviderAgendaScreen extends StatefulWidget {
  final String expertId;
  const ProviderAgendaScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderAgendaScreen> createState() => _ProviderAgendaScreenState();
}

class _ProviderAgendaScreenState extends State<ProviderAgendaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final List<String> _weekDaysShort = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"];
  final List<int> _hours = List.generate(12, (i) => i + 7); // 7h - 18h

  DateTime _gridDate = DateTime.now();
  DateTime _queryDate = DateTime.now();
  Stream<List<InterventionModel>>? _interventionsStream;
  List<InterventionModel> _cachedInterventions = [];
  // Track which month the cache belongs to — prevents stale cross-month data
  String _cacheMonth = '';
  String? _resolvedExpertId;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _queryDate = DateTime(_gridDate.year, _gridDate.month, 1);
    _resolveAndInit();
  }

  Future<void> _resolveAndInit() async {
    debugPrint("[ProviderAgendaScreen] Resolving session...");
    final expertId = await _firestoreService.getExpertIdFromSession();
    debugPrint("[ProviderAgendaScreen] Resolved Expert ID: $expertId");
    
    if (expertId != null && mounted) {
      _resolvedExpertId = expertId;
      
      // Listen to premium status
      _firestoreService.isExpertPremium(expertId).listen((premium) {
        if (mounted) setState(() => _isPremium = premium);
      });

      _subscribeToStream();
      setState(() {});
    }
  }

  void _subscribeToStream() {
    if (_resolvedExpertId == null) return;
    final newMonthKey = '${_queryDate.year}-${_queryDate.month}';
    // Clear cache immediately when switching to a different month
    if (_cacheMonth != newMonthKey) {
      _cachedInterventions = [];
      _cacheMonth = newMonthKey;
    }
    _interventionsStream = _firestoreService.getExpertInterventionsByMonth(_resolvedExpertId!, _queryDate);
  }

  void _previousMonth() {
    _queryDate = DateTime(_queryDate.year, _queryDate.month - 1, 1);
    _gridDate = _queryDate;
    _subscribeToStream();
    setState(() {});
  }

  void _nextMonth() {
    _queryDate = DateTime(_queryDate.year, _queryDate.month + 1, 1);
    _gridDate = _queryDate;
    _subscribeToStream();
    setState(() {});
  }

  void _previousWeek() {
    _gridDate = _gridDate.subtract(const Duration(days: 7));
    if (_gridDate.month != _queryDate.month || _gridDate.year != _queryDate.year) {
      _queryDate = DateTime(_gridDate.year, _gridDate.month, 1);
      _cachedInterventions = [];
      _subscribeToStream();
    }
    setState(() {});
  }

  void _nextWeek() {
    _gridDate = _gridDate.add(const Duration(days: 7));
    if (_gridDate.month != _queryDate.month || _gridDate.year != _queryDate.year) {
      _queryDate = DateTime(_gridDate.year, _gridDate.month, 1);
      _cachedInterventions = [];
      _subscribeToStream();
    }
    setState(() {});
  }

  DateTime get _startOfWeek {
    int daysToSubtract = _gridDate.weekday - 1;
    return DateTime(_gridDate.year, _gridDate.month, _gridDate.day).subtract(Duration(days: daysToSubtract));
  }

  DateTime get _endOfWeek => _startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));

  @override
  Widget build(BuildContext context) {
    if (_resolvedExpertId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return ProviderLayout(
      activeRoute: '/provider/agenda',
      expertId: _resolvedExpertId!,
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              _buildWeekPicker(),
              Expanded(
                child: _interventionsStream == null 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : StreamBuilder<List<InterventionModel>>(
                      stream: _interventionsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                        }
                        
                        // Only update cache if the data belongs to the current query month
                        if (snapshot.hasData) {
                          final newMonthKey = '${_queryDate.year}-${_queryDate.month}';
                          if (_cacheMonth == newMonthKey) {
                            _cachedInterventions = snapshot.data!;
                          }
                        }
        
                        final bool isWaiting = snapshot.connectionState == ConnectionState.waiting;
                        
                        final allInterventions = _cachedInterventions;
                        debugPrint("[ProviderAgendaScreen] UI Render - All: ${allInterventions.length}");

                        if (isWaiting && allInterventions.isEmpty) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }

                        final weekInterventions = allInterventions.where((i) {
                          if (i.dateDebutIntervention == null) return false;
                          final start = _startOfWeek.subtract(const Duration(seconds: 1));
                          final end = _endOfWeek.add(const Duration(seconds: 1));
                          return i.dateDebutIntervention!.isAfter(start) &&
                                 i.dateDebutIntervention!.isBefore(end);
                        }).toList();
                        debugPrint("[ProviderAgendaScreen] UI Render - Week: ${weekInterventions.length}");
        
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              _buildCalendarGrid(weekInterventions),
                              const SizedBox(height: 24),
                              _buildSummaryList(allInterventions),
                              if (isWaiting)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary, backgroundColor: Colors.transparent),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
          if (!_isPremium) _buildLockedOverlay(),
        ],
      ),
    );
  }

  Widget _buildLockedOverlay() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 24),
          const Text(
            "Disponible avec le pack Premium",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Accédez aux statistiques avancées pour booster votre activité",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/provider/$_resolvedExpertId/subscription'),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: const Text("Passer Premium", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          const Text(
            "Mon Agenda",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const Spacer(),
          Text(
            DateFormat('MMMM yyyy', 'fr').format(_queryDate).toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(LucideIcons.chevronLeft, size: 20, color: AppColors.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekPicker() {
    final start = DateFormat('dd MMM', 'fr').format(_startOfWeek);
    final end = DateFormat('dd MMM yyyy', 'fr').format(_endOfWeek);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: _previousWeek, icon: const Icon(LucideIcons.arrowLeft, size: 16)),
          Text(
            "Semaine du $start au $end",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          IconButton(onPressed: _nextWeek, icon: const Icon(LucideIcons.arrowRight, size: 16)),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(List<InterventionModel> interventions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Week days header
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                const SizedBox(width: 44),
                ...List.generate(7, (index) {
                  final dayDate = _startOfWeek.add(Duration(days: index));
                  final isToday = dayDate.day == DateTime.now().day && dayDate.month == DateTime.now().month && dayDate.year == DateTime.now().year;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            _weekDaysShort[index],
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isToday ? AppColors.primary : const Color(0xFF1E293B)),
                          ),
                          Text(
                            "${dayDate.day}",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isToday ? AppColors.primary : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Hourly grid
          Stack(
            children: [
              Column(
                children: _hours.map((hour) => Container(
                  height: 60,
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        alignment: Alignment.center,
                        child: Text(
                          "$hour:00",
                          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ),
                      ...List.generate(7, (index) => Expanded(
                        child: Container(
                          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFF1F5F9)))),
                        ),
                      )),
                    ],
                  ),
                )).toList(),
              ),
              // Positioning interventions
              ...interventions.map((interv) {
                final date = interv.dateDebutIntervention!;
                final dayInWeek = date.weekday - 1; 
                final startHour = date.hour;
                final startMin = date.minute;
                final endHour = interv.dateFinIntervention?.hour ?? (startHour + 1);
                final endMin = interv.dateFinIntervention?.minute ?? 0;

                if (startHour < 7 || startHour >= 19) return const SizedBox.shrink();

                final double top = (startHour - 7) * 60.0 + (startMin / 60.0 * 60.0);
                final double durationInHours = (endHour + endMin / 60.0) - (startHour + startMin / 60.0);
                final double height = (durationInHours * 60.0) - 4;

                return Positioned(
                  top: top + 2,
                  left: 44 + (dayInWeek * (MediaQuery.of(context).size.width - 76) / 7),
                  width: (MediaQuery.of(context).size.width - 76) / 7 - 4,
                  height: height.isNegative ? 20 : height,
                  child: GestureDetector(
                    onTap: () => _showInterventionDetails(interv),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getStatusColor(interv.statut).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: _getStatusColor(interv.statut), width: 3)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            interv.tacheSnapshot?['serviceNom'] ?? 'Intervention',
                            style: TextStyle(
                              fontSize: height < 40 ? 10 : 12,
                              fontWeight: FontWeight.w800,
                              color: _getStatusColor(interv.statut),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (height > 45)
                            Text(
                              interv.clientSnapshot?['nom'] ?? '',
                              style: TextStyle(fontSize: 10, color: _getStatusColor(interv.statut).withOpacity(0.9), fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryList(List<InterventionModel> interventions) {
    // Sort all interventions for the month by date
    final sorted = List<InterventionModel>.from(interventions)
      ..sort((a, b) => (a.dateDebutIntervention ?? DateTime.now()).compareTo(b.dateDebutIntervention ?? DateTime.now()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Toutes les interventions du mois",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            _badge("${interventions.length}", AppColors.primary),
          ],
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text("Aucune intervention ce mois", style: TextStyle(color: Colors.grey, fontSize: 13))),
          )
        else
          ...sorted.map((interv) => GestureDetector(
            onTap: () => _showInterventionDetails(interv),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor(interv.statut).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.calendar, color: _getStatusColor(interv.statut), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          interv.tacheSnapshot?['serviceNom'] ?? 'Service',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
                        ),
                        Text(
                          "${DateFormat('dd/MM HH:mm', 'fr').format(interv.dateDebutIntervention!)} • ${interv.clientSnapshot?['nom'] ?? 'Client'}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  _badge(interv.statut, _getStatusColor(interv.statut)),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACCEPTEE': return Colors.green;
      case 'TERMINEE': return Colors.blue;
      case 'EN_ATTENTE': return Colors.orange;
      case 'REFUSEE': return Colors.red;
      case 'ANNULEE': return Colors.grey;
      default: return AppColors.primary;
    }
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  void _showInterventionDetails(InterventionModel interv) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _getStatusColor(interv.statut).withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.info, color: _getStatusColor(interv.statut)),
              const SizedBox(width: 12),
              const Text("Détails de l'intervention", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _modalHeader(interv),
              const Divider(height: 32),
              _detailRow("Service", interv.tacheSnapshot?['serviceNom']),
              _detailRow("Date", DateFormat('dd MMMM yyyy', 'fr').format(interv.dateDebutIntervention!)),
              _detailRow("Horaire", "${DateFormat('HH:mm').format(interv.dateDebutIntervention!)} - ${DateFormat('HH:mm').format(interv.dateFinIntervention ?? interv.dateDebutIntervention!.add(const Duration(hours: 1)))}"),
              _detailRow("Prix", "${interv.prixNegocie} DH"),
              _detailRow("Statut", interv.statut),
              const SizedBox(height: 8),
              Text("ID Document: ${interv.id}", style: const TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              const Text("CLIENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _clientCard(interv.clientSnapshot),
              const SizedBox(height: 20),
              const Text("ADRESSE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _locationCard(interv.adresseSnapshot),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              // Action logic could go here (e.g. call client)
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _modalHeader(InterventionModel interv) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: const Icon(LucideIcons.wrench, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(interv.tacheSnapshot?['serviceNom'] ?? 'Intervention', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              _badge(interv.statut, _getStatusColor(interv.statut)),
            ],
          ),
        )
      ],
    );
  }

  Widget _clientCard(Map<String, dynamic>? client) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: (client?['photo'] != null && (client?['photo'].toString().startsWith('http') ?? false)) ? NetworkImage(client!['photo']) : null,
            child: (client?['photo'] == null || !(client?['photo'].toString().startsWith('http') ?? false)) ? const Icon(LucideIcons.user, size: 20, color: AppColors.primary) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client?['nom'] ?? 'Client inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(client?['telephone'] ?? 'Pas de numéro', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.phone, size: 18, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _locationCard(Map<String, dynamic>? addr) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.mapPin, size: 18, color: Colors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "${addr?['Rue'] ?? ''}, ${addr?['Ville'] ?? ''} ${addr?['CodePostal'] ?? ''}",
              style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF1E293B)),
            ),
          )
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value?.toString() ?? 'N/A', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
