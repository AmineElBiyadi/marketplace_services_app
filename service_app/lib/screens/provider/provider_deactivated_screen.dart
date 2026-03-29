import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';

class ProviderDeactivatedScreen extends StatefulWidget {
  const ProviderDeactivatedScreen({super.key});

  @override
  State<ProviderDeactivatedScreen> createState() => _ProviderDeactivatedScreenState();
}

class _ProviderDeactivatedScreenState extends State<ProviderDeactivatedScreen> {
  final _firestoreService = FirestoreService();
  bool _isLoading = true;
  bool _isReactivating = false;
  String? _expertId;
  String? _status;
  bool _desactiveParAdmin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        context.go('/welcome');
        return;
      }

      final providerData = await _firestoreService.getProviderByUid(user.uid);
      if (providerData == null) {
        context.go('/welcome');
        return;
      }

      setState(() {
        _expertId = providerData['expertId'];
        _status = providerData['etatCompte'];
        _desactiveParAdmin = providerData['desactiveParAdmin'] ?? false;
        _isLoading = false;
      });
      
      // If active, go to dashboard
      if (_status == 'ACTIVE') {
        context.go('/provider/$_expertId/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Loading error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReactivation() async {
    if (_expertId == null) return;
    
    setState(() => _isReactivating = true);
    try {
      await _firestoreService.reactivateExpertSelf(_expertId!);
      if (mounted) {
        context.go('/provider/$_expertId/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isReactivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isSuspended = _status == 'SUSPENDUE';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go('/welcome'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) context.go('/welcome');
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: (isSuspended || _desactiveParAdmin) ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  (isSuspended || _desactiveParAdmin) ? LucideIcons.alertCircle : LucideIcons.userX,
                  size: 50,
                  color: (isSuspended || _desactiveParAdmin) ? Colors.red : Colors.orange,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isSuspended ? "Account Suspended" : "Account Deactivated",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _getMessage(),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (!_desactiveParAdmin && !isSuspended)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isReactivating ? null : _handleReactivation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isReactivating
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text(
                            "Reactivate my account",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              if (_desactiveParAdmin || isSuspended)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      // Support behavior
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Contact support",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadStatus,
                child: const Text("Refresh status", style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMessage() {
    if (_status == 'SUSPENDUE') {
      return "Your account has been suspended by administration for verification. Please contact support for more details.";
    }
    if (_desactiveParAdmin) {
      return "Your account has been deactivated by an administrator. You cannot reactivate it yourself. Please contact support.";
    }
    return "You have deactivated your account. You can reactivate it at any time to resume your activity.";
  }
}
