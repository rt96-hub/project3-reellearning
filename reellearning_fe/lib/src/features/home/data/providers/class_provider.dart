import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../models/class_model.dart';
import '../repositories/class_repository.dart';

final classRepositoryProvider = Provider<ClassRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ClassRepository(firestore: firestore);
});

final createdClassesProvider = StreamProvider<List<ClassModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final repository = ref.watch(classRepositoryProvider);
  return repository.getCreatedClasses(user.uid);
});

final joinedClassesProvider = StreamProvider<List<ClassModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final repository = ref.watch(classRepositoryProvider);
  return repository.getJoinedClasses(user.uid);
});

final discoverableClassesProvider = StreamProvider<List<ClassModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  final repository = ref.watch(classRepositoryProvider);
  return repository.getDiscoverableClasses(user.uid);
});

final createClassProvider = Provider<Future<ClassModel> Function({
  required String title,
  required String description,
  required bool isPublic,
})>((ref) {
  return ({
    required String title,
    required String description,
    required bool isPublic,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('User must be logged in to create a class');

    final repository = ref.read(classRepositoryProvider);
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return repository.createClass(
      title: title,
      description: description,
      isPublic: isPublic,
      creator: userRef,
    );
  };
});

// Check if current user is a member of a specific class
final isClassMemberProvider = StreamProvider.family<bool, String>((ref, classId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(false);

  final repository = ref.watch(classRepositoryProvider);
  return repository.isMember(user.uid, classId);
});

// Join/Leave class functions
final classActionsProvider = Provider<ClassActions>((ref) {
  return ClassActions(ref);
});

class ClassActions {
  final Ref _ref;

  ClassActions(this._ref);

  Future<void> joinClass(String classId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw Exception('User must be logged in to join a class');

    final repository = _ref.read(classRepositoryProvider);
    await repository.joinClass(userId: user.uid, classId: classId);
  }

  Future<void> leaveClass(String classId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw Exception('User must be logged in to leave a class');

    final repository = _ref.read(classRepositoryProvider);
    await repository.leaveClass(userId: user.uid, classId: classId);
  }
} 