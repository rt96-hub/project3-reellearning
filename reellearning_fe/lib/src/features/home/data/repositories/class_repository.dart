import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_model.dart';

class ClassRepository {
  final FirebaseFirestore _firestore;

  ClassRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Create a new class
  Future<ClassModel> createClass({
    required String title,
    required String description,
    required bool isPublic,
    required DocumentReference creator,
  }) async {
    final now = DateTime.now();
    final classData = {
      'title': title,
      'description': description,
      'isPublic': isPublic,
      'thumbnail': '', // TODO: Implement thumbnail upload
      'creator': creator,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'memberCount': 1, // Start with 1 member (the creator)
    };

    // Create the class document
    final docRef = await _firestore.collection('classes').add(classData);

    // Add creator as a member
    await _firestore.collection('classMembership').doc('${creator.id}_${docRef.id}').set({
      'userId': creator,
      'classId': docRef,
      'joinedAt': Timestamp.fromDate(now),
      'role': 'curator',
    });

    return ClassModel.fromMap(docRef.id, {
      ...classData,
      'createdAt': classData['createdAt'] as Timestamp,
      'updatedAt': classData['updatedAt'] as Timestamp,
    });
  }

  // Join a class
  Future<void> joinClass({
    required String userId,
    required String classId,
  }) async {
    final batch = _firestore.batch();
    final now = Timestamp.now();

    // Create membership document
    final membershipRef = _firestore.collection('classMembership').doc('${userId}_$classId');
    batch.set(membershipRef, {
      'userId': _firestore.collection('users').doc(userId),
      'classId': _firestore.collection('classes').doc(classId),
      'joinedAt': now,
      'role': 'follower',
    });

    // Increment member count
    final classRef = _firestore.collection('classes').doc(classId);
    batch.update(classRef, {
      'memberCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Leave a class
  Future<void> leaveClass({
    required String userId,
    required String classId,
  }) async {
    final batch = _firestore.batch();

    // Delete membership document
    final membershipRef = _firestore.collection('classMembership').doc('${userId}_$classId');
    batch.delete(membershipRef);

    // Decrement member count
    final classRef = _firestore.collection('classes').doc(classId);
    batch.update(classRef, {
      'memberCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  // Check if user is a member of a class
  Stream<bool> isMember(String userId, String classId) {
    return _firestore
        .collection('classMembership')
        .doc('${userId}_$classId')
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  // Get classes created by a user
  Stream<List<ClassModel>> getCreatedClasses(String userId) {
    final userRef = _firestore.collection('users').doc(userId);
    return _firestore
        .collection('classes')
        .where('creator', isEqualTo: userRef)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClassModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get classes a user is a member of
  Stream<List<ClassModel>> getJoinedClasses(String userId) {
    return _firestore
        .collection('classMembership')
        .where('userId', isEqualTo: _firestore.collection('users').doc(userId))
        .snapshots()
        .asyncMap((snapshot) async {
      final classIds = snapshot.docs.map((doc) => doc.data()['classId'] as DocumentReference).toList();
      if (classIds.isEmpty) return [];

      final classesSnapshot = await _firestore
          .collection('classes')
          .where(FieldPath.documentId, whereIn: classIds.map((ref) => ref.id).toList())
          .get();

      return classesSnapshot.docs
          .map((doc) => ClassModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Get discoverable (public) classes
  Stream<List<ClassModel>> getDiscoverableClasses(String userId) {
    // Get the classes the user is a member of
    return _firestore
        .collection('classMembership')
        .where('userId', isEqualTo: _firestore.collection('users').doc(userId))
        .snapshots()
        .asyncMap((membershipSnapshot) async {
      // Get the IDs of classes the user is already a member of
      final memberClassIds = membershipSnapshot.docs
          .map((doc) => (doc.data()['classId'] as DocumentReference).id)
          .toSet();

      // Get a random sample of public classes the user isn't a member of
      // TODO: In the future, this will be replaced with a more sophisticated recommendation system
      // that takes into account user interests, class popularity, and other metrics
      final classesSnapshot = await _firestore
          .collection('classes')
          .where('isPublic', isEqualTo: true)
          .limit(50)
          .get();

      final availableClasses = classesSnapshot.docs
          .where((doc) => !memberClassIds.contains(doc.id))
          .map((doc) => ClassModel.fromMap(doc.id, doc.data()))
          .toList();

      // Shuffle and take first 20
      availableClasses.shuffle();
      return availableClasses.take(20).toList();
    });
  }
} 