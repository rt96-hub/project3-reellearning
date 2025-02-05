import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/profile_screen.dart';
import '../../features/home/presentation/screens/edit_profile_screen.dart';
import '../../features/home/presentation/screens/messages_screen.dart';
import '../../features/home/presentation/screens/classes_screen.dart';
import '../../features/home/presentation/screens/class_detail_screen.dart';
import '../../features/home/presentation/screens/create_class_screen.dart';
import '../../features/home/presentation/screens/search_screen.dart';

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
      // Profile routes - static paths first
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/liked-videos',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Liked Videos - Coming Soon')),
        ),
      ),
      GoRoute(
        path: '/profile/bookmarked',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Bookmarked Videos - Coming Soon')),
        ),
      ),
      // Profile routes with parameters
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) => ProfileScreen(
          userId: state.pathParameters['userId'],
        ),
      ),
      GoRoute(
        path: '/profile/:userId/liked-videos',
        builder: (context, state) => Scaffold(
          body: Center(child: Text('${state.pathParameters['userId']}\'s Liked Videos - Coming Soon')),
        ),
      ),
      GoRoute(
        path: '/profile/:userId/bookmarked',
        builder: (context, state) => Scaffold(
          body: Center(child: Text('${state.pathParameters['userId']}\'s Bookmarked Videos - Coming Soon')),
        ),
      ),
      GoRoute(
        path: '/profile/:userId/classes',
        builder: (context, state) => Scaffold(
          body: Center(child: Text('${state.pathParameters['userId']}\'s Classes - Coming Soon')),
        ),
      ),
      // Other routes
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/classes',
        builder: (context, state) => const ClassesScreen(),
      ),
      GoRoute(
        path: '/classes/new',
        builder: (context, state) => const CreateClassScreen(),
      ),
      GoRoute(
        path: '/classes/:classId',
        builder: (context, state) => ClassDetailScreen(
          classId: state.pathParameters['classId']!,
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
    ],
  );
}); 