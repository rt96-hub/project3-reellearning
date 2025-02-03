import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Stream of auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges();
});

// Current user state
final currentUserProvider = StateProvider<User?>((ref) {
  // Initialize with current user
  return FirebaseAuth.instance.currentUser;
});

// Add a provider to combine auth state and user data
final userStateProvider = Provider<AsyncValue<User?>>((ref) {
  return ref.watch(authStateProvider);
}); 