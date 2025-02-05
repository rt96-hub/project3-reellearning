import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential> signUp(String email, String password, String phone) async {
    try {
      // First create the auth user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Then create the user document with explicit typing
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'phone': phone,
        'createdAt': Timestamp.now(),
        'profile': {
          'displayName': email.split('@')[0],  // Use part before @ as initial display name
          'avatarUrl': '',  // Empty for now
          'biography': ''   // Empty for now
        }
      });

      return userCredential;
    } catch (e) {
      // Add better error handling
      if (e is FirebaseAuthException) {
        throw _handleAuthError(e);
      }
      rethrow;
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user document exists and has profile
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      
      if (!userDoc.exists || !userDoc.data()!.containsKey('profile')) {
        // Create or update user document with profile
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'profile': {
            'displayName': email.split('@')[0],
            'avatarUrl': '',
            'biography': ''
          }
        }, SetOptions(merge: true));  // merge: true ensures we don't overwrite other fields
      }

      return userCredential;
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw _handleAuthError(e);
      }
      rethrow;
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password provided';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'The password provided is too weak';
      default:
        return e.message ?? 'An unknown error occurred';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
} 