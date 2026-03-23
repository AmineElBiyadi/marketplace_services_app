import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../services/admin_dashboard_service.dart';
import '../../theme/app_colors.dart';

class BookingDetailDialog extends StatefulWidget {
  final String bookingId;
  const BookingDetailDialog({super.key, required this.bookingId});

  @override
  State<BookingDetailDialog> createState() => _BookingDetailDialogState();
}

class _BookingDetailDialogState extends State<BookingDetailDialog> {
  final AdminDashboardService _service = AdminDashboardService();
  bool _loading = true;
  Map<String, dynamic>? _booking;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final result = await _service.getReservationById(widget.bookingId);
      if (mounted) setState(() { _booking = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1024;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: isMobile ? screenWidth * 0.9 : 800,
        height: isMobile ? MediaQuery.of(context).size.height * 0.8 : 600,
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(isMobile),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : (_booking == null ? const Center(child: Text('Réservation introuvable')) : _buildContent(isMobile)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32, vertical: 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.calendarDays, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Détails de Réservation', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text(
                  '#${widget.bookingId.substring(0, 8).toUpperCase()}', 
                  style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (_booking != null) _buildStatusBadge(_booking!['status'] ?? 'N/A'),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildProfilesCard(),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildInfoCard()),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildProfilesCard()),
        ],
      ),
    );
  }

  Widget _cardWrapper({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: AppColors.primary)),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return _cardWrapper(
      title: 'Informations Générales',
      icon: LucideIcons.info,
      child: Column(
        children: [
          _modernInfoRow('Service', _booking!['service'] ?? 'N/A', LucideIcons.briefcase),
          _modernInfoRow('Date & Heure', '${_booking!['date'] ?? 'N/A'} à ${_booking!['time'] ?? '--:--'}', LucideIcons.clock),
          _modernInfoRow('Prix de la prestation', '${_booking!['amount'] ?? 0} DH', LucideIcons.creditCard, isBold: true, valueColor: Colors.green, isLarge: true),
          _modernInfoRow('Urgence', (_booking!['isUrgent'] ?? false) ? 'URGENTE' : 'NORMALE', LucideIcons.alertCircle, valueColor: (_booking!['isUrgent'] ?? false) ? Colors.red : Colors.grey),
          if ((_booking!['status'] == 'ANNULEE' || _booking!['status'] == 'REFUSEE') && 
              (_booking!['motifAnnulation'] != null || _booking!['motifRefus'] != null))
            _modernInfoRow(
              'Motif', 
              _booking!['motifAnnulation'] ?? _booking!['motifRefus'] ?? 'N/A', 
              LucideIcons.fileWarning,
              valueColor: Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _modernInfoRow(String label, String value, IconData icon, {bool isBold = false, Color? valueColor, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const Spacer(),
          Text(
            value, 
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500, 
              color: valueColor ?? const Color(0xFF0F172A), 
              fontSize: isLarge ? 16 : 14,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesCard() {
    return _cardWrapper(
      title: 'Intervenants',
      icon: LucideIcons.users,
      child: Column(
        children: [
          _modernProfileItem('Client', _booking!['clientName'] ?? 'N/A', _booking!['idClient'], LucideIcons.user),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
          _modernProfileItem('Prestataire', _booking!['expertName'] ?? 'N/A', _booking!['idExpert'], LucideIcons.briefcase),
        ],
      ),
    );
  }

  Widget _modernProfileItem(String role, String name, String? id, IconData icon) {
    return InkWell(
      onTap: id != null ? () => _showUserProfileModal(id, role == 'Client' ? 'Client' : 'Prestataire') : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), shape: BoxShape.circle),
              child: const Icon(LucideIcons.chevronRight, size: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserProfileModal(String id, String role) {
    showDialog(
      context: context,
      builder: (context) => UserProfileDetailDialog(id: id, role: role),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'ACCEPTEE') color = Colors.green;
    else if (status == 'TERMINEE') color = Colors.blue;
    else if (status == 'EN_ATTENTE') color = Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class UserProfileDetailDialog extends StatefulWidget {
  final String id;
  final String role;
  const UserProfileDetailDialog({super.key, required this.id, required this.role});

  @override
  State<UserProfileDetailDialog> createState() => _UserProfileDetailDialogState();
}

class _UserProfileDetailDialogState extends State<UserProfileDetailDialog> {
  final AdminDashboardService _service = AdminDashboardService();
  bool _loading = true;
  Map<String, dynamic>? _user;

  // Theme Constants matching the Admin Dashboard
  static const Color _primary = Color(0xFF0F172A);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    final data = await _service.getUserProfile(widget.id, widget.role);
    if (mounted) setState(() { _user = data; _loading = false; });
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    await _service.updateUserStatus(widget.id, widget.role, status);
    await _loadUser();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut à jour. Email automatique envoyé à ${_user!['email']}'),
          backgroundColor: Colors.green,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: _loading 
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : _user == null 
            ? const Center(child: Text('Profil non trouvé'))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildResilientAvatar(
                          _user!['imageUrl']?.toString(),
                          _user!['name']?.toString() ?? 'U',
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_user!['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primary)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(widget.role, style: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 8),
                                  _statusBadge(_user!['status'] ?? ''),
                                ],
                              )
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 24),
                    
                    const Text('Informations Générales', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 0.5)),
                    const SizedBox(height: 16),
                    _modernInfoTile(LucideIcons.mail, 'E-mail', _user!['email']),
                    _modernInfoTile(LucideIcons.phone, 'Téléphone', _user!['phone']),
                    if (_user!['region'] != null) _modernInfoTile(LucideIcons.mapPin, 'Région', _user!['region']),
                    
                    if (widget.role == 'Expert' || widget.role == 'Prestataire') ...[
                      const SizedBox(height: 24),
                      const Text('Profil Professionnel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 0.5)),
                      const SizedBox(height: 16),
                      _docTile(LucideIcons.contact, 'Carte Nationale', _user!['CarteNationale']?.toString() ?? 'Non fourni'),
                      _docTile(LucideIcons.fileText, 'Casier Judiciaire', _user!['CasierJudiciaire']?.toString() ?? 'Non fourni'),
                      _modernInfoTile(LucideIcons.briefcase, 'Expérience', _user!['Experience']?.toString() ?? 'Non précisée'),
                      if (_user!['services'] != null && (_user!['services'] as List).isNotEmpty)
                        _modernInfoTile(LucideIcons.settings, 'Services', (_user!['services'] as List).join(", ")),
                    ],
                    
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 24),

                    const Text('Actions Administratives', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 0.5)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _user!['email'].isNotEmpty ? _showEmailComposer : null,
                        icon: const Icon(LucideIcons.mail, size: 16),
                        label: const Text('Composer un e-mail personnalisé'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _modernActionBtn('Activer', Colors.green, LucideIcons.checkCircle, () => _updateStatus('ACTIVE'), isActive: _user!['status'] == 'ACTIVE')),
                        const SizedBox(width: 8),
                        Expanded(child: _modernActionBtn('Suspendre', Colors.orange, LucideIcons.alertTriangle, () => _updateStatus('SUSPENDUE'), isActive: _user!['status'] == 'SUSPENDUE')),
                        const SizedBox(width: 8),
                        Expanded(child: _modernActionBtn('Désactiver', Colors.red, LucideIcons.xCircle, () => _updateStatus('DESACTIVE'), isActive: _user!['status'] == 'DESACTIVE')),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showEmailComposer() {
    final subjectController = TextEditingController(text: 'Concernant votre compte Marketplace');
    final bodyController = TextEditingController();
    bool sending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouvel E-mail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 24),
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Sujet',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bodyController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                      child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: sending ? null : () async {
                        if (bodyController.text.isEmpty) return;
                        setLocalState(() => sending = true);
                        await _service.sendAutomaticEmail(
                          to: _user!['email'],
                          subject: subjectController.text,
                          html: "<div style='font-family: sans-serif; color: #333;'><p>${bodyController.text.replaceAll('\n', '<br>')}</p><br><p>Cordialement,<br><strong>L'équipe Marketplace</strong></p></div>",
                        );
                        if (context.mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-mail envoyé avec succès !'), backgroundColor: Colors.green));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: sending 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modernInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: _textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, color: _primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docTile(IconData icon, String label, String value) {
    final strValue = value.toString();
    final isLong = strValue.length > 50;
    final isUrl = strValue.startsWith('http');
    final displayValue = (isLong || isUrl) ? "Document fourni" : strValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: _textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(displayValue, style: const TextStyle(fontSize: 14, color: _primary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isLong || isUrl)
            TextButton.icon(
              onPressed: () => _showFullDocument(label, strValue),
              icon: const Icon(LucideIcons.externalLink, size: 14),
              label: const Text('Ouvrir', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
        ],
      ),
    );
  }

  void _showFullDocument(String label, String value) {
    final bool isPdf = value.toLowerCase().endsWith('.pdf');
    final bool isUrl = value.startsWith('http');

    if (isPdf && isUrl) {
      // Pour les PDFs, on ouvre dans le navigateur
      _launchExternalUrl(value);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: value.startsWith('data:image') 
              ? Image.memory(base64Decode(value.split(',').last))
              : isUrl 
                ? Image.network(
                    value,
                    errorBuilder: (context, error, stackTrace) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.fileWarning, size: 48, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text("L'aperçu est bloqué par la sécurité du navigateur (CORS) ou le fichier n'est pas une image.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _launchExternalUrl(value),
                          icon: const Icon(LucideIcons.externalLink, size: 14),
                          label: const Text("Ouvrir dans un nouvel onglet"),
                        ),
                      ],
                    ),
                  )
                : Text(value),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildResilientAvatar(String? url, String name) {
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: _primary.withOpacity(0.1),
        child: Text(name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.characters.take(1).toString().toUpperCase(), 
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primary)),
      );
    }

    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return CircleAvatar(radius: 40, backgroundImage: MemoryImage(bytes));
      } catch (e) {
        return CircleAvatar(radius: 40, child: Icon(LucideIcons.user));
      }
    }

    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          url,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Text(
            name.characters.take(1).toString().toUpperCase(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primary),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
        ),
      ),
    );
  }

  Widget _modernActionBtn(String label, Color color, IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return ElevatedButton.icon(
      onPressed: isActive ? null : onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _textSecondary,
        disabledBackgroundColor: color.withOpacity(0.1),
        disabledForegroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isActive ? color : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green; label = 'Actif'; break;
      case 'SUSPENDUE':
        color = Colors.orange; label = 'Suspendu'; break;
      case 'DESACTIVE':
        color = Colors.red; label = 'Désactivé'; break;
      default:
        color = Colors.grey; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
