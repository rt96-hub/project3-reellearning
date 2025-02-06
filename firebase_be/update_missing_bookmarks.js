const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateMissingBookmarks() {
  const videosRef = db.collection('videos');
  
  try {
    // Get all video documents
    const snapshot = await videosRef.get();
    
    // Keep track of how many documents we update
    let updateCount = 0;
    
    // Batch writes for better performance
    const batches = [];
    let batch = db.batch();
    let operationCount = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Check if the document is missing the bookmarks field
      if (!data.engagement?.bookmarks) {
        batch.update(doc.ref, {
          'engagement.bookmarks': 0
        });
        
        operationCount++;
        updateCount++;
        
        // Firebase has a limit of 500 operations per batch
        if (operationCount === 499) {
          batches.push(batch);
          batch = db.batch();
          operationCount = 0;
        }
      }
    }
    
    // Push the last batch if it has any operations
    if (operationCount > 0) {
      batches.push(batch);
    }
    
    // Commit all batches
    await Promise.all(batches.map(batch => batch.commit()));
    
    console.log(`Successfully updated ${updateCount} documents`);
    
  } catch (error) {
    console.error('Error updating documents:', error);
  } finally {
    // Exit the process
    process.exit(0);
  }
}

updateMissingBookmarks();