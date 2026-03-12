import 'package:flutter/material.dart';
import '../widgets/provider_bottom_nav.dart';
import '../widgets/provider_sidebar.dart';

class ProviderLayout extends StatefulWidget {
  final Widget child;
  final bool showBottomNav;
  final int currentIndex;

  const ProviderLayout({
    super.key,
    required this.child,
    this.showBottomNav = true,
    this.currentIndex = 0,
  });

  @override
  State<ProviderLayout> createState() => _ProviderLayoutState();
}

class _ProviderLayoutState extends State<ProviderLayout> {
  bool _sidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: showBottomNav ? 80 : 0),
          child: child,
        ),
      ),
      bottomNavigationBar: showBottomNav
          ? ProviderBottomNav(currentIndex: currentIndex)
          : null,
    );
  }
}
