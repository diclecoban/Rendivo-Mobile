import 'package:flutter/material.dart';

class BusinessBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isPending;
  final ValueChanged<int> onTap;

  const BusinessBottomNav({
    super.key,
    required this.currentIndex,
    required this.isPending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: isPending,
      child: Opacity(
        opacity: isPending ? 0.5 : 1,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.design_services_outlined),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              label: 'Staff',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              label: 'Schedule',
            ),
          ],
        ),
      ),
    );
  }
}
