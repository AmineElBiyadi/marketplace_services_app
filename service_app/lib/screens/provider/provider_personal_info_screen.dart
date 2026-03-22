import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';
import '../../models/expert.dart';

class ProviderPersonalInfoScreen extends StatefulWidget {
  final String expertId;

  const ProviderPersonalInfoScreen({super.key, required this.expertId});

  @override
  State<ProviderPersonalInfoScreen> createState() => _ProviderPersonalInfoScreenState();
}

class _ProviderPersonalInfoScreenState extends State<ProviderPersonalInfoScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  bool _isSaving = false;
  Expert? _expertData;
  ExpertModel? _expertModel;

  final TextEditingController _prenomCtrl = TextEditingController();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _villeCtrl = TextEditingController();
  final TextEditingController _adresseCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  
  double _rayon = 20.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final expertModel = await _firestoreService.getExpertProfile(widget.expertId);
      final expertDetailed = await _firestoreService.getExpertDetailed(widget.expertId);

      if (mounted) {
        setState(() {
          _expertModel = expertModel;
          _expertData = expertDetailed;

          // Hydrate fields
          final splitNom = (_expertData?.nom ?? _expertModel?.user?.nom ?? 'Expert').split(' ');
          _prenomCtrl.text = splitNom.isNotEmpty ? splitNom[0] : '';
          _nomCtrl.text = splitNom.length > 1 ? splitNom[1] : '';

          _phoneCtrl.text = _expertData?.telephone ?? '';
          _emailCtrl.text = _expertModel?.user?.email ?? '';
          
          _villeCtrl.text = _expertData?.ville.split(',').first ?? 'Casablanca';
          _adresseCtrl.text = _expertData?.ville ?? '';
          
          _categoryCtrl.text = (_expertData?.services.isNotEmpty == true) 
              ? _expertData!.services.first 
              : "Plumbing";
          
          _rayon = (_expertModel?.rayonTravaille ?? 20).toDouble();
          _bioCtrl.text = _expertModel?.experience ?? "Professional expert with years of experience.";

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveChanges() async {
    if (_expertData == null || _expertModel == null) return;
    
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateExpertProfileInfo(
        widget.expertId,
        _expertModel!.idUtilisateur,
        prenom: _prenomCtrl.text,
        nom: _nomCtrl.text,
        telephone: _phoneCtrl.text,
        email: _emailCtrl.text,
        ville: _villeCtrl.text,
        adresse: _adresseCtrl.text,
        rayonTravaille: _rayon,
        experience: _bioCtrl.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Changes saved successfully!"), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error while saving : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderLayout(
      activeRoute: '/provider/profile',
      expertId: widget.expertId,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            "Personal Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          centerTitle: false,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTextField("First Name", LucideIcons.user, _prenomCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("Last Name", null, _nomCtrl, isLabeled: true)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField("Phone", LucideIcons.phone, _phoneCtrl),
                    const SizedBox(height: 20),
                    _buildTextField("Email", LucideIcons.mail, _emailCtrl),
                    const SizedBox(height: 20),
                    _buildDropdownField("City", LucideIcons.mapPin, _villeCtrl),
                    const SizedBox(height: 20),
                    _buildTextField("Address", LucideIcons.mapPin, _adresseCtrl),
                    const SizedBox(height: 20),
                    _buildDropdownField("Service Category", LucideIcons.briefcase, _categoryCtrl),
                    const SizedBox(height: 24),
                    _buildRayonSlider(),
                    const SizedBox(height: 24),
                    _buildTextField("Bio / Description", LucideIcons.fileText, _bioCtrl, maxLines: 3),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData? icon, TextEditingController controller, {bool isLabeled = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, IconData icon, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: controller.text.isNotEmpty ? controller.text : null,
              icon: const Icon(LucideIcons.chevronDown, color: Color(0xFF64748B), size: 18),
              items: [controller.text].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRayonSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.search, size: 16, color: Color(0xFF64748B)), // Or any radius icon
            const SizedBox(width: 8),
            const Text(
              "Working radius",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Maximum distance", style: TextStyle(color: Color(0xFF64748B))),
                  Text(
                    "${_rayon.toInt()} km",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                ),
                child: Slider(
                  value: _rayon,
                  min: 5,
                  max: 100,
                  onChanged: (val) {
                    setState(() {
                      _rayon = val;
                    });
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("5 km", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  Text("100 km", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
