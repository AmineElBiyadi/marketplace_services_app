import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';
import '../../models/booking.dart';

enum AgendaViewMode { month, week, day }

class ProviderAgendaScreen extends StatefulWidget {
  final String expertId;
  const ProviderAgendaScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderAgendaScreen> createState() => _ProviderAgendaScreenState();
}

class _ProviderAgendaScreenState extends State<ProviderAgendaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final List<String> _weekDaysShort = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  final List<int> _hours = List.generate(12, (i) => i + 7); // 7h - 18h

  DateTime _gridDate = DateTime.now();
  DateTime _queryDate = DateTime.now();
  AgendaViewMode _viewMode = AgendaViewMode.month;
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
    
    DateTime start;
    DateTime end;
    
    if (_viewMode == AgendaViewMode.week) {
      start = _startOfWeek;
      end = _endOfWeek;
    } else if (_viewMode == AgendaViewMode.day) {
      start = DateTime(_gridDate.year, _gridDate.month, _gridDate.day);
      end = DateTime(_gridDate.year, _gridDate.month, _gridDate.day, 23, 59, 59);
    } else {
      // Month mode: visible range should cover all days in the 5-6 weeks shown
      start = _startOfVisibleMonth;
      end = _endOfVisibleMonth;
    }

    // Use a slightly larger range for the stream to avoid issues with timezones or small overlaps
    // For the list below the grid, we use the whole month of the current selected date
    final firstOfMonth = DateTime(_gridDate.year, _gridDate.month, 1);
    final lastOfMonth = DateTime(_gridDate.year, _gridDate.month + 1, 0, 23, 59, 59);
    
    final newMonthKey = '${_gridDate.year}-${_gridDate.month}';
    if (_cacheMonth != newMonthKey) {
      _cachedInterventions = [];
      _cacheMonth = newMonthKey;
    }
    
    // We fetch for the whole month to populate the "All interventions of the month" list
    // This also fixes the boundary issue because _cachedInterventions will contain 
    // all interventions for the month of the currently viewed week/day.
    // However, if a week spans TWO months, we need both months.
    // To keep it simple and fix the boundary bug: fetch from start of visible range to end of visible range PLUS the month.
    
    final fetchStart = start.isBefore(firstOfMonth) ? start : firstOfMonth;
    final fetchEnd = end.isAfter(lastOfMonth) ? end : lastOfMonth;

    _interventionsStream = _firestoreService.getExpertInterventionsByRange(_resolvedExpertId!, fetchStart, fetchEnd);
  }

  void _previousMonth() {
    _gridDate = DateTime(_gridDate.year, _gridDate.month - 1, _gridDate.day);
    _subscribeToStream();
    setState(() {});
  }

  void _nextMonth() {
    _gridDate = DateTime(_gridDate.year, _gridDate.month + 1, _gridDate.day);
    _subscribeToStream();
    setState(() {});
  }

  void _navigatePrevious() {
    if (_viewMode == AgendaViewMode.month) {
      _gridDate = DateTime(_gridDate.year, _gridDate.month - 1, 1);
    } else if (_viewMode == AgendaViewMode.week) {
      _gridDate = _gridDate.subtract(const Duration(days: 7));
    } else {
      _gridDate = _gridDate.subtract(const Duration(days: 1));
    }
    _subscribeToStream();
    setState(() {});
  }

  void _navigateNext() {
    if (_viewMode == AgendaViewMode.month) {
      _gridDate = DateTime(_gridDate.year, _gridDate.month + 1, 1);
    } else if (_viewMode == AgendaViewMode.week) {
      _gridDate = _gridDate.add(const Duration(days: 7));
    } else {
      _gridDate = _gridDate.add(const Duration(days: 1));
    }
    _subscribeToStream();
    setState(() {});
  }

  DateTime get _startOfVisibleMonth {
    final first = DateTime(_gridDate.year, _gridDate.month, 1);
    int daysToSubtract = first.weekday - 1;
    return first.subtract(Duration(days: daysToSubtract));
  }

  DateTime get _endOfVisibleMonth => _startOfVisibleMonth.add(const Duration(days: 41, hours: 23, minutes: 59));

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
                          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                        }
                        
                        // Only update cache if the data belongs to the current query range
                        if (snapshot.hasData) {
                          _cachedInterventions = snapshot.data!;
                        }
        
                        final bool isWaiting = snapshot.connectionState == ConnectionState.waiting;
                        
                        final allInterventions = _cachedInterventions;
                        debugPrint("[ProviderAgendaScreen] UI Render - All: ${allInterventions.length}");

                        if (isWaiting && allInterventions.isEmpty) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }

                        final visibleInterventions = allInterventions.where((i) {
                          if (i.dateDebutIntervention == null) return false;
                          DateTime startRange;
                          DateTime endRange;
                          
                          if (_viewMode == AgendaViewMode.week) {
                            startRange = _startOfWeek;
                            endRange = _endOfWeek;
                          } else if (_viewMode == AgendaViewMode.day) {
                            startRange = DateTime(_gridDate.year, _gridDate.month, _gridDate.day);
                            endRange = DateTime(_gridDate.year, _gridDate.month, _gridDate.day, 23, 59, 59);
                          } else {
                            // Month mode, we show everything for the currently fetched range
                            return true;
                          }
                          
                          return i.dateDebutIntervention!.isAfter(startRange.subtract(const Duration(seconds: 1))) &&
                                 i.dateDebutIntervention!.isBefore(endRange.add(const Duration(seconds: 1)));
                        }).toList();
                        debugPrint("[ProviderAgendaScreen] UI Render - Visible: ${visibleInterventions.length}");
        
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              if (_viewMode == AgendaViewMode.month)
                                _buildMonthGrid(visibleInterventions)
                              else
                                _buildCalendarGrid(visibleInterventions),
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
            "Available with Premium pack",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Access advanced statistics to boost\nyour activity",
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
              label: const Text("Go Premium", style: TextStyle(fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "My Agenda",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildToggleButton("Day", _viewMode == AgendaViewMode.day, () {
                      setState(() { _viewMode = AgendaViewMode.day; _subscribeToStream(); });
                    }),
                    _buildToggleButton("Week", _viewMode == AgendaViewMode.week, () {
                      setState(() { _viewMode = AgendaViewMode.week; _subscribeToStream(); });
                    }),
                    _buildToggleButton("Month", _viewMode == AgendaViewMode.month, () {
                      setState(() { _viewMode = AgendaViewMode.month; _subscribeToStream(); });
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _navigatePrevious,
                icon: const Icon(LucideIcons.chevronLeft, size: 20, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                DateFormat('MMMM yyyy', 'en_US').format(_gridDate).toUpperCase(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.1),
              ),
              IconButton(
                onPressed: _navigateNext,
                icon: const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekPicker() {
    if (_viewMode == AgendaViewMode.month) return const SizedBox.shrink();
    
    final String label;
    if (_viewMode == AgendaViewMode.week) {
      final start = DateFormat('dd MMM', 'en_US').format(_startOfWeek);
      final end = DateFormat('dd MMM yyyy', 'en_US').format(_endOfWeek);
      label = "Week of $start to $end";
    } else {
      label = DateFormat('EEEE, dd MMMM yyyy', 'en_US').format(_gridDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: _navigatePrevious, icon: const Icon(LucideIcons.arrowLeft, size: 16)),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          IconButton(onPressed: _navigateNext, icon: const Icon(LucideIcons.arrowRight, size: 16)),
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
                if (_viewMode == AgendaViewMode.week)
                  ...List.generate(7, (index) {
                    final dayDate = _startOfWeek.add(Duration(days: index));
                    final isToday = dayDate.day == DateTime.now().day && dayDate.month == DateTime.now().month && dayDate.year == DateTime.now().year;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _gridDate = dayDate;
                            _viewMode = AgendaViewMode.day;
                            _subscribeToStream();
                          });
                        },
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
                      ),
                    );
                  })
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEEE', 'en_US').format(_gridDate),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          Text(
                            "${_gridDate.day}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      if (_viewMode == AgendaViewMode.week)
                        ...List.generate(7, (index) => Expanded(
                          child: Container(
                            decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFF1F5F9)))),
                          ),
                        ))
                      else
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFF1F5F9)))),
                          ),
                        ),
                    ],
                  ),
                )).toList(),
              ),
              // Positioning interventions
              ...interventions.map((interv) {
                final date = interv.dateDebutIntervention ?? interv.dateFinIntervention ?? interv.createdAt ?? DateTime.now();
                final dayInWeek = date.weekday - 1; 
                final startHour = date.hour;
                final startMin = date.minute;
                
                // Calculate duration, default to 1 hour if dateFinIntervention is missing
                final startDateTime = date;
                final endDateTime = interv.dateFinIntervention ?? startDateTime.add(const Duration(hours: 1));
                
                double durationInHours = endDateTime.difference(startDateTime).inMinutes / 60.0;
                
                // Visually ensure at least 1 hour for all blocks (fix for TERMINEE "line" issue)
                if (durationInHours < 0.8) durationInHours = 1.0;

                if (startHour < 7 || startHour >= 19) return const SizedBox.shrink();

                final double top = (startHour - 7) * 60.0 + (startMin / 60.0 * 60.0);
                final double height = (durationInHours * 60.0) - 4;

                final double totalWidth = MediaQuery.of(context).size.width - 76;
                final double itemWidth = (_viewMode == AgendaViewMode.week) ? (totalWidth / 7) : totalWidth;
                final double leftOffset = 44 + ((_viewMode == AgendaViewMode.week) ? (dayInWeek * itemWidth) : 0);

                return Positioned(
                  top: top + 2,
                  left: leftOffset,
                  width: itemWidth - 4,
                  height: height.isNegative ? 20 : height,
                  child: GestureDetector(
                    onTap: () => _showInterventionDetails(interv),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getStatusColor(interv.statut).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: _getStatusColor(interv.statut), width: 4)),
                        boxShadow: [
                          BoxShadow(color: _getStatusColor(interv.statut).withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              interv.tacheSnapshot?['serviceNom'] ?? 'Intervention',
                              style: TextStyle(
                                fontSize: height < 30 ? 7 : (height < 45 ? 9 : 11),
                                fontWeight: FontWeight.w900,
                                color: _getStatusColor(interv.statut),
                                height: 1.1,
                              ),
                              maxLines: height < 40 ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (height > 45) ...[
                              const SizedBox(height: 2),
                              Text(
                                interv.clientSnapshot?['nom'] ?? '',
                                style: TextStyle(
                                  fontSize: 8, 
                                  color: _getStatusColor(interv.statut).withOpacity(0.8), 
                                  fontWeight: FontWeight.bold
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
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

  Widget _buildMonthGrid(List<InterventionModel> interventions) {
    final start = _startOfVisibleMonth;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Month days header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: List.generate(7, (index) => Expanded(
                child: Center(
                  child: Text(
                    _weekDaysShort[index],
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)),
                  ),
                ),
              )),
            ),
          ),
          // Month grid
          ...List.generate(6, (weekIndex) {
            return Container(
              height: (MediaQuery.of(context).size.width - 32) / 7,
              decoration: BoxDecoration(
                border: Border(bottom: weekIndex < 5 ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none),
              ),
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final dayDate = start.add(Duration(days: weekIndex * 7 + dayIndex));
                  final isCurrentMonth = dayDate.month == _gridDate.month;
                  final isToday = dayDate.day == DateTime.now().day && dayDate.month == DateTime.now().month && dayDate.year == DateTime.now().year;
                  
                  final dayInterventions = interventions.where((i) {
                    final d = i.dateDebutIntervention ?? i.dateFinIntervention ?? i.createdAt;
                    return d != null && d.year == dayDate.year && d.month == dayDate.month && d.day == dayDate.day;
                  }).toList();

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _gridDate = dayDate;
                          _viewMode = AgendaViewMode.day;
                          _subscribeToStream();
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
                          border: Border(left: dayIndex > 0 ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                "${dayDate.day}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isToday ? FontWeight.w900 : (isCurrentMonth ? FontWeight.bold : FontWeight.normal),
                                  color: isToday ? AppColors.primary : (isCurrentMonth ? const Color(0xFF1E293B) : Colors.grey[300]),
                                ),
                              ),
                            ),
                            if (dayInterventions.isNotEmpty)
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                    ),
                                    if (dayInterventions.length > 1) ...[
                                      const SizedBox(width: 2),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.5), shape: BoxShape.circle),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
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
              "All interventions of the month",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            _badge("${interventions.length}", AppColors.primary),
          ],
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text("No interventions this month", style: TextStyle(color: Colors.grey, fontSize: 13))),
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
                  _buildClientAvatar(interv.clientSnapshot?['photo'] ?? '', interv.clientSnapshot?['nom'] ?? 'Client'),
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
                          "${DateFormat('dd/MM HH:mm', 'en_US').format(interv.dateDebutIntervention ?? interv.dateFinIntervention ?? interv.createdAt ?? DateTime.now())} • ${interv.clientSnapshot?['nom'] ?? 'Client'}",
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
      case 'ACCEPTEE': return AppColors.primary;
      case 'TERMINEE': return const Color(0xFF10B981);
      case 'EN_ATTENTE': return const Color(0xFFF5C518);
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
              const Text("Intervention Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              _detailRow("Date", DateFormat('dd MMMM yyyy', 'en_US').format(interv.dateDebutIntervention ?? interv.dateFinIntervention ?? interv.createdAt ?? DateTime.now())),
              _detailRow("Schedule", "${DateFormat('HH:mm').format(interv.dateDebutIntervention ?? interv.dateFinIntervention ?? interv.createdAt ?? DateTime.now())} - ${DateFormat('HH:mm').format(interv.dateFinIntervention ?? (interv.dateDebutIntervention?.add(const Duration(hours: 1)) ?? (interv.createdAt?.add(const Duration(hours: 1)) ?? DateTime.now().add(const Duration(hours: 1)))))}"),
              _detailRow("Price", "${interv.prixNegocie} DH"),
              _detailRow("Status", interv.statut),
              const SizedBox(height: 8),
              Text("Document ID: ${interv.id}", style: const TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              const Text("CLIENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _clientCard(interv.clientSnapshot),
              const SizedBox(height: 20),
              const Text("ADDRESS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _locationCard(interv.adresseSnapshot),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
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
          _buildClientAvatar(client?['photo'] ?? '', client?['nom'] ?? 'Client', size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client?['nom'] ?? 'Unknown client', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(client?['telephone'] ?? 'No phone number', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  Widget _buildClientAvatar(String photo, String name, {double size = 40}) {
    final initials = name.isNotEmpty ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
        image: photo.isNotEmpty && photo.startsWith('http')
            ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: photo.isEmpty || !photo.startsWith('http')
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}
