import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signUp(String email, String password, String phone) async {
    try {
      // Create auth user without signing in
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Store phone number in temporary auth user metadata
      await userCredential.user!.updateDisplayName(phone);

      // Sign out immediately in case Firebase auto-signed in
      await _auth.signOut();
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw _handleAuthError(e);
      }
      rethrow;
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      // Attempt to sign in to check verification status
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If we get here, the user exists and password is correct
      // Now check verification status
      if (!userCredential.user!.emailVerified) {
        // Sign out and throw verification error
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please check your email for a verification link before signing in.',
        );
      }

      // User is verified, check if user document exists
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        // Create user document on first verified login
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'phone': userCredential.user!.displayName ?? '', // Get phone from metadata
          'createdAt': Timestamp.now(),
          'profile': {
            'displayName': email.split('@')[0],
            'avatarUrl': '',
            'biography': ''
          }
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      switch (e.code) {
        case 'user-not-found':
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No account found with this email. Please sign up first.',
          );
        case 'wrong-password':
          throw FirebaseAuthException(
            code: 'wrong-password',
            message: 'Incorrect password. Please try again.',
          );
        default:
          throw _handleAuthError(e);
      }
    } catch (e) {
      rethrow;
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'The password provided is too weak';
      case 'email-not-verified':
        return 'Please check your email for a verification link before signing in.';
      default:
        return e.message ?? 'An unknown error occurred';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Add method to resend verification email
  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
}
