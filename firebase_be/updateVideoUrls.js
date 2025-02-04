const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function getAllVideoIds() {
  const videosSnapshot = await db.collection('videos').get();
  const videoIds = [];
  
  videosSnapshot.forEach(doc => {
    videoIds.push(doc.id);
  });

  return videoIds;
}

async function updateVideoUrls() {
  try {
    const videoIds = await getAllVideoIds();
    
    for (let i = 0; i < videoIds.length; i++) {
      const videoId = videoIds[i];
      const videoUrl = `gs://reellearning-prj3.firebasestorage.app/videos/sample${i + 1}.mp4`;
      
      await db.collection('videos').doc(videoId).update({
        'metadata.videoUrl': videoUrl,
        'metadata.updatedAt': admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Updated video ${videoId} with URL: ${videoUrl}`);
    }
    
    console.log('All videos updated successfully');
  } catch (error) {
    console.error('Error updating videos:', error);
  }
}

updateVideoUrls();

