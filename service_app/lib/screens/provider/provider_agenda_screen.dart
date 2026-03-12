import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';

class Booking {
  final int id;
  final int day; // 0-6
  final int startHour;
  final int endHour;
  final String client;
  final String service;

  Booking({
    required this.id,
    required this.day,
    required this.startHour,
    required this.endHour,
    required this.client,
    required this.service,
  });

  Booking copyWith({
    int? day,
    int? startHour,
    int? endHour,
    String? client,
    String? service,
  }) {
    return Booking(
      id: id,
      day: day ?? this.day,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      client: client ?? this.client,
      service: service ?? this.service,
    );
  }
}

class ProviderAgendaScreen extends StatefulWidget {
  final String expertId;
  const ProviderAgendaScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderAgendaScreen> createState() => _ProviderAgendaScreenState();
}

class _ProviderAgendaScreenState extends State<ProviderAgendaScreen> {
  final List<String> _weekDaysShort = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"];
  final List<int> _hours = List.generate(12, (i) => i + 7); // 7h - 18h

  List<Booking> _bookings = [
    Booking(id: 1, day: 0, startHour: 9, endHour: 11, client: "Amina B.", service: "Plomberie"),
    Booking(id: 2, day: 1, startHour: 14, endHour: 16, client: "Omar H.", service: "Ménage"),
    Booking(id: 3, day: 3, startHour: 10, endHour: 12, client: "Sara M.", service: "Jardinage"),
    Booking(id: 4, day: 4, startHour: 8, endHour: 9, client: "Karim L.", service: "Réparation"),
  ];

  void _openAdd() {
    _showAddEditDialog();
  }

  void _openEdit(Booking b) {
    _showAddEditDialog(booking: b);
  }

  void _handleDelete(int id) {
    setState(() {
      _bookings.removeWhere((element) => element.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProviderLayout(
      activeRoute: '/provider/agenda',
      expertId: widget.expertId,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  const Text(
                    "Semaine du 8 au 14 Mars 2026",
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarGrid(),
                  const SizedBox(height: 24),
                  _buildUpcomingList(),
                ],
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Mon Agenda",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          ElevatedButton.icon(
            onPressed: _openAdd,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text("Ajouter"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Week header
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                const SizedBox(width: 44),
                ..._weekDaysShort.map((d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ),
                )),
              ],
            ),
          ),
          // Time slots
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
              // Bookings overlay
              ..._bookings.map((booking) {
                final double top = (booking.startHour - 7) * 60.0;
                final double height = (booking.endHour - booking.startHour) * 60.0 - 4;
                final double widthFactor = 1 / 7;

                return Positioned(
                  top: top + 2,
                  left: 44 + (booking.day * (MediaQuery.of(context).size.width - 76) / 7),
                  width: (MediaQuery.of(context).size.width - 76) / 7 - 4,
                  height: height,
                  child: GestureDetector(
                    onTap: () => _openEdit(booking),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.service,
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            booking.client,
                            style: TextStyle(fontSize: 7, color: AppColors.primary.withOpacity(0.7)),
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

  Widget _buildUpcomingList() {
    final sortedBookings = List<Booking>.from(_bookings)
      ..sort((a, b) => a.day.compareTo(b.day) != 0 ? a.day.compareTo(b.day) : a.startHour.compareTo(b.startHour));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Événements cette semaine",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        if (sortedBookings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text("Aucun événement cette semaine", style: TextStyle(color: Colors.grey, fontSize: 13))),
          )
        else
          ...sortedBookings.map((b) => GestureDetector(
            onTap: () => _openEdit(b),
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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.clock, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.service,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${_weekDaysShort[b.day]} • ${b.startHour}:00 - ${b.endHour}:00 ${b.client.isNotEmpty ? '• ${b.client}' : ''}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _handleDelete(b.id),
                    icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  void _showAddEditDialog({Booking? booking}) {
    final bool isEdit = booking != null;
    final idController = TextEditingController(text: isEdit ? booking.id.toString() : "");
    final serviceController = TextEditingController(text: isEdit ? booking.service : "");
    final clientController = TextEditingController(text: isEdit ? booking.client : "");
    int selectedDay = isEdit ? booking.day : 0;
    int selectedStart = isEdit ? booking.startHour : 8;
    int selectedEnd = isEdit ? booking.endHour : 10;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isEdit ? "Modifier l'événement" : "Ajouter un événement",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Service / Titre"),
                    TextField(
                      controller: serviceController,
                      decoration: _inputDecoration("Ex: Plomberie"),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel("Client (optionnel)"),
                    TextField(
                      controller: clientController,
                      decoration: _inputDecoration("Ex: Amina B."),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel("Jour"),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(7, (index) => GestureDetector(
                        onTap: () => setDialogState(() => selectedDay = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedDay == index ? AppColors.primary : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selectedDay == index ? AppColors.primary : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            _weekDaysShort[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: selectedDay == index ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Début"),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: selectedStart,
                                    isExpanded: true,
                                    items: _hours.map((h) => DropdownMenuItem(value: h, child: Text("$h:00"))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          selectedStart = val;
                                          if (selectedEnd <= selectedStart) selectedEnd = selectedStart + 1;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Fin"),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: selectedEnd,
                                    isExpanded: true,
                                    items: _hours.where((h) => h > selectedStart).map((h) => DropdownMenuItem(value: h, child: Text("$h:00"))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => selectedEnd = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (isEdit) ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _handleDelete(booking.id);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                foregroundColor: Colors.red,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.trash2, size: 16),
                                  SizedBox(width: 4),
                                  Text("Supprimer", style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (serviceController.text.trim().isEmpty) return;
                              setState(() {
                                if (isEdit) {
                                  final index = _bookings.indexWhere((element) => element.id == booking.id);
                                  _bookings[index] = booking.copyWith(
                                    service: serviceController.text,
                                    client: clientController.text,
                                    day: selectedDay,
                                    startHour: selectedStart,
                                    endHour: selectedEnd,
                                  );
                                } else {
                                  _bookings.add(Booking(
                                    id: DateTime.now().millisecondsSinceEpoch,
                                    service: serviceController.text,
                                    client: clientController.text,
                                    day: selectedDay,
                                    startHour: selectedStart,
                                    endHour: selectedEnd,
                                  ));
                                }
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(isEdit ? "Modifier" : "Ajouter", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
