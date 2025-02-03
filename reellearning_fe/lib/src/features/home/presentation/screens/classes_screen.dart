import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import '../widgets/bottom_nav_bar.dart';

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Classes Screen',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome, ${user?.email ?? 'User'}!',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/messages');
              break;
            case 2:
              // Already on classes
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }
} 