import os
from collections import Counter
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Firebase if not already initialized
if not firebase_admin._apps:
    cred = credentials.Certificate('../serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
db = firestore.client()

def get_all_video_hashtags():
    """Fetch all hashtags from all videos in the videos collection."""
    videos_ref = db.collection('videos')
    all_hashtags = []
    
    try:
        # Stream all video documents
        docs = videos_ref.stream()
        
        for doc in docs:
            video_data = doc.to_dict()
            # Access the hashtags array using the correct path
            hashtags = video_data.get('classification', {}).get('explicit', {}).get('hashtags', [])
            all_hashtags.extend(hashtags)
        
        return all_hashtags
    except Exception as e:
        print(f"Error fetching video hashtags: {e}")
        return []

def create_tags_collection(hashtags):
    """Create or update the videoTags collection with tag counts."""
    # Count occurrences of each tag
    tag_counts = Counter(hashtags)
    
    # Create a batch write
    batch = db.batch()
    tags_ref = db.collection('videoTags')
    
    try:
        # Add each tag to the batch
        for tag, count in tag_counts.items():
            # Create a document with the tag as the ID
            doc_ref = tags_ref.document(tag.lower().replace('#', '').replace(' ', '_'))
            batch.set(doc_ref, {
                'tag': tag,
                'count': count
            })
        
        # Commit the batch
        batch.commit()
        print(f"Successfully created/updated {len(tag_counts)} tags")
        
        # Print some statistics
        print("\nTop 10 most used tags:")
        for tag, count in sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
            print(f"{tag}: {count} videos")
            
    except Exception as e:
        print(f"Error creating tags collection: {e}")

def main():
    print("Fetching video hashtags...")
    hashtags = get_all_video_hashtags()
    
    if not hashtags:
        print("No hashtags found in videos collection")
        return
    
    print(f"\nFound {len(hashtags)} total hashtag occurrences")
    print(f"Found {len(set(hashtags))} unique tags")
    
    print("\nCreating tags collection...")
    create_tags_collection(hashtags)

if __name__ == "__main__":
    main()
