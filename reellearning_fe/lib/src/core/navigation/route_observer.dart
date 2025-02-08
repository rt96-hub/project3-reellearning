import 'package:flutter/material.dart';

/// Custom route observer for tracking navigation at different levels of the app
class AppRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final String name;
  final bool enableLogging;

  AppRouteObserver({
    required this.name,
    this.enableLogging = true,
  });

  void _log(String message) {
    if (enableLogging) {
      debugPrint('[$name] $message');
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _log('didPush: ${route.settings.name} (previous: ${previousRoute?.settings.name})');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _log('didPop: ${route.settings.name} (previous: ${previousRoute?.settings.name})');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _log('didReplace: ${newRoute?.settings.name} (old: ${oldRoute?.settings.name})');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _log('didRemove: ${route.settings.name} (previous: ${previousRoute?.settings.name})');
  }
}

/// Singleton instances for different navigation levels
class AppRouteObservers {
  static final rootObserver = AppRouteObserver(name: 'RootNavigator');
  static final shellObserver = AppRouteObserver(name: 'ShellNavigator');
  static final profileObserver = AppRouteObserver(name: 'ProfileNavigator');
  static final classesObserver = AppRouteObserver(name: 'ClassesNavigator');

  // Private constructor to prevent instantiation
  AppRouteObservers._();
}
