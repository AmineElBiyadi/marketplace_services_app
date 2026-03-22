import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const EditProfileScreen({super.key, required this.clientData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  String? _imageBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clientData['nom']);
    _phoneController = TextEditingController(text: widget.clientData['telephone']);
    _imageBase64 = widget.clientData['image_profile'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 30,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 700000) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image file is too large (max ~700 KB).')),
            );
          }
          return;
        }
        setState(() {
          _imageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _firestoreService.updateClientProfile(
          uid: user.uid,
          name: name,
          phone: phone,
          imageBase64: _imageBase64,
        );
        if (mounted) {
          context.pop(true); // Return true to indicate successful update
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFFCF9F2);
    const primaryBlue = Color(0xFF2A4278);

    ImageProvider? imageProvider;
    if (_imageBase64 != null && _imageBase64!.isNotEmpty) {
      if (_imageBase64!.startsWith('http://') || _imageBase64!.startsWith('https://')) {
        imageProvider = NetworkImage(_imageBase64!);
      } else {
        try {
          final Uint8List bytes = base64Decode(_imageBase64!);
          imageProvider = MemoryImage(bytes);
        } catch (e) {
          // Fallback handled below
        }
      }
    }

    final String initial = _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFFDCDFEA),
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? Text(initial, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: primaryBlue))
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: primaryBlue, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: primaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: const TextStyle(color: primaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
