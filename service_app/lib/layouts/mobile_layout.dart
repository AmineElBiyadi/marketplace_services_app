import 'package:flutter/material.dart';
import '../widgets/bottom_nav.dart';

class MobileLayout extends StatelessWidget {
  final Widget child;
  final bool showBottomNav;
  final int currentIndex;

  const MobileLayout({
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
          ? BottomNav(currentIndex: currentIndex)
          : null,
    );
  }
}
