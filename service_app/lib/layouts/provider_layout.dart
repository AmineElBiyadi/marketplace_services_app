import 'package:flutter/material.dart';
import '../widgets/provider_bottom_nav.dart';

class ProviderLayout extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
