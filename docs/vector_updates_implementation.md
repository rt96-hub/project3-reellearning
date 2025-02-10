# Vector Updates Implementation Guide

## Overview
This guide details how to add video vector updates to the existing like/bookmark functionality in the class selection modal. The goal is to maintain the existing UI behavior while adding vector updates for recommendation system functionality.

## Alternative: Using Separate Vector Collections

Instead of storing vectors directly on user documents, we can use separate collections for better organization and performance:

```
collections/
  ├── userVectors/
  │   └── {userId}/           # Same ID as user document
  │       ├── user: reference  # Reference to user
  │       └── vector: number[]
  │
  └── classVectors/          # Optional: could do the same for classes
      └── {classId}/
          ├── class: reference  # Reference to class
          └── vector: number[]
```

### Benefits
1. Keeps user documents lean (especially important for frequently accessed data)
2. Allows for easier vector-specific operations and queries
3. Better separation of concerns
4. More efficient updates (don't need to read/write entire user document)

## Modified Vector Update Function
```dart
Future<void> _updateVectorForLike(WriteBatch batch, String targetId, bool isUser, bool isAdd) async {
  if (widget.interactionType != InteractionType.like) return;

  // Get video vector
  final videoDoc = await FirebaseFirestore.instance
      .collection('videos')
      .doc(widget.videoId)
      .get();
  final videoData = videoDoc.data() as Map<String, dynamic>;
  final videoVector = videoData['classification']?['videoVector'] as List<dynamic>?;
  
  if (videoVector == null) return;

  // Get target vector document
  final collectionName = isUser ? 'userVectors' : 'classVectors';
  final vectorDoc = await FirebaseFirestore.instance
      .collection(collectionName)
      .doc(targetId)
      .get();
  
  if (!vectorDoc.exists) {
    // If no vector exists, initialize with video vector
    batch.set(FirebaseFirestore.instance.collection(collectionName).doc(targetId), {
      '${isUser ? 'user' : 'class'}Id': targetId,
      'vector': videoVector,
    });
  } else {
    final existingVector = vectorDoc.data()?['vector'] as List<dynamic>?;
    if (existingVector != null) {
      final updatedVector = List<num>.from(existingVector.map((e) => e as num));
      for (var i = 0; i < videoVector.length; i++) {
        if (isAdd) {
          updatedVector[i] += (videoVector[i] as num);
        } else {
          updatedVector[i] -= (videoVector[i] as num);
        }
      }
      batch.update(FirebaseFirestore.instance.collection(collectionName).doc(targetId), {
        'vector': updatedVector,
      });
    }
  }
}
```

## Usage in Existing Functions

### In _handleInteractionToggle:
```dart
if (!isSelected) {
  // ... existing code ...
  
  if (isNewDocument) {
    await _updateVideoEngagement(batch, true);
    // Add vector updates for new likes only
    if (widget.interactionType == InteractionType.like) {
      await _updateVectorForLike(batch, classId, false, true);  // class vector
      await _updateVectorForLike(batch, userId, true, true);    // user vector
    }
  }
}
```

### In _handlePersonalFeedToggle:
```dart
if (!isPersonalFeedSelected) {
  // ... existing code ...
  
  if (widget.interactionType == InteractionType.like) {
    await _updateVectorForLike(batch, userId, true, true);
  }
}
```

## Firestore Rules Updates
Add these rules to secure the new collections:

```javascript
match /userVectors/{userId} {
  allow read: if true;  // Anyone can read vectors for recommendations
  allow write: if request.auth != null && 
               request.auth.uid == userId;  // Only user can update their vector
}

match /classVectors/{classId} {
  allow read: if true;
  allow write: if request.auth != null && 
               exists(/databases/$(database)/documents/classMembership/$(request.auth.uid)_$(classId)) &&
               get(/databases/$(database)/documents/classMembership/$(request.auth.uid)_$(classId)).data.role == 'curator';
}
```

## Migration Considerations

1. **Initial Setup**
   - Create the new collections
   - Add appropriate indexes if needed
   - Set up security rules

2. **Data Migration**
   If you have existing vectors in user/class documents:
   ```dart
   Future<void> migrateVectors() async {
     // Migrate user vectors
     final users = await FirebaseFirestore.instance.collection('users').get();
     final batch = FirebaseFirestore.instance.batch();
     
     for (final user in users.docs) {
       final vector = user.data()['userVector'];
       if (vector != null) {
         batch.set(
           FirebaseFirestore.instance.collection('userVectors').doc(user.id),
           {'userId': user.id, 'vector': vector}
         );
       }
     }
     
     await batch.commit();
   }
   ```

## Advantages of This Approach

1. **Performance**
   - Smaller documents to read/write
   - Can update vectors without touching main documents
   - Better caching potential

2. **Scalability**
   - Easier to manage vector-specific operations
   - Can add vector-specific metadata without cluttering main documents
   - Better for analytics and vector-specific queries

3. **Maintenance**
   - Clearer separation of concerns
   - Easier to modify vector logic independently
   - Simpler to debug vector-related issues

The rest of the implementation rules and testing checklist remain the same. 