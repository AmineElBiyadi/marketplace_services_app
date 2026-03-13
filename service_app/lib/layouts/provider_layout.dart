import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/provider_bottom_nav.dart';
import '../widgets/provider_sidebar.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

class ProviderLayout extends StatefulWidget {
  final Widget child;
  final bool showBottomNav;
  final String activeRoute;
  final String expertId;

  const ProviderLayout({
    super.key,
    required this.child,
    this.showBottomNav = true,
    this.activeRoute = '/provider/dashboard',
    required this.expertId,
  });

  @override
  State<ProviderLayout> createState() => _ProviderLayoutState();
}

class _ProviderLayoutState extends State<ProviderLayout> {
  bool _sidebarOpen = true;
  String? _resolvedExpertId;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    final expertId = await _firestoreService.getExpertIdFromSession();
    if (mounted) {
      if (expertId != null) {
        setState(() => _resolvedExpertId = expertId);
      } else {
        // Force logout or error if session cannot be resolved to an expert
        // For now, we'll just not set _resolvedExpertId which will show the loader
        debugPrint("[ProviderLayout] Critical: Session could not be resolved to an Expert ID.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedExpertId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      drawer: isMobile 
          ? ProviderSidebar(
              activeRoute: widget.activeRoute, 
              isMobile: true,
              expertId: _resolvedExpertId!,
            ) 
          : null,
      body: Row(
        children: [
          if (!isMobile)
            ProviderSidebar(
              activeRoute: widget.activeRoute,
              isOpen: _sidebarOpen,
              onToggle: () => setState(() => _sidebarOpen = !_sidebarOpen),
              expertId: _resolvedExpertId!,
            ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: widget.child,
                ),
                if (isMobile && widget.showBottomNav)
                  ProviderBottomNav(
                    currentIndex: _getSelectedIndex(widget.activeRoute),
                    expertId: _resolvedExpertId!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(String route) {
    switch (route) {
      case '/provider/dashboard':
        return 0;
      case '/provider/services':
        return 1;
      case '/provider/bookings':
        return 2;
      case '/provider/agenda':
        return 3;
      case '/provider/profile':
        return 4;
      default:
        return 0;
    }
  }
}
