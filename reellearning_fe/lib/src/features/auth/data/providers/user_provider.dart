import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/firebase_providers.dart';

// Cache user data to avoid multiple Firestore reads
final userDataProvider = StreamProvider.family<Map<String, dynamic>, DocumentReference>((ref, userRef) {
  final firestore = ref.watch(firestoreProvider);
  
  return firestore
      .doc(userRef.path)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data() ?? {};
        final profile = data['profile'] as Map<String, dynamic>? ?? {};
        return {
          ...data,
          'displayName': profile['displayName'],
          'avatarUrl': profile['avatarUrl'],
          'biography': profile['biography'],
        };
      });
}); 