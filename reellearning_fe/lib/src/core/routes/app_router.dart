import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/features/auth/presentation/screens/login_screen.dart';
import 'package:reellearning_fe/src/features/auth/presentation/screens/signup_screen.dart';
import 'package:reellearning_fe/src/features/home/presentation/screens/home_screen.dart';

// TODO: Implement router configuration
class AppRouter {
  static final GoRouter router = GoRouter(
    // need to make initial location be the home page, but if user is not logged in, it should redirect to the login page
    initialLocation: '/login',
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
    ],
  );
} 