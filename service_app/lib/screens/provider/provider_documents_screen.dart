import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/firestore_service.dart';
import '../../models/expert.dart';
import '../../theme/app_colors.dart';

class ProviderDocumentsScreen extends StatefulWidget {
  final String expertId;

  const ProviderDocumentsScreen({super.key, required this.expertId});

  @override
  State<ProviderDocumentsScreen> createState() => _ProviderDocumentsScreenState();
}

class _ProviderDocumentsScreenState extends State<ProviderDocumentsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  ExpertModel? _expertModel;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final model = await _firestoreService.getExpertProfile(widget.expertId);
      if (mounted) {
        setState(() {
          _expertModel = model;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des documents : $e')),
        );
      }
    }
  }

  void _showImageDialog(BuildContext context, String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      height: 300,
                      color: Colors.white,
                      child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 300,
                      color: Colors.white,
                      child: const Center(child: Icon(LucideIcons.imageOff, size: 50, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentCard(String title, String? imageUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.fileImage, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showImageDialog(context, title, imageUrl),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.imageOff, size: 40, color: Color(0xFF94A3B8)),
                          SizedBox(height: 8),
                          Text("Image non disponible", style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 100,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const Center(
                child: Text(
                  "Aucun document fourni",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Mes Documents",
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Documents professionnels",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Retrouvez ici les documents que vous avez soumis lors de votre inscription.",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildDocumentCard(
                    "Carte Nationale d'Identité (Recto)",
                    _expertModel?.carteNationale,
                  ),
                  _buildDocumentCard(
                    "Carte Nationale d'Identité (Verso)",
                    _expertModel?.carteNationaleVerso,
                  ),
                  _buildDocumentCard(
                    "Certificat / Diplôme",
                    _expertModel?.certificatDocs,
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
