import firebase_admin
from firebase_admin import credentials, firestore
import random

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('../serviceAccountKey.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def get_all_users():
    """Fetch all users from the users collection."""
    users_ref = db.collection('users')
    users = users_ref.stream()
    return [user.id for user in users]

def get_all_videos():
    """Fetch all videos that don't have a creator assigned."""
    videos_ref = db.collection('videos')
    # Query for videos where creator is None or doesn't exist
    videos = videos_ref.stream()
    return [video for video in videos]

def assign_creators():
    """Assign random users as creators to videos."""
    print("Fetching users...")
    user_ids = get_all_users()
    
    if not user_ids:
        print("No users found in the database!")
        return
    
    print(f"Found {len(user_ids)} users")
    
    print("Fetching videos...")
    videos = get_all_videos()
    video_count = 0
    
    # Process in batches to respect Firestore limits
    batch = db.batch()
    batch_size = 0
    max_batch_size = 500  # Firestore batch limit
    
    for video in videos:
        # Create a reference to a random user
        random_user_id = random.choice(user_ids)
        user_ref = db.collection('users').document(random_user_id)
        
        # Update the video's creator field with the user reference
        video_ref = db.collection('videos').document(video.id)
        batch.update(video_ref, {
            'creator': user_ref,
            'metadata.updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        batch_size += 1
        video_count += 1
        
        # If we've reached the batch limit, commit and start a new batch
        if batch_size >= max_batch_size:
            print(f"Committing batch of {batch_size} updates...")
            batch.commit()
            batch = db.batch()
            batch_size = 0
    
    # Commit any remaining updates
    if batch_size > 0:
        print(f"Committing final batch of {batch_size} updates...")
        batch.commit()
    
    print(f"\nCompleted! Assigned creators to {video_count} videos")

if __name__ == "__main__":
    print("Starting creator assignment process...")
    assign_creators()
    print("Process completed!") 