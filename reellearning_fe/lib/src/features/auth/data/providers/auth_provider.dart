import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Stream of auth state changes that includes verification status
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges().map((user) {
    if (user != null && !user.emailVerified) {
      // Sign out if email is not verified
      FirebaseAuth.instance.signOut();
      return null;
    }
    return user;
  });
});

// Current user state
final currentUserProvider = StateProvider<User?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && !user.emailVerified) {
    FirebaseAuth.instance.signOut();
    return null;
  }
  return user;
});

// Provider to check if user needs email verification
final needsVerificationProvider = StateProvider<bool>((ref) => false);

// Add a provider to combine auth state and user data
final userStateProvider = Provider<AsyncValue<User?>>((ref) {
  return ref.watch(authStateProvider);
});