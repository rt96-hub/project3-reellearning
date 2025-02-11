import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/providers/auth_provider.dart';
import '../../features/onboarding/data/providers/onboarding_provider.dart';
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
import '../../features/home/presentation/screens/class_members_screen.dart';
import '../../features/home/presentation/screens/user_classes_screen.dart';
import '../../features/home/presentation/screens/settings_screen.dart';
import '../../features/home/presentation/screens/user_progress_screen.dart';
import '../../features/home/presentation/screens/class_progress_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_profile_screen.dart';
import '../../features/onboarding/presentation/screens/interests_screen.dart';
import '../../features/videos/presentation/screens/video_grid_screen.dart';
import '../widgets/shell_scaffold.dart';
import '../navigation/route_observer.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();
final _classesNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    observers: [AppRouteObservers.rootObserver],
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isGoingToAuth = state.matchedLocation == '/login' || 
                           state.matchedLocation == '/signup';
      
      // Handle loading and error states
      final isOnboardingCompleted = onboardingCompleted.when(
        data: (value) => value,
        loading: () => false,
        error: (_, __) => false,
      );
      
      final isGoingToOnboarding = state.matchedLocation.startsWith('/onboarding');

      // Not logged in - redirect to login
      if (!isLoggedIn && !isGoingToAuth) {
        return '/login';
      }

      // Logged in but trying to access auth pages - redirect to home
      if (isLoggedIn && isGoingToAuth) {
        if (!isOnboardingCompleted) {
          return '/onboarding/profile';
        }
        return '/';
      }

      // Logged in but onboarding not completed - redirect to onboarding
      if (isLoggedIn && !isOnboardingCompleted && !isGoingToOnboarding) {
        return '/onboarding/profile';
      }

      // Onboarding completed but trying to access onboarding pages - redirect to home
      if (isLoggedIn && isOnboardingCompleted && isGoingToOnboarding) {
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
      // Onboarding routes
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingProfileScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const OnboardingProfileScreen(),
          ),
          GoRoute(
            path: 'interests',
            builder: (context, state) => const InterestsScreen(),
          ),
        ],
      ),
      // Root shell route for main navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        observers: [AppRouteObservers.shellObserver],
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
                path: 'messages',  // becomes /messages
                builder: (context, state) => const MessagesScreen(),
              ),
              GoRoute(
                path: 'search',  // becomes /search
                builder: (context, state) => const SearchScreen(),
              ),
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
                    routes: [
                      GoRoute(
                        path: 'members',
                        builder: (context, state) => ClassMembersScreen(
                          classId: state.pathParameters['classId']!,
                          className: (state.extra as Map<String, dynamic>)['className'] as String,
                        ),
                      ),
                      GoRoute(
                        path: 'bookmarked',
                        builder: (context, state) => VideoGridScreen(
                          title: '${(state.extra as Map<String, dynamic>)['className'] as String} Bookmarks',
                          sourceType: 'class',
                          sourceId: state.pathParameters['classId']!,
                          videoType: 'bookmarks',
                        ),
                      ),
                      GoRoute(
                        path: 'progress',
                        builder: (context, state) => ClassProgressScreen(
                          classId: state.pathParameters['classId']!,
                        ),
                      ),
                    ],
                  ),
                ],
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
                        path: 'settings',
                        builder: (context, state) => const SettingsScreen(),
                      ),
                      GoRoute(
                        path: 'videos',
                        builder: (context, state) => VideoGridScreen(
                          title: 'Your Videos',
                          sourceType: 'user',
                          sourceId: authState.value?.uid ?? '',
                          videoType: 'videos',
                        ),
                      ),
                      GoRoute(
                        path: 'liked-videos',
                        builder: (context, state) => VideoGridScreen(
                          title: 'Your Likes',
                          sourceType: 'user',
                          sourceId: authState.value?.uid ?? '',
                          videoType: 'likes',
                        ),
                      ),
                      GoRoute(
                        path: 'bookmarked',
                        builder: (context, state) => VideoGridScreen(
                          title: 'Your Bookmarks',
                          sourceType: 'user',
                          sourceId: authState.value?.uid ?? '',
                          videoType: 'bookmarks',
                        ),
                      ),
                      GoRoute(
                        path: 'progress',
                        builder: (context, state) => UserProgressScreen(
                          userId: authState.value?.uid,
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
                        builder: (context, state) => VideoGridScreen(
                          title: '${(state.extra as Map<String, dynamic>)['displayName'] as String} Videos',
                          sourceType: 'user',
                          sourceId: state.pathParameters['userId']!,
                          videoType: 'videos',
                        ),
                      ),
                      GoRoute(
                        path: 'classes',
                        builder: (context, state) => UserClassesScreen(
                          userId: state.pathParameters['userId']!,
                          displayName: (state.extra as Map<String, dynamic>)['displayName'] as String,
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