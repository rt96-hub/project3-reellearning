import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/widgets/bottom_nav_bar.dart';
import '../../features/navigation/providers/tab_state_provider.dart';
import '../../features/videos/data/providers/video_controller_provider.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  final int selectedIndex;

  const ShellScaffold({
    super.key,
    required this.child,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Update tab state when the selected index changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tabStateProvider.notifier).setTab(selectedIndex);
    });

    // Listen to tab changes
    ref.listen(tabStateProvider, (previous, next) {
      if (previous != null && previous != next) {
        // Pause video when changing tabs
        ref.read(videoControllerProvider.notifier).pauseAndRemember();
      }
    });

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/classes');
              break;
            case 2:
              context.go('/search');
              break;
            case 3:
              context.go('/messages');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }
}