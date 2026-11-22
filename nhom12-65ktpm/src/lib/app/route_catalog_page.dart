import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';

// Trang nội bộ để kiểm tra cả 26 đường dẫn trên Android Emulator.
class RouteCatalogPage extends StatelessWidget {
  const RouteCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục 26 màn hình (demo)')),
      body: ListView.builder(
        itemCount: AppRoutes.screens.length,
        itemBuilder: (context, index) {
          final screen = AppRoutes.screens[index];
          return ListTile(
            key: ValueKey(screen.code),
            title: Text('${screen.code} • ${screen.title}'),
            subtitle: Text(screen.previewPath),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Năm trang tab chính dùng go, trang con dùng push.
              if (screen.previewPath == AppRoutes.home ||
                  screen.previewPath == AppRoutes.explore ||
                  screen.previewPath == AppRoutes.transactions ||
                  screen.previewPath == AppRoutes.profile) {
                context.go(screen.previewPath);
              } else {
                context.push(screen.previewPath);
              }
            },
          );
        },
      ),
    );
  }
}
