const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
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
    const randomIndex = Math.floor(Math.random() * userIds.length);
    const creatorId = userIds[randomIndex];

    const now = admin.firestore.FieldValue.serverTimestamp();
    const video = {
      creator: db.doc(`users/${creatorId}`),
      metadata: {
        title: `Sample Video ${i + 1}`,
        description: `This is a description for sample video ${i + 1}.`,
        thumbnailUrl: `https://example.com/thumbnail${i + 1}.jpg`,
        videoUrl: '', // To be updated after uploading the video file to storage
        duration: 300 + i * 10,
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
    creator: db.doc(`users/${userIds[0]}`),
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
    creator: db.doc(`users/${userIds[1]}`),
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