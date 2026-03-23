import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class CguUpdateScreen extends StatefulWidget {
  final Map<String, dynamic> extraData;
  const CguUpdateScreen({super.key, required this.extraData});

  @override
  State<CguUpdateScreen> createState() => _CguUpdateScreenState();
}

class _CguUpdateScreenState extends State<CguUpdateScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _acceptCgu() async {
    setState(() => _isLoading = true);
    try {
      final uid = widget.extraData['uid'];
      final cgu = widget.extraData['cgu'];
      final role = widget.extraData['role'];

      // Update in Firestore
      await _firestoreService.updateCguVersion(uid, cgu?['version'] ?? '1.0');
      
      if (mounted) {
        if (role == 'CLIENT') {
          context.go('/home');
        } else {
          final providerData = await _firestoreService.getProviderByUid(uid);
          final expertId = providerData?['expertId'] ?? '';
          final etatCompte = providerData?['etatCompte'] ?? 'PENDING';
          
          if (!mounted) return;
          
          if (etatCompte == 'ACTIVE') {
            context.go('/provider/$expertId/dashboard');
          } else {
            context.go('/provider/pending');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final cgu = widget.extraData['cgu'];
    final content = cgu?['content']?.replaceAll('\\n', '\n') ?? 
        'Les conditions générales ne sont pas encore configurées dans la base de données. Vous pouvez tout de même continuer et accepter la version par défaut.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mise à jour des CGU'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF1A237E),
        automaticallyImplyLeading: false, // Force them to choose
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'Nos conditions d\'utilisation et notre politique de confidentialité ont été mises à jour. Veuillez les lire et les accepter pour continuer à utiliser l\'application.',
                style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _acceptCgu,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F64B5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Accepter et continuer',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading ? null : _logout,
                      child: const Text('Se déconnecter',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
