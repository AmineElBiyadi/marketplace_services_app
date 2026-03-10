import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';


const List<String> _categories = [
  "Plomberie",
  "Électricité",
  "Ménage",
  "Jardinage",
  "Coiffure",
  "Informatique",
  "Peinture",
  "Climatisation",
];

class ProviderSignupScreen extends StatefulWidget {
  const ProviderSignupScreen({super.key});

  @override
  State<ProviderSignupScreen> createState() => _ProviderSignupScreenState();
}

class _ProviderSignupScreenState extends State<ProviderSignupScreen> {
  int _step = 1;

  // Step 1
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _agreed = false;
  
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;


  // Step 2
  String _selectedCategory = "";
  final _descriptionController = TextEditingController();
  final _zoneController = TextEditingController();

  // Step 3
  String? _cinFrontName;
  String? _cinFrontBase64;
  String? _cinBackName;
  String? _cinBackBase64;
  String? _certificateName;
  String? _certificateBase64;
  final ImagePicker _picker = ImagePicker();

  bool get _step1Valid {
    final hasContact = _phoneController.text.isNotEmpty || _emailController.text.isNotEmpty;
    return _nameController.text.isNotEmpty &&
        hasContact &&
        _passwordController.text.isNotEmpty &&
        _passwordController.text == _confirmController.text &&
        _agreed;
  }

  bool get _step2Valid =>
      _selectedCategory.isNotEmpty &&
      _descriptionController.text.isNotEmpty &&
      _zoneController.text.isNotEmpty;

  bool get _step3Valid =>
      _cinFrontBase64 != null && _cinBackBase64 != null && _certificateBase64 != null;

  Future<void> _pickImage(Function(String, String) setter) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 30, // Aggressive compression (1MB limit in Firestore)
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        setter(image.name, base64String);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument(Function(String, String) setter) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        
        // Check size (Firestore limit is 1MB total per document, so warn if > 700KB)
        if (bytes.length > 700000) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                content: Text("Fichier trop volumineux. La taille maximale est de ~700 Ko."),
                backgroundColor: AppColors.destructive,
              ),
            );
          }
          return;
        }

        final base64String = base64Encode(bytes);
        setter(result.files.single.name, base64String);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick document: $e')),
        );
      }
    }
  }

  void _handleSignup(String planType) async {
    // Only proceed if steps 1-3 are valid
    if (!_step1Valid || !_step2Valid || !_step3Valid) return;

    setState(() => _isLoading = true);

    try {
      final hasPhone = _phoneController.text.trim().isNotEmpty;
      final hasEmail = _emailController.text.trim().isNotEmpty;
      final usePhone = hasPhone;

      // --- Pre-validation Check ---
      String phoneToCheck = _phoneController.text.trim();
      if (hasPhone) {
        if (!phoneToCheck.startsWith('+')) {
          if (phoneToCheck.startsWith('0')) {
            phoneToCheck = '+212${phoneToCheck.substring(1)}';
          } else {
            phoneToCheck = '+$phoneToCheck';
          }
        }
      }

      final duplicateField = await _firestoreService.checkUserExists(
        phone: phoneToCheck,
        email: _emailController.text.trim(),
      );

      if (duplicateField != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          final msg = duplicateField == 'phone'
              ? 'Ce numéro de téléphone est déjà utilisé.'
              : 'Cet email est déjà utilisé.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
        return;
      }
      // ----------------------------

      if (usePhone) {
        await _authService.verifyPhoneNumber(
          phoneNumber: phoneToCheck,
          onVerificationCompleted: (credential) {
            if (mounted) setState(() => _isLoading = false);
          },
          onVerificationFailed: (Exception e) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: ${e.toString()}')),
              );
            }
          },
          onCodeSent: (String verificationId, int? resendToken) {
            if (mounted) {
              setState(() => _isLoading = false);
              context.push('/otp', extra: {
                'method': 'phone',
                'verificationId': verificationId,
                'name': _nameController.text.trim(),
                'phone': _phoneController.text.trim(),
                'email': _emailController.text.trim(),
                'password': _passwordController.text,
                'category': _selectedCategory,
                'description': _descriptionController.text.trim(),
                'zone': _zoneController.text.trim(),
                'cinFront': _cinFrontBase64,
                'cinBack': _cinBackBase64,
                'certificate': _certificateBase64,
                'plan': planType,
                'role': 'provider',
              });
            }
          },
          onCodeAutoRetrievalTimeout: (String verificationId) {
            if (mounted) setState(() => _isLoading = false);
          },
        );
      } else if (hasEmail) {
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        setState(() => _isLoading = false);
        if (mounted) {
          context.push('/otp', extra: {
            'method': 'email',
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'category': _selectedCategory,
            'description': _descriptionController.text.trim(),
            'zone': _zoneController.text.trim(),
            'cinFront': _cinFrontBase64,
            'cinBack': _cinBackBase64,
            'certificate': _certificateBase64,
            'plan': planType,
            'role': 'provider',
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur inattendue: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressWidth = (_step / 4) * 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_step > 1) {
                        setState(() => _step--);
                      } else {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.pushReplacement('/provider/login');
                        }
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.textPrimary,
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressWidth / 100,
                        backgroundColor: AppColors.divider,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "$_step/4",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Step Content
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
              if (_step == 3) _buildStep3(),
              if (_step == 4) _buildStep4(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.construction,
              size: 48,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Informations personnelles",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Créez votre compte prestataire",
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        CustomTextField(
          hint: "Nom complet",
          controller: _nameController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          hint: "Téléphone",
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          hint: "Email",
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          hint: "Mot de passe",
          controller: _passwordController,
          obscureText: !_showPassword,
          suffix: IconButton(
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(
              _showPassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textSecondary,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          hint: "Confirmer le mot de passe",
          controller: _confirmController,
          obscureText: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              activeColor: AppColors.primary,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "J'accepte les ",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CustomButton(
          text: "Continuer",
          onPressed: _step1Valid ? () => setState(() => _step = 2) : null,
          disabled: !_step1Valid,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Informations professionnelles",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Décrivez votre activité",
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Catégorie de métier",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: isSelected
                    ? AppColors.primary
                    : AppColors.cardBackground,
                child: Text(
                  cat,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.buttonText
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          "Description",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: "Décrivez votre expérience et vos spécialités...",
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          "Zone d'intervention",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          hint: "Ex: Casablanca, Rabat...",
          controller: _zoneController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          height: 120,
          child: Center(
            child: Text(
              "Carte interactive (bientôt disponible)",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: "Continuer",
          onPressed: _step2Valid ? () => setState(() => _step = 3) : null,
          disabled: !_step2Valid,
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Documents justificatifs",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Téléchargez vos pièces pour vérification",
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _buildUploadCard(
          "CIN - Recto",
          _cinFrontName,
          () => _pickImage((name, base64) {
            _cinFrontName = name;
            _cinFrontBase64 = base64;
          }),
          Icons.camera_alt,
        ),
        const SizedBox(height: 16),
        _buildUploadCard(
          "CIN - Verso",
          _cinBackName,
          () => _pickImage((name, base64) {
            _cinBackName = name;
            _cinBackBase64 = base64;
          }),
          Icons.camera_alt,
        ),
        const SizedBox(height: 16),
        _buildUploadCard(
          "Certificat de bonne conduite",
          _certificateName,
          () => _pickDocument((name, base64) {
            _certificateName = name;
            _certificateBase64 = base64;
          }),
          Icons.upload_file,
        ),
        const SizedBox(height: 16),
        GlassContainer(
          backgroundColor: AppColors.primary.withValues(alpha: 0.2), // Changed accent to primary
          borderColor: AppColors.primary.withValues(alpha: 0.3), // Changed accent to primary
          child: Row(
            children: [
              const Text("⏳", style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Vos documents seront vérifiés par notre équipe sous 24-48h.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: "Continuer",
          onPressed: _step3Valid ? () => setState(() => _step = 4) : null,
          disabled: !_step3Valid,
        ),
      ],
    );
  }

  Widget _buildUploadCard(
    String label,
    String? value,
    VoidCallback onTap,
    IconData icon,
  ) {
    final isUploaded = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: GlassContainer(
            height: 100,
            borderColor: isUploaded
                ? AppColors.primary
                : AppColors.divider,
            borderWidth: 2,
            borderStyle: BorderStyle.solid,
            backgroundColor: isUploaded
                ? AppColors.primary.withValues(alpha: 0.05)
                : AppColors.cardBackground,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isUploaded
                  ? [
                      Icon(
                        Icons.check_circle,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ]
                  : [
                      Icon(
                        icon,
                        size: 32,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Appuyez pour télécharger",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choisissez votre pack",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Commencez gratuitement ou boostez votre visibilité",
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Free Pack
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Basique",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "0 DH",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    "/mois",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFeatureItem("Max 5 services", true),
              _buildFeatureItem("Commission 10%", true),
              _buildFeatureItem("Badge \"Basique\"", true),
              const SizedBox(height: 16),
              CustomButton(
                text: _isLoading ? "Chargement..." : "Commencer avec Gratuit",
                isOutlined: true,
                onPressed: _isLoading ? null : () => _handleSignup('basique'),
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Premium Pack
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary, width: 2), // Changed accent to primary as accent isn't defined
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2), // changed accent to primary
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "Premium ⭐",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary, // changed accent to primary
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "99 DH",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "/mois",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeatureItem("Services illimités", true, isPremium: true),
                _buildFeatureItem(
                    "Commission 3% seulement", true, isPremium: true),
                _buildFeatureItem("Profil boosté", true, isPremium: true),
                _buildFeatureItem(
                    "Statistiques avancées", true, isPremium: true),
                _buildFeatureItem(
                    "Badge \"Premium ⭐\"", true, isPremium: true),
                const SizedBox(height: 16),
                CustomButton(
                  text: _isLoading ? "Chargement..." : "Passer Premium",
                  backgroundColor: AppColors.primary, // Changed accent to primary
                  textColor: Colors.white, // Changed primary to white for contrast
                  onPressed: _isLoading ? null : () => _handleSignup('premium'),
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text, bool included, {bool isPremium = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check,
            size: 16,
            color: isPremium ? AppColors.primary : AppColors.primary, // Changed accent to primary
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isPremium ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
