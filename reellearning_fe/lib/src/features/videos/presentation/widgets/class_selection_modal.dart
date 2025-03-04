import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'dart:math' as math;

enum InteractionType {
  like,
  bookmark
}

class ClassSelectionModal extends ConsumerStatefulWidget {
  final String videoId;
  final InteractionType interactionType;
  final Function(bool isSelected) onInteractionChanged;

  const ClassSelectionModal({
    super.key,
    required this.videoId,
    required this.interactionType,
    required this.onInteractionChanged,
  });

  @override
  ConsumerState<ClassSelectionModal> createState() => _ClassSelectionModalState();
}

class _ClassSelectionModalState extends ConsumerState<ClassSelectionModal> {
  Set<String> selectedClassIds = {};
  bool isPersonalFeedSelected = false;
  bool isLoading = true;
  String? loadingClassId; // Track which class button is loading
  bool isPersonalFeedLoading = false; // Track personal feed button loading

  @override
  void initState() {
    super.initState();
    _loadExistingInteraction();
  }

  Future<void> _loadExistingInteraction() async {
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      final collectionName = widget.interactionType == InteractionType.like 
          ? 'userLikes' 
          : 'userBookmarks';
      
      final docId = '${userId}_${widget.videoId}';
      final doc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final classIds = (data['classId'] as List<dynamic>?)?.map((ref) {
          if (ref is DocumentReference) {
            return ref.id;
          } else {
            return null;
          }
        }).whereType<String>().toSet() ?? {};
        
        setState(() {
          selectedClassIds = classIds;
          isPersonalFeedSelected = true;
          isLoading = false;
        });
      } else {
        setState(() {
          selectedClassIds = {};
          isPersonalFeedSelected = false;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading interaction: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateVideoEngagement(WriteBatch batch, bool isIncrement) async {
    final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoId);
    final videoDoc = await videoRef.get();
    final videoData = videoDoc.data() as Map<String, dynamic>;
    final engagement = videoData['engagement'] ?? {
      'likes': 0,
      'bookmarks': 0,
      'views': 0,
      'shares': 0,
      'completionRate': 0.0,
      'averageWatchTime': 0.0,
    };

    final field = widget.interactionType == InteractionType.like ? 'likes' : 'bookmarks';
    final currentCount = (engagement[field] ?? 0) as int;
    
    batch.update(videoRef, {
      'engagement': {
        ...engagement,
        field: isIncrement ? currentCount + 1 : math.max<int>(0, currentCount - 1),
      }
    });
  }

  Future<void> _updateVectorForLike(WriteBatch batch, String targetId, bool isUser, bool isAdd) async {
    if (widget.interactionType != InteractionType.like) return;

    // Get video vector and tags
    final videoDoc = await FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .get();
    final videoData = videoDoc.data() as Map<String, dynamic>;
    final videoVector = videoData['classification']?['videoVector'] as List<dynamic>?;
    final videoTags = (videoData['classification']?['explicit']?['hashtags'] as List<dynamic>?)?.cast<String>() ?? [];
    
    if (videoVector == null) return;

    // Get target vector document
    final collectionName = isUser ? 'userVectors' : 'classVectors';
    final vectorDoc = await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(targetId)
        .get();
    
    if (!vectorDoc.exists) {
      // If no vector exists, initialize with video vector and tags
      final tagPreferences = Map.fromEntries(
        videoTags.map((tag) => MapEntry(tag.toLowerCase(), 1)),
      );

      batch.set(FirebaseFirestore.instance.collection(collectionName).doc(targetId), {
        '${isUser ? 'user' : 'class'}': FirebaseFirestore.instance.collection(isUser ? 'users' : 'classes').doc(targetId),
        'vector': videoVector,
        'tagPreferences': tagPreferences,
      });
    } else {
      var existingVector = vectorDoc.data()?['vector'] as List<dynamic>?;
      final existingTagPrefs = (vectorDoc.data()?['tagPreferences'] as Map<String, dynamic>?) ?? {};
      
      if (existingVector == null && isAdd) {
        // Document exists (from onboarding) but no vector yet - initialize with this video's vector
        // and merge new tags with existing tag preferences
        final updatedTagPrefs = Map<String, num>.from(existingTagPrefs);
        for (final tag in videoTags) {
          final normalizedTag = tag.toLowerCase();
          updatedTagPrefs[normalizedTag] = (updatedTagPrefs[normalizedTag] ?? 0) + 1;
        }

        batch.update(FirebaseFirestore.instance.collection(collectionName).doc(targetId), {
          'vector': videoVector,
          'tagPreferences': updatedTagPrefs,
        });
        existingVector = videoVector;
      }
      
      if (existingVector != null) {
        // Update vector
        final updatedVector = List<num>.from(existingVector.map((e) => e as num));
        for (var i = 0; i < videoVector.length; i++) {
          if (isAdd) {
            updatedVector[i] += (videoVector[i] as num);
          } else {
            updatedVector[i] -= (videoVector[i] as num);
          }
        }

        // Update tag preferences
        final updatedTagPrefs = Map<String, num>.from(existingTagPrefs.map(
          (key, value) => MapEntry(key, (value as num))
        ));

        for (final tag in videoTags) {
          final normalizedTag = tag.toLowerCase();
          if (isAdd) {
            updatedTagPrefs[normalizedTag] = (updatedTagPrefs[normalizedTag] ?? 0) + 1;
          } else {
            final currentCount = updatedTagPrefs[normalizedTag] ?? 0;
            if (currentCount <= 1) {
              updatedTagPrefs.remove(normalizedTag);
            } else {
              updatedTagPrefs[normalizedTag] = currentCount - 1;
            }
          }
        }

        batch.update(FirebaseFirestore.instance.collection(collectionName).doc(targetId), {
          'vector': updatedVector,
          'tagPreferences': updatedTagPrefs,
        });
      }
    }
  }

  Future<void> _handleInteractionToggle(String classId) async {
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;

    setState(() => loadingClassId = classId);

    try {
      final collectionName = widget.interactionType == InteractionType.like 
          ? 'userLikes' 
          : 'userBookmarks';
      
      final docId = '${userId}_${widget.videoId}';
      final docRef = FirebaseFirestore.instance.collection(collectionName).doc(docId);
      
      final isSelected = selectedClassIds.contains(classId);
      final classRef = FirebaseFirestore.instance.collection('classes').doc(classId);

      if (!isSelected) {
        final docSnapshot = await docRef.get();
        final isNewDocument = !docSnapshot.exists;

        final batch = FirebaseFirestore.instance.batch();

        batch.set(docRef, {
          'userId': FirebaseFirestore.instance.collection('users').doc(userId),
          'videoId': FirebaseFirestore.instance.collection('videos').doc(widget.videoId),
          'classId': isNewDocument ? [classRef] : FieldValue.arrayUnion([classRef]),
          if (widget.interactionType == InteractionType.like)
            'likedAt': FieldValue.serverTimestamp()
          else
            'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (isNewDocument) {
          await _updateVideoEngagement(batch, true);
          // Add vector update for user only if this is their first like
          if (widget.interactionType == InteractionType.like) {
            await _updateVectorForLike(batch, userId, true, true);    // user vector
          }
        }

        // Always update class vector when adding a class to likes
        if (widget.interactionType == InteractionType.like) {
          await _updateVectorForLike(batch, classId, false, true);  // class vector
        }

        await batch.commit();

        setState(() {
          selectedClassIds.add(classId);
          isPersonalFeedSelected = true;
          loadingClassId = null;
        });
        if (isNewDocument) {
          widget.onInteractionChanged(true);
        }
      } else {
        final batch = FirebaseFirestore.instance.batch();
        
        batch.update(docRef, {
          'classId': FieldValue.arrayRemove([classRef]),
        });

        // Get current state to check if this is the last class and if we need to update user vector
        final docSnapshot = await docRef.get();
        final currentClassIds = (docSnapshot.data()?['classId'] as List<dynamic>?)?.length ?? 0;
        
        if (widget.interactionType == InteractionType.like) {
          // Always update class vector when removing a class from likes
          await _updateVectorForLike(batch, classId, false, false);  // class vector
          
          // Only update user vector if this was the last class
          if (currentClassIds <= 1) {
            await _updateVectorForLike(batch, userId, true, false);    // user vector
          }
        }

        await batch.commit();

        setState(() {
          selectedClassIds.remove(classId);
          if (selectedClassIds.isEmpty) {
            isPersonalFeedSelected = true;
          }
          loadingClassId = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => loadingClassId = null);
    }
  }

  Future<void> _handlePersonalFeedToggle() async {
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;

    setState(() => isPersonalFeedLoading = true);

    try {
      final collectionName = widget.interactionType == InteractionType.like 
          ? 'userLikes' 
          : 'userBookmarks';
      
      final docId = '${userId}_${widget.videoId}';
      final docRef = FirebaseFirestore.instance.collection(collectionName).doc(docId);

      if (!isPersonalFeedSelected) {
        final batch = FirebaseFirestore.instance.batch();

        batch.set(docRef, {
          'userId': FirebaseFirestore.instance.collection('users').doc(userId),
          'videoId': FirebaseFirestore.instance.collection('videos').doc(widget.videoId),
          'classId': [],
          if (widget.interactionType == InteractionType.like)
            'likedAt': FieldValue.serverTimestamp()
          else
            'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _updateVideoEngagement(batch, true);
        
        // Add vector update for personal feed likes
        if (widget.interactionType == InteractionType.like) {
          await _updateVectorForLike(batch, userId, true, true);
        }

        await batch.commit();

        setState(() {
          isPersonalFeedSelected = true;
          selectedClassIds.clear();
          isPersonalFeedLoading = false;
        });
        widget.onInteractionChanged(true);
      } else if (selectedClassIds.isEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        batch.delete(docRef);
        await _updateVideoEngagement(batch, false);
        
        // Remove vector contribution when removing from personal feed
        if (widget.interactionType == InteractionType.like) {
          await _updateVectorForLike(batch, userId, true, false);
        }

        await batch.commit();

        setState(() {
          isPersonalFeedSelected = false;
          isPersonalFeedLoading = false;
        });
        widget.onInteractionChanged(false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => isPersonalFeedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Center(child: Text('User not authenticated'));
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.interactionType == InteractionType.like ? 'Like' : 'Bookmark'} for Classes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('classMembership')
                    .where('userId', isEqualTo: FirebaseFirestore.instance.collection('users').doc(user.uid))
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final memberships = snapshot.data!.docs;

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // Personal Feed Row - Moved to top and always visible
                        ListTile(
                          leading: IconButton(
                            icon: Icon(
                              widget.interactionType == InteractionType.like
                                  ? (isPersonalFeedSelected ? Icons.favorite : Icons.favorite_border)
                                  : (isPersonalFeedSelected ? Icons.bookmark : Icons.bookmark_border),
                              color: widget.interactionType == InteractionType.like && isPersonalFeedSelected
                                  ? Colors.red
                                  : null,
                            ),
                            onPressed: isPersonalFeedLoading ? null : _handlePersonalFeedToggle,
                          ),
                          title: const Text('Personal Feed'),
                          subtitle: Text(
                            widget.interactionType == InteractionType.like
                                ? 'Like without class context'
                                : 'Bookmark without class context'
                          ),
                        ),
                        if (memberships.isNotEmpty) ...[
                          const Divider(height: 32),
                          ...memberships.where((doc) {
                            final membership = doc.data() as Map<String, dynamic>;
                            return membership['role'] == 'curator';
                          }).map((doc) {
                            final membership = doc.data() as Map<String, dynamic>;
                            final classRef = membership['classId'] as DocumentReference;
                            
                            return FutureBuilder<DocumentSnapshot>(
                              future: classRef.get(),
                              builder: (context, AsyncSnapshot<DocumentSnapshot> classSnapshot) {
                                if (!classSnapshot.hasData) {
                                  return const ListTile(
                                    leading: SizedBox(
                                      width: 48,
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                    title: Text('Loading...'),
                                  );
                                }

                                final classData = classSnapshot.data!.data() as Map<String, dynamic>;
                                return ListTile(
                                  leading: IconButton(
                                    icon: Icon(
                                      widget.interactionType == InteractionType.like
                                          ? (selectedClassIds.contains(classRef.id) ? Icons.favorite : Icons.favorite_border)
                                          : (selectedClassIds.contains(classRef.id) ? Icons.bookmark : Icons.bookmark_border),
                                      color: widget.interactionType == InteractionType.like && selectedClassIds.contains(classRef.id)
                                          ? Colors.red
                                          : null,
                                    ),
                                    onPressed: loadingClassId == classRef.id ? null : () => _handleInteractionToggle(classRef.id),
                                  ),
                                  title: Row(
                                    children: [
                                      if (classData['thumbnail'] != null && classData['thumbnail'].isNotEmpty)
                                        CircleAvatar(
                                          backgroundImage: NetworkImage(classData['thumbnail']),
                                          radius: 16,
                                        )
                                      else
                                        const CircleAvatar(
                                          child: Icon(Icons.class_),
                                          radius: 16,
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(classData['title'] ?? 'Unnamed Class'),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    widget.interactionType == InteractionType.like
                                        ? 'Like for this class'
                                        : 'Bookmark for this class'
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
