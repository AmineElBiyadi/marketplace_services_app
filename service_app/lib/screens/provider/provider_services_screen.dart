import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/badges.dart';
import '../../widgets/common_widgets.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';
import '../../models/service.dart';
import '../../models/task_model.dart';
import '../../services/cloudinary_service.dart';

// Categories will be loaded from Firestore

class ProviderServicesScreen extends StatefulWidget {
  final String expertId;
  const ProviderServicesScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderServicesScreen> createState() =>
      _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _expertServices = [];
  List<ServiceModel> _categories = [];
  bool _isLoading = true;
  bool _isPremium = false;
  int _freeLimit = 3;
  int _freePortfolioLimit = 3;
  StreamSubscription<bool>? _premiumSub;

  @override
  void initState() {
    super.initState();
    _subscribeToPremuim();
    _loadData();
  }

  void _subscribeToPremuim() {
    _premiumSub = _firestoreService.isExpertPremium(widget.expertId).listen((isPremium) {
      if (mounted) {
        setState(() => _isPremium = isPremium);
        _loadData(); // Trigger reload to get updated isVisibleByPlan status
      }
    });
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // Load free limits from global config
      final dynamicLimit = await _firestoreService.getFreeServiceLimit();
      final dynamicPortfolioLimit = await _firestoreService.getFreePortfolioLimit();
      if (mounted) {
        setState(() {
          _freeLimit = dynamicLimit;
          _freePortfolioLimit = dynamicPortfolioLimit;
        });
      }

      final services = await _firestoreService.getExpertServicesDetailed(widget.expertId);
      final categories = await _firestoreService.getServiceCategories();
      
      if (!mounted) return;
      setState(() {
        _expertServices = services;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading data: $e")),
      );
    }
  }

  Future<void> _toggleService(String id, bool currentStatus) async {
    // If we are deactivating, check for ongoing interventions
    if (currentStatus == true) {
      final hasOngoing = await _firestoreService.hasOngoingInterventionsForService(widget.expertId, id);
      if (hasOngoing) {
        _showBlockedDialog(
          title: "Action Blocked",
          message: "You cannot deactivate this service because you have ongoing bookings associated with it.",
        );
        return;
      }
    }

    try {
      await _firestoreService.toggleServiceExpertsActive(id, !currentStatus);
      _loadData();
    } catch (e) {
      String errorMessage = e.toString().replaceAll("Exception: ", "");
      _showBlockedDialog(
        title: "Action Impossible",
        message: errorMessage,
      );
    }
  }

  void _showBlockedDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with red color
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Center(
                  child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 54),
                ),
              ),
              const SizedBox(height: 24),
              // Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(fontSize: 14, color: Colors.red, height: 1.5, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Action Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Got it!", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteService(String serviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Service"),
        content: const Text("Are you sure you want to delete this service? This action will also delete all linked tasks and images."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Check for ongoing interventions before deleting
      final hasOngoing = await _firestoreService.hasOngoingInterventionsForService(widget.expertId, serviceId);
      if (hasOngoing) {
        _showBlockedDialog(
          title: "Delete Blocked",
          message: "You cannot delete this service because you have ongoing bookings associated with it.",
        );
        return;
      }

      try {
        await _firestoreService.deleteExpertService(widget.expertId, serviceId);
        // After deletion, auto-unlock logic is handled in FirestoreService.deleteExpertService
        // But we already have logic to unlock hidden services there.
        // Photo auto-unlock is triggered if we delete a specific photo, not the whole service.
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service deleted successfully")),
        );
      } catch (e) {
        String errorMessage = e.toString().replaceAll("Exception: ", "");
        _showBlockedDialog(
          title: "Action Impossible",
          message: errorMessage,
        );
      }
    }
  }

  // Form State
  int _currentStep = 1;
  ServiceModel? _selectedCategory;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customSkillController = TextEditingController();
  List<TaskModel> _availableTasks = [];
  final List<TaskModel> _selectedTasks = [];
  final List<String> _customTasks = [];
  final List<Map<String, dynamic>> _imagesWithTasks = [];
  bool _isSaving = false;

  int get _visiblePhotosCount {
    return _imagesWithTasks
        .where((img) => (img['isVisibleByPlan'] ?? true) == true)
        .length;
  }

  Future<void> _pickImage(StateSetter setSheetState) async {
    // Count only visible photos already in the list
    final visiblePhotosCount = _visiblePhotosCount;
    
    // For free users, block adding more photos once we reach the dynamic limit
    if (visiblePhotosCount >= _freePortfolioLimit && !_isPremium) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium, size: 48, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Limit Reached",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Text(
                  "You've reached the limit of $_freePortfolioLimit portfolio photos for free accounts. Upgrade to Premium to upload unlimited photos and attract more clients!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/provider/${widget.expertId}/subscription');
                    },
                    child: const Text("Upgrade Now", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Maybe Later", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (_selectedTasks.isEmpty && _customTasks.isEmpty) {
      _showErrorDialog(
        title: "Skills Required",
        message: "Please add at least one skill before adding photos. This helps clients understand what specific services you offer.",
        icon: Icons.build_circle,
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);

      // Show skill picker dialog
      String? selectedTaskId;
      String? selectedTaskName;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Associate with Skill"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._selectedTasks.map((t) => ListTile(
                  title: Text(t.nom),
                  onTap: () {
                    selectedTaskId = t.id;
                    selectedTaskName = t.nom;
                    Navigator.pop(context);
                  },
                )),
                ..._customTasks.map((t) => ListTile(
                  title: Text(t),
                  onTap: () {
                    selectedTaskId = ''; // Custom tasks don't have IDs yet
                    selectedTaskName = t;
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ),
        ),
      );

      if (selectedTaskName != null) {
        // For free users, all photos within the limit are visible
        // For premium users, all photos are visible
        setSheetState(() {
          _imagesWithTasks.add({
            'image': base64,
            'taskId': selectedTaskId ?? '',
            'taskName': selectedTaskName!,
            'isVisibleByPlan': _isPremium || (visiblePhotosCount < _freePortfolioLimit),
          });
        });
        setState(() {});
      }
    }
  }

  void _showErrorDialog({required String title, required String message, required IconData icon}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with red color
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 54),
                ),
              ),
              const SizedBox(height: 24),
              // Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(fontSize: 14, color: Colors.red, height: 1.5, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Action Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Got it!", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetAddForm() {
    setState(() {
      _currentStep = 1;
      _selectedCategory = null;
      _descriptionController.clear();
      _customSkillController.clear();
      _availableTasks = [];
      _selectedTasks.clear();
      _customTasks.clear();
      _imagesWithTasks.clear();
      _isSaving = false;
    });
  }

  Future<void> _saveService() async {
    if (_selectedCategory == null) {
      _showErrorDialog(
        title: "Missing Information",
        message: "Please select a service category before saving.",
        icon: Icons.category,
      );
      return;
    }
    
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorDialog(
        title: "Description Required",
        message: "Please add a description of your service to help clients understand what you offer.",
        icon: Icons.description,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Upload new images to Cloudinary
      final List<Map<String, dynamic>> finalImagesWithMetadata = [];
      
      for (var imgData in _imagesWithTasks) {
        final imageSource = imgData['image']!;
        
        if (imageSource.startsWith('http')) {
          // Already on Cloudinary
          finalImagesWithMetadata.add(imgData);
        } else {
          // It's Base64, upload it
          final String? url = await CloudinaryService.uploadImage(imageSource);
          if (url != null) {
            final publicId = url.split('/').last.split('.').first;
            finalImagesWithMetadata.add({
              ...imgData,
              'image': url,
              'publicId': publicId,
              'storageType': 'cloudinary',
            });
          } else {
            throw Exception("Failed to upload image to Cloudinary");
          }
        }
      }

      await _firestoreService.addExpertService(
        expertId: widget.expertId,
        serviceId: _selectedCategory!.id!,
        description: _descriptionController.text,
        selectedTasks: _selectedTasks,
        customTasks: _customTasks,
        imagesWithTasks: finalImagesWithMetadata,
      );
      
      Navigator.pop(context);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Service added successfully")),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    }
  }

  Future<void> _saveEditedService(Map<String, dynamic> serviceData) async {
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorDialog(
        title: "Description Required",
        message: "Please add a description of your service to help clients understand what you offer.",
        icon: Icons.description,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Upload new images to Cloudinary
      final List<Map<String, dynamic>> finalImagesWithMetadata = [];
      
      for (var imgData in _imagesWithTasks) {
        final imageSource = imgData['image']!;
        
        if (imageSource.startsWith('http')) {
          finalImagesWithMetadata.add(imgData);
        } else {
          final String? url = await CloudinaryService.uploadImage(imageSource);
          if (url != null) {
            final publicId = url.split('/').last.split('.').first;
            finalImagesWithMetadata.add({
              ...imgData,
              'image': url,
              'publicId': publicId,
              'storageType': 'cloudinary',
            });
          } else {
            throw Exception("Failed to upload image to Cloudinary");
          }
        }
      }

      await _firestoreService.updateExpertService(
        expertId: widget.expertId,
        serviceExpertDocId: serviceData['id'],
        serviceId: serviceData['idService'],
        description: _descriptionController.text,
        selectedTasks: _selectedTasks,
        customTasks: _customTasks,
        imagesWithTasks: finalImagesWithMetadata,
        existingImagesToDelete: [], 
      );
      
      Navigator.pop(context);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Service updated successfully")),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating: $e")),
      );
    }
  }

  void _showAddSheet() {
    _resetAddForm();
    final isWide = MediaQuery.of(context).size.width >= 600;
    if (isWide) {
      showDialog(
        context: context,
        barrierColor: Colors.black45,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.of(context).size.height * 0.80,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _buildSheetContent(
                  setSheetState: setSheetState,
                  isAdd: true,
                  scrollController: ScrollController(),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.90,
            expand: false,
            builder: (context, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: _buildSheetContent(
                setSheetState: setSheetState,
                isAdd: true,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSheetContent({
    required StateSetter setSheetState,
    required bool isAdd,
    required ScrollController scrollController,
    Map<String, dynamic>? serviceData,
  }) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Fixed Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (!isAdd)
                      ...[]
                    else if (_currentStep == 2)
                      IconButton(
                        onPressed: () => setSheetState(() => _currentStep = 1),
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (!isAdd || _currentStep == 2) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdd
                                ? (_currentStep == 1 ? "Choose Service" : (_selectedCategory?.nom ?? "Service Details"))
                                : "Edit Service",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isAdd && _currentStep == 1)
                            const Text(
                              "Select a category",
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            )
                          else if (!isAdd)
                            Text(
                              _selectedCategory?.nom ?? '',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                      ),
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: isAdd
                  ? (_currentStep == 1
                      ? _buildStep1(setSheetState)
                      : _buildStep2(setSheetState, isEditing: false))
                  : _buildStep2(setSheetState, isEditing: true, serviceData: serviceData),
            ),
          ),
          // Fixed Bottom Button (only on step 2 for add / always for edit)
          if (!isAdd || _currentStep == 2)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: CustomButton(
                text: _isSaving ? "Saving..." : (isAdd ? "Save Service" : "Save Changes"),
                onPressed: _isSaving
                    ? null
                    : () {
                        if (isAdd) {
                          _saveService();
                        } else {
                          _saveEditedService(serviceData!);
                        }
                      },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep1(StateSetter setSheetState) {
    // Filter out categories that the expert has already added
    final addedServiceIds = _expertServices.map((s) => s['idService'] as String).toSet();
    final availableCategories = _categories.where((c) => !addedServiceIds.contains(c.id)).toList();

    if (availableCategories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            "You have added all available services.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: availableCategories.length,
      itemBuilder: (context, index) {
        final cat = availableCategories[index];
        final isSelected = _selectedCategory?.id == cat.id;
        
        return GestureDetector(
          onTap: () async {
            setSheetState(() {
              _selectedCategory = cat;
            });
            // Load tasks for this category (Standard + Expert-specific)
            final tasks = await _firestoreService.getTasksForCategory(cat.id!, expertId: widget.expertId);
            setSheetState(() {
              _availableTasks = tasks;
              _currentStep = 2;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGridImage(cat, isSelected),
                const SizedBox(height: 8),
                Text(
                  cat.nom,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridImage(ServiceModel cat, bool isSelected) {
    if (cat.image == null || cat.image!.isEmpty) {
      return Icon(
        Icons.work_outline,
        color: isSelected ? AppColors.primary : const Color(0xFF64748B),
        size: 32,
      );
    }
    
    final imagePath = cat.image!;
    Widget imageWidget;
    
    if (imagePath.startsWith('assets/')) {
      imageWidget = Image.asset(imagePath, width: 44, height: 44, fit: BoxFit.contain,
        errorBuilder: (context, _, __) => Icon(Icons.work_outline, color: isSelected ? AppColors.primary : const Color(0xFF64748B), size: 32));
    } else if (imagePath.startsWith('http')) {
      imageWidget = Image.network(imagePath, width: 44, height: 44, fit: BoxFit.contain,
        errorBuilder: (context, _, __) => Icon(Icons.work_outline, color: isSelected ? AppColors.primary : const Color(0xFF64748B), size: 32));
    } else {
      try {
        String cleanBase64 = imagePath;
        if (imagePath.contains(',')) cleanBase64 = imagePath.split(',').last;
        imageWidget = Image.memory(base64Decode(cleanBase64), width: 44, height: 44, fit: BoxFit.contain,
          errorBuilder: (context, _, __) => Icon(Icons.work_outline, color: isSelected ? AppColors.primary : const Color(0xFF64748B), size: 32));
      } catch (e) {
        return Icon(
          Icons.work_outline,
          color: isSelected ? AppColors.primary : const Color(0xFF64748B),
          size: 32,
        );
      }
    }
    
    return imageWidget;
  }

  Widget _buildStep2(StateSetter setSheetState, {required bool isEditing, Map<String, dynamic>? serviceData}) {
    Widget imageWidget(String imagePath) {
      if (imagePath.startsWith('http')) {
        return Image.network(
          imagePath,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
        );
      } else {
        return Image.memory(
          base64Decode(imagePath.contains(',') ? imagePath.split(',').last : imagePath),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Description",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: "Describe your service...",
            filled: true,
            fillColor: _descriptionController.text.trim().isEmpty ? Colors.red.shade50 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _descriptionController.text.trim().isEmpty ? Colors.red.shade300 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _descriptionController.text.trim().isEmpty ? Colors.red.shade300 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _descriptionController.text.trim().isEmpty ? Colors.red.shade500 : AppColors.primary,
              ),
            ),
            suffixIcon: _descriptionController.text.trim().isEmpty
                ? const Icon(Icons.error_outline, color: Colors.red, size: 20)
                : const Icon(Icons.check_circle, color: Colors.green, size: 20),
            helperText: _descriptionController.text.trim().isEmpty
                ? "Description is required"
                : "Describe what you offer to help clients choose you",
            helperStyle: TextStyle(
              color: _descriptionController.text.trim().isEmpty ? Colors.red.shade700 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          onChanged: (val) => setSheetState(() {}),
        ),
        const SizedBox(height: 24),
        const Text(
          "Skills / Tasks",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._availableTasks.map((task) {
              final isSelected = _selectedTasks.any((t) => t.id == task.id);
              return FilterChip(
                label: Text(task.nom),
                selected: isSelected,
                onSelected: (val) {
                  setSheetState(() {
                    if (val) {
                      if (_selectedTasks.length + _customTasks.length < 10) {
                        _selectedTasks.add(task);
                      }
                    } else {
                      _selectedTasks.removeWhere((t) => t.id == task.id);
                    }
                  });
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              );
            }),
            ..._customTasks.map((task) => Chip(
              label: Text(task),
              onDeleted: () {
                setSheetState(() {
                  _customTasks.remove(task);
                });
              },
              deleteIconColor: Colors.red,
              backgroundColor: AppColors.primary.withOpacity(0.1),
            )),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _customSkillController,
                hint: "Custom skill",
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (_customSkillController.text.isNotEmpty) {
                  if (_selectedTasks.length + _customTasks.length < 10) {
                    setSheetState(() {
                      _customTasks.add(_customSkillController.text);
                      _customSkillController.clear();
                    });
                  }
                }
              },
              icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 32),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          _isPremium
              ? "Photos (Unlimited)"
              : "Photos ($_visiblePhotosCount/$_freePortfolioLimit)",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (!_isPremium && _visiblePhotosCount >= _freePortfolioLimit)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.block, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Photo limit reached. Upgrade to Premium to add more photos!",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/provider/${widget.expertId}/subscription'),
                  child: const Text("Upgrade", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.red)),
                ),
              ],
            ),
          ),
        if (!_isPremium && _imagesWithTasks.any((img) => (img['isVisibleByPlan'] as bool? ?? true) == false))
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Upgrade to Premium to make all your photos visible!",
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/provider/${widget.expertId}/subscription'),
                  child: const Text("Upgrade to Premium", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.orange)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: () => _pickImage(setSheetState),
                child: Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: (!_isPremium && _visiblePhotosCount >= _freePortfolioLimit) 
                        ? Colors.grey.shade100 
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (!_isPremium && _visiblePhotosCount >= _freePortfolioLimit) 
                          ? Colors.grey.shade300 
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo, 
                        color: (!_isPremium && _visiblePhotosCount >= _freePortfolioLimit) 
                            ? Colors.grey.shade400 
                            : Colors.grey,
                      ),
                      if (!_isPremium && _visiblePhotosCount >= _freePortfolioLimit)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            "Limit",
                            style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ..._imagesWithTasks.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              ((entry.value['isVisibleByPlan'] ?? true) == true || entry.value['isVisibleByPlan'] == 'true')
                                ? imageWidget(entry.value['image']!)
                                : Opacity(
                                    opacity: 0.6,
                                    child: ImageFiltered(
                                      imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                      child: imageWidget(entry.value['image']!),
                                    ),
                                  ),
                              if (!((entry.value['isVisibleByPlan'] ?? true) == true || entry.value['isVisibleByPlan'] == 'true'))
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.2),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.lock, color: Colors.white, size: 24),
                                          SizedBox(height: 4),
                                          Text("LOCKED", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 100,
                          child: Text(
                            entry.value['taskName']!,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            _imagesWithTasks.removeAt(entry.key);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showEditSheet(Map<String, dynamic> service) async {
    final String serviceId = service['idService'];
    _selectedCategory = _categories.firstWhere((c) => c.id == serviceId, orElse: () => ServiceModel(nom: 'Unknown', description: '', id: serviceId));
    final List tasks = service['tasks'] ?? [];
    final List serviceImages = service['images'] ?? [];
    
    _descriptionController.text = service['description'] ?? (tasks.isNotEmpty ? tasks[0]['description'] ?? '' : '');
    
    _selectedTasks.clear();
    _customTasks.clear();
    _imagesWithTasks.clear();
    
    // Load images with their task associations and visibility
    final imagesWithTasks = await _firestoreService.getImagesWithTasks(service['id']);
    for (var imgData in imagesWithTasks) {
        _imagesWithTasks.add({
          'image': imgData['image']!,
          'taskId': imgData['taskId'] ?? '',
          'taskName': imgData['taskName'] ?? 'Existing Image',
          'isVisibleByPlan': imgData['isVisibleByPlan'] ?? true,
          'publicId': imgData['publicId'] ?? '',
          'storageType': imgData['storageType'] ?? 'base64',
          'docId': imgData['docId'], // Store docId for deletion/auto-unlock
        });
    }
    
    for (var task in tasks) {
      if (!_selectedTasks.any((t) => t.id == task['idTache'])) {
         _selectedTasks.add(TaskModel(id: task['idTache'], idService: serviceId, nom: task['nom'], description: task['description'] ?? ''));
      }
    }
    _currentStep = 2;
    _isSaving = false;
    
    final fetchedTasks = await _firestoreService.getTasksForCategory(serviceId, expertId: widget.expertId);
    setState(() { _availableTasks = fetchedTasks; });

    if (!mounted) return;

    final isWide = MediaQuery.of(context).size.width >= 600;
    if (isWide) {
      showDialog(
        context: context,
        barrierColor: Colors.black45,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.of(context).size.height * 0.80,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _buildSheetContent(
                  setSheetState: setSheetState,
                  isAdd: false,
                  scrollController: ScrollController(),
                  serviceData: service,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.90,
            expand: false,
            builder: (context, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: _buildSheetContent(
                setSheetState: setSheetState,
                isAdd: false,
                scrollController: scrollController,
                serviceData: service,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalServices = _expertServices.length;
    final isLimitReached = !_isPremium && totalServices >= _freeLimit;
    final progress = (totalServices / _freeLimit) * 100;
    final hasHiddenServices = !_isPremium && _expertServices.any((s) => !(s['isVisibleByPlan'] ?? true));

    return ProviderLayout(
      activeRoute: '/provider/services',
      expertId: widget.expertId,
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "My Services",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B), // Dark blue/slate
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: isLimitReached 
                        ? () => context.push('/provider/${widget.expertId}/subscription')
                        : _showAddSheet,
                      icon: const Icon(Icons.add, size: 20, color: Colors.white),
                      label: const Text(
                        "Add",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLimitReached ? Colors.grey : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),

                if (hasHiddenServices)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text("Subscription suspended, reactivate to restore all your services.", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13, height: 1.4)),
                        ),
                        TextButton(
                          onPressed: () => context.push('/provider/${widget.expertId}/subscription'),
                          child: const Text("Reactivate", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        )
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Limit indicator / Usage Card
                if (!_isPremium)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$totalServices/$_freeLimit services used",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (!_isPremium)
                            GestureDetector(
                              onTap: () =>
                                  context.push('/provider/${widget.expertId}/subscription'),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Upgrade",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Stack(
                        children: [
                          Container(
                            height: 10,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9), // Very light gray/blue
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: (totalServices / _freeLimit).clamp(0.0, 1.0),
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: isLimitReached ? Colors.orange : AppColors.primary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Service Cards
                if (_expertServices.isEmpty)
                  const Center(child: Text("No services added yet."))
                else
                  ..._expertServices.map((service) => _buildServiceCard(service)),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    bool isActive = service["estActive"] ?? true;
    bool isVisibleByPlan = _isPremium ? true : (service["isVisibleByPlan"] ?? true);
    final List tasks = service["tasks"] ?? [];
    // Prefer service image from collection, fallback to first task image
    String? thumbnail = service['serviceImage'];
    if ((thumbnail == null || thumbnail.isEmpty) && tasks.isNotEmpty && tasks[0]['images'] != null && tasks[0]['images'].isNotEmpty) {
      thumbnail = tasks[0]['images'][0];
    }

    ImageProvider? imageProvider;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      if (thumbnail.startsWith('assets/')) {
        imageProvider = AssetImage(thumbnail);
      } else if (thumbnail.startsWith('http')) {
        imageProvider = NetworkImage(thumbnail);
      } else {
        try {
          String cleanBase64 = thumbnail;
          if (thumbnail.contains(',')) cleanBase64 = thumbnail.split(',').last;
          imageProvider = MemoryImage(base64Decode(cleanBase64));
        } catch (e) {
          debugPrint('Error decoding base64 thumbnail: $e');
        }
      }
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Opacity(
        opacity: isVisibleByPlan ? 1.0 : 0.6,
        child: GestureDetector(
          onTap: isVisibleByPlan ? () => _showDetailsService(service) : null,
          child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon/Image Container
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // Very light blue
                    borderRadius: BorderRadius.circular(20),
                    image: imageProvider != null 
                      ? DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                  ),
                  child: imageProvider == null 
                    ? const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF3B82F6), // Blue 500
                        size: 32,
                      )
                    : null,
                ),
                const SizedBox(width: 16),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service["serviceName"],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tasks.isNotEmpty ? tasks[0]['nom'] : "No tasks",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B), // Slate/Gray
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${tasks.length} tasks",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle Switch
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: isActive,
                    onChanged: isVisibleByPlan ? (val) => _toggleService(service["id"], isActive) : null,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            // Footer: State Badge + Actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isActive ? "Active" : "Inactive",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isActive ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (!isVisibleByPlan) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("Hidden (Plan)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => _showEditSheet(service), 
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text("Edit", style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteService(service["idService"]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 6),
                        Text("Delete", style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red)),
                      ],
                    ),
                  ),
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

  void _showDetailsService(Map<String, dynamic> service) {
    final List tasks = service['tasks'] as List? ?? [];
    
    // Build a map of taskId -> taskName for labeling images
    final Map<String, String> taskIdToName = {};
    for (var t in tasks) {
      taskIdToName[t['id']?.toString() ?? ''] = t['nom']?.toString() ?? 'Task';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.work_outline, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            service['serviceName'] ?? 'Service details',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Description
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              service['description'] ?? 'Aucune description.',
                              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Skills
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Compétences & Tâches", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                          ),
                          const SizedBox(height: 12),
                          tasks.isEmpty
                            ? const Text('Aucune tâche ajoutée.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tasks.map((t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withAlpha(50)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(t['nom']?.toString() ?? '', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                                    ],
                                  ),
                                )).toList(),
                              ),
                          const SizedBox(height: 24),
                          // Photos with skill labels
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Photos & Réalisations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _firestoreService.getImagesWithTasks(service['id'] as String),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              }
                              final images = snapshot.data ?? [];
                              final flatImages = service['images'] as List? ?? [];
                              if (images.isEmpty && flatImages.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Aucune photo ajoutée.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                );
                              }
                              if (images.isNotEmpty) {
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.85,
                                  ),
                                  itemCount: images.length,
                                  itemBuilder: (context, index) {
                                    final imgData = images[index];
                                    String img = imgData['image'] ?? '';
                                    if (img.contains(',')) img = img.split(',').last;
                                    final taskName = imgData['taskName'] as String? ?? '';
                                    return Column(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Stack(
                                              children: [
                                                ((imgData['isVisibleByPlan'] ?? true) == true || imgData['isVisibleByPlan'] == 'true' || _isPremium)
                                                  ? (img.startsWith('http')
                                                      ? Image.network(img, fit: BoxFit.cover, width: double.infinity,
                                                          errorBuilder: (context, _, __) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))
                                                      : Image.memory(base64Decode(img), fit: BoxFit.cover, width: double.infinity,
                                                          errorBuilder: (context, _, __) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image))))
                                                  : Opacity(
                                                      opacity: 0.6,
                                                      child: ImageFiltered(
                                                        imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                                        child: img.startsWith('http')
                                                          ? Image.network(img, fit: BoxFit.cover, width: double.infinity,
                                                              errorBuilder: (context, _, __) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))
                                                          : Image.memory(base64Decode(img), fit: BoxFit.cover, width: double.infinity,
                                                              errorBuilder: (context, _, __) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image))),
                                                      ),
                                                    ),
                                                if (!((imgData['isVisibleByPlan'] ?? true) == true || imgData['isVisibleByPlan'] == 'true' || _isPremium))
                                                  Positioned.fill(
                                                    child: Container(
                                                      color: Colors.black.withOpacity(0.2),
                                                      child: const Center(
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(Icons.lock, color: Colors.white, size: 24),
                                                            SizedBox(height: 4),
                                                            Text("LOCKED", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (taskName.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withAlpha(20),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              taskName,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                );
                              }
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1,
                                ),
                                itemCount: flatImages.length,
                                itemBuilder: (context, index) {
                                  String img = flatImages[index].toString();
                                  if (img.contains(',')) img = img.split(',').last;
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: img.startsWith('http')
                                      ? Image.network(img, fit: BoxFit.cover, errorBuilder: (context, _, __) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))
                                      : Image.memory(base64Decode(img), fit: BoxFit.cover, errorBuilder: (context, _, __) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image))),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
