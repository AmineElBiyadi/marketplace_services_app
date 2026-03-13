import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:io';
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
  final int _freeLimit = 3;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Get services
      final services = await _firestoreService.getExpertServicesDetailed(widget.expertId);
      
      // Get categories
      final categories = await _firestoreService.getServiceCategories();

      // Check premium status (assuming from expert doc)
      final expertDoc = await _firestoreService.getExpertById(widget.expertId);
      final isPremium = expertDoc?['isPremium'] ?? false;

      setState(() {
        _expertServices = services;
        _categories = categories;
        _isPremium = isPremium;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading data: $e")),
      );
    }
  }

  Future<void> _toggleService(String id, bool currentStatus) async {
    try {
      await _firestoreService.toggleServiceExpertsActive(id, !currentStatus);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
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
      try {
        await _firestoreService.deleteExpertService(widget.expertId, serviceId);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service deleted successfully")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting: $e")),
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
  final List<String> _base64Images = [];
  bool _isSaving = false;

  Future<void> _pickImage(StateSetter setSheetState) async {
    if (_base64Images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 3 photos allowed")),
      );
      return;
    }
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setSheetState(() {
        _base64Images.add(base64Encode(bytes));
      });
      // also update main state just in case
      setState(() {});
    }
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
      _base64Images.clear();
      _isSaving = false;
    });
  }

  Future<void> _saveService() async {
    if (_selectedCategory == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Category and Description are required")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestoreService.addExpertService(
        expertId: widget.expertId,
        serviceId: _selectedCategory!.id!,
        description: _descriptionController.text,
        selectedTasks: _selectedTasks,
        customTasks: _customTasks,
        base64Images: _base64Images,
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
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description is required")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateExpertService(
        expertId: widget.expertId,
        serviceExpertDocId: serviceData['id'],
        serviceId: serviceData['idService'],
        description: _descriptionController.text,
        selectedTasks: _selectedTasks,
        customTasks: _customTasks,
        base64Images: _base64Images,
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
                Icon(
                  Icons.work_outline,
                  color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                  size: 32,
                ),
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

  Widget _buildStep2(StateSetter setSheetState, {required bool isEditing, Map<String, dynamic>? serviceData}) {
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
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
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
        const Text(
          "Photos (Max 3)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: () => _pickImage(setSheetState),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              ..._base64Images.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(entry.value),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            _base64Images.removeAt(entry.key);
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
    _base64Images.clear();
    
    for (var img in serviceImages) {
        String cleanImg = img;
        if (cleanImg.contains(',')) cleanImg = cleanImg.split(',').last;
        if (!_base64Images.contains(cleanImg)) _base64Images.add(cleanImg);
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
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Switch to Premium plan to add more services")),
                            );
                          }
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

                const SizedBox(height: 24),

                // Limit indicator / Usage Card
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
                          GestureDetector(
                            onTap: () =>
                                context.push('/provider/subscription'),
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
    final List tasks = service["tasks"] ?? [];
    // Thumbnail from first task image or placeholder
    String? thumbnail;
    if (tasks.isNotEmpty && tasks[0]['images'] != null && tasks[0]['images'].isNotEmpty) {
      thumbnail = tasks[0]['images'][0];
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
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
                    image: thumbnail != null 
                      ? DecorationImage(
                          image: MemoryImage(base64Decode(thumbnail)),
                          fit: BoxFit.cover,
                        )
                      : null,
                  ),
                  child: thumbnail == null 
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
                    onChanged: (val) => _toggleService(service["id"], isActive),
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
                const Spacer(),
                GestureDetector(
                  onTap: () => _showEditSheet(service), 
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 22,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _deleteService(service["idService"]),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 22,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
