import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';

final onboardingCompletedProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  
  if (user == null) {
    return Stream.value(false);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .where((doc) => doc.exists)
      .map((doc) => doc.data()?['onboardingCompleted'] as bool? ?? false);
});
