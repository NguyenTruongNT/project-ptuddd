import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StudyShareShell extends StatelessWidget {
  const StudyShareShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StudyShare')),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Khám phá'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'Đăng tin'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Giao dịch'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Cá nhân'),
        ],
      ),
    );
  }
}
