import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../services/admin_dashboard_service.dart';
import '../../theme/app_colors.dart';

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
