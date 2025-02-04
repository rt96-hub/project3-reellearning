# Sample Data Generation, Uploading, and Video Rendering Checklist

Below is a checklist outlining the steps needed to generate sample users, videos, and classes from your simple Firestore schema. Additionally, you'll find guidance on how to add video URLs to Firebase Storage and render the videos in your Flutter application.

- [ ] **Set Up a Node.js Script for Data Generation**  
  - Create a script (e.g., `generateSampleData.js`) that uses the Firebase Admin SDK to:
    - Generate 5 sample users.
    - Generate 10 sample video documents.
    - Generate 2 class documents (one for "Math" and one for "History").
  - Use the sample functions provided below.

```
const admin = require('firebase-admin');

// Initialize Firebase Admin (ensure your serviceAccountKey.json is configured properly)
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  // Optionally include your storage bucket config if needed
  // storageBucket: 'your-project-id.appspot.com'
});
const db = admin.firestore();

// Function to generate 5 sample users
async function generateUsers() {
  const sampleUsers = [
    {
      displayName: 'Alice',
      email: 'alice@example.com',
      avatarUrl: 'https://example.com/avatar1.png',
      biography: 'Loves learning!',
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      displayName: 'Bob',
      email: 'bob@example.com',
      avatarUrl: 'https://example.com/avatar2.png',
      biography: 'Math genius.',
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      displayName: 'Charlie',
      email: 'charlie@example.com',
      avatarUrl: 'https://example.com/avatar3.png',
      biography: 'History buff.',
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      displayName: 'Diana',
      email: 'diana@example.com',
      avatarUrl: 'https://example.com/avatar4.png',
      biography: 'Science lover.',
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      displayName: 'Evan',
      email: 'evan@example.com',
      avatarUrl: 'https://example.com/avatar5.png',
      biography: 'Always curious.',
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
    }
  ];

  const userIds = [];
  for (const user of sampleUsers) {
    const userDoc = await db.collection('users').add({ profile: user });
    console.log('Created user with ID:', userDoc.id);
    userIds.push(userDoc.id);
  }
  return userIds;
}

// Function to generate 10 sample videos
async function generateVideos(userIds) {
  for (let i = 0; i < 10; i++) {
    // Randomly select a creator from the userIds array
    const randomIndex = Math.floor(Math.random() * userIds.length);
    const creatorId = userIds[randomIndex];

    // Define sample video document
    const now = admin.firestore.FieldValue.serverTimestamp();
    const video = {
      creator: db.doc(`users/${creatorId}`),
      metadata: {
        title: `Sample Video ${i + 1}`,
        description: `This is a description for sample video ${i + 1}.`,
        thumbnailUrl: `https://example.com/thumbnail${i + 1}.jpg`,
        videoUrl: '', // To be updated after uploading the video file to storage
        duration: 300 + i * 10, // Example: duration in seconds
        uploadedAt: now,
        updatedAt: now,
      },
      classification: {
        explicit: {
          hashtags: ['#sample', '#video'],
          description: `Explicit description for video ${i + 1}`,
          targetAudience: 'general',
          prerequisites: [],
        },
      },
      engagement: {
        views: 0,
        likes: 0,
        shares: 0,
        completionRate: 0,
        averageWatchTime: 0,
      },
    };

    const videoDoc = await db.collection('videos').add(video);
    console.log('Created video with ID:', videoDoc.id);
  }
}

// Function to generate 2 classes (Math and History)
async function generateClasses(userIds) {
  const now = admin.firestore.FieldValue.serverTimestamp();

  const mathClass = {
    creator: db.doc(`users/${userIds[0]}`), // For example, using the first user as creator for Math
    metadata: {
      title: 'Math',
      description: 'A class for Mathematics enthusiasts.',
      createdAt: now,
      updatedAt: now,
      isPublic: true,
      thumbnail: 'https://example.com/math-thumbnail.jpg',
    },
  };

  const historyClass = {
    creator: db.doc(`users/${userIds[1]}`), // For example, using the second user as creator for History
    metadata: {
      title: 'History',
      description: 'A class exploring historical events.',
      createdAt: now,
      updatedAt: now,
      isPublic: true,
      thumbnail: 'https://example.com/history-thumbnail.jpg',
    },
  };

  const mathDoc = await db.collection('classes').add(mathClass);
  console.log('Created class "Math" with ID:', mathDoc.id);

  const historyDoc = await db.collection('classes').add(historyClass);
  console.log('Created class "History" with ID:', historyDoc.id);
}

// Main function to generate all sample data
async function main() {
  try {
    const userIds = await generateUsers();
    await generateVideos(userIds);
    await generateClasses(userIds);
    console.log('Sample data generated successfully.');
  } catch (error) {
    console.error('Error generating sample data:', error);
  }
}

main();
```

- [ ] **Run the Data Generation Script**  
  - Execute the script in your terminal (e.g., `node generateSampleData.js`) to populate Firestore with sample users, videos, and classes.

- [ ] **Upload Video Files to Firebase Storage**  
  - Upload your video files to Firebase Storage either using the Firebase Console or programmatically with the Firebase SDK.
  - After uploading, obtain the download URLs for each video.
  - Update the corresponding Firestore video document:
  
```
async function updateVideoUrl(videoId, downloadUrl) {
  await db.collection('videos').doc(videoId).update({
    "metadata.videoUrl": downloadUrl,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

// Example usage:
const videoId = 'your-video-id'; // Replace with the actual video document ID
const downloadUrl = 'https://firebasestorage.googleapis.com/...'; // Replace with the obtained URL
updateVideoUrl(videoId, downloadUrl);
```

- [ ] **Render Videos in Your Flutter Application**  
  - Retrieve video documents from Firestore in your Flutter app. For example, you can use a `StreamBuilder` to listen to changes in the "videos" collection.
  - Use the video URL from each document to play the video. You can use a package such as `video_player` (and optionally `chewie` for a wrapper) to render videos.

Example Flutter widget snippet:

```
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

class VideoListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sample Videos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('videos').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final videos = snapshot.data!.docs;
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final data = videos[index].data() as Map<String, dynamic>;
              final videoUrl = data['metadata']['videoUrl'] as String;
              return ListTile(
                title: Text(data['metadata']['title']),
                subtitle: Text(data['metadata']['description']),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(videoUrl: videoUrl),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  VideoPlayerScreen({required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Player')),
      body: Center(
        child: _controller.value.isInitialized 
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : CircularProgressIndicator(),
      ),
    );
  }
}
```

- [ ] **Test the Entire Flow**  
  - Run your Node.js script to generate Firestore data.
  - Upload your video files to Storage and update Firestore with the download URLs.
  - Launch your Flutter app and verify that videos are retrieved from Firestore and played correctly.

This checklist should help you generate sample data, integrate Firebase Storage with video uploads, and render the videos smoothly in your Flutter application.