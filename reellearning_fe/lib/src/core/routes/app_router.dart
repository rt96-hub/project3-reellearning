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
import '../widgets/shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();
final _classesNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isGoingToAuth = state.matchedLocation == '/login' || 
                           state.matchedLocation == '/signup';

      if (!isLoggedIn && !isGoingToAuth) {
        return '/login';
      }

      if (isLoggedIn && isGoingToAuth) {
        return '/';
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
      // Root shell route for main navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          // Determine selected index based on the current path
          final location = state.uri.path;
          int selectedIndex = 0;
          if (location.startsWith('/classes')) selectedIndex = 1;
          if (location.startsWith('/search')) selectedIndex = 2;
          if (location.startsWith('/messages')) selectedIndex = 3;
          if (location.startsWith('/profile')) selectedIndex = 4;
          
          return ShellScaffold(
            selectedIndex: selectedIndex,
            child: child,
          );
        },
        routes: [
          // Home route with all nested navigation
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'search',  // becomes /search
                builder: (context, state) => const SearchScreen(),
              ),
              GoRoute(
                path: 'messages',  // becomes /messages
                builder: (context, state) => const MessagesScreen(),
              ),
              // Profile section with nested navigation
              ShellRoute(
                navigatorKey: _profileNavigatorKey,
                builder: (context, state, child) => child,
                routes: [
                  GoRoute(
                    path: 'profile',  // becomes /profile
                    builder: (context, state) => const ProfileScreen(),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => const EditProfileScreen(),
                      ),
                      GoRoute(
                        path: 'videos',
                        builder: (context, state) => const Scaffold(
                          body: Center(child: Text('Your Posted Videos - Coming Soon')),
                        ),
                      ),
                      GoRoute(
                        path: 'liked-videos',
                        builder: (context, state) => const Scaffold(
                          body: Center(child: Text('Liked Videos - Coming Soon')),
                        ),
                      ),
                      GoRoute(
                        path: 'bookmarked',
                        builder: (context, state) => const Scaffold(
                          body: Center(child: Text('Bookmarked Videos - Coming Soon')),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'profile/:userId',  // becomes /profile/:userId
                    builder: (context, state) => ProfileScreen(
                      userId: state.pathParameters['userId'],
                    ),
                    routes: [
                      GoRoute(
                        path: 'videos',
                        builder: (context, state) => Scaffold(
                          body: Center(child: Text('${state.pathParameters['userId']}\'s Posted Videos - Coming Soon')),
                        ),
                      ),
                      GoRoute(
                        path: 'liked-videos',
                        builder: (context, state) => Scaffold(
                          body: Center(child: Text('${state.pathParameters['userId']}\'s Liked Videos - Coming Soon')),
                        ),
                      ),
                      GoRoute(
                        path: 'bookmarked',
                        builder: (context, state) => Scaffold(
                          body: Center(child: Text('${state.pathParameters['userId']}\'s Bookmarked Videos - Coming Soon')),
                        ),
                      ),
                      GoRoute(
                        path: 'classes',
                        builder: (context, state) => Scaffold(
                          body: Center(child: Text('${state.pathParameters['userId']}\'s Classes - Coming Soon')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Classes section with nested navigation
              ShellRoute(
                navigatorKey: _classesNavigatorKey,
                builder: (context, state, child) => child,
                routes: [
                  GoRoute(
                    path: 'classes',  // becomes /classes
                    builder: (context, state) => const ClassesScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const CreateClassScreen(),
                      ),
                      GoRoute(
                        path: ':classId',
                        builder: (context, state) => ClassDetailScreen(
                          classId: state.pathParameters['classId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}); 