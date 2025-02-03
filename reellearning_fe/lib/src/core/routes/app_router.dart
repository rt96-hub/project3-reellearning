import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/profile_screen.dart';
import '../../features/home/presentation/screens/messages_screen.dart';
import '../../features/home/presentation/screens/classes_screen.dart';

// TODO: Implement router configuration
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // Check if the user is logged in
      final isLoggedIn = authState.value != null;
      final isGoingToAuth = state.matchedLocation == '/login' || 
                           state.matchedLocation == '/signup';

      if (!isLoggedIn && !isGoingToAuth) {
        return '/login';
      }

      if (isLoggedIn && isGoingToAuth) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/classes',
        builder: (context, state) => const ClassesScreen(),
      ),
    ],
  );
}); 