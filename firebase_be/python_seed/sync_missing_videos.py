import firebase_admin
from firebase_admin import credentials, firestore
import csv
import os
from datetime import datetime

# Initialize Firebase if not already initialized
if not firebase_admin._apps:
    cred = credentials.Certificate('../serviceAccountKey.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def get_existing_video_ids():
    """Get all video IDs from the existing CSV file."""
    existing_ids = set()
    if os.path.exists('generated_videos.csv'):
        with open('generated_videos.csv', 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            existing_ids = {row['id'] for row in reader}
    return existing_ids

def get_firestore_videos():
    """Get all videos from Firestore that don't have a videoUrl."""
    videos_ref = db.collection('videos')
    # Query for videos where videoUrl is empty or doesn't exist
    query = videos_ref.where('metadata.videoUrl', '==', '')
    docs = query.get()
    
    videos = []
    for doc in docs:
        data = doc.to_dict()
        metadata = data.get('metadata', {})
        classification = data.get('classification', {}).get('explicit', {})
        
        # Extract the high-level subject from hashtags or use a default
        subject = "General"
        hashtags = classification.get('hashtags', [])
        if hashtags:
            subject = hashtags[0].replace('#', '')
        
        videos.append({
            'id': doc.id,
            'title': metadata.get('title', ''),
            'topic_area': classification.get('targetAudience', 'General'),
            'subject': subject
        })
    return videos

def append_to_csv(videos, filename='generated_videos.csv'):
    """Append new videos to the CSV file."""
    # Check if file exists to determine if we need to write headers
    file_exists = os.path.exists(filename)
    
    fieldnames = ['id', 'title', 'topic_area', 'subject', 'processed']
    
    with open(filename, 'a' if file_exists else 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        if not file_exists:
            writer.writeheader()
        
        for video in videos:
            video['processed'] = 'false'  # Mark as unprocessed
            writer.writerow(video)

def main():
    print("Starting video sync process...")
    
    # Get existing video IDs from CSV
    existing_ids = get_existing_video_ids()
    print(f"Found {len(existing_ids)} existing videos in CSV")
    
    # Get videos from Firestore
    all_videos = get_firestore_videos()
    print(f"Found {len(all_videos)} videos in Firestore without videoUrl")
    
    # Filter out videos that are already in the CSV
    new_videos = [v for v in all_videos if v['id'] not in existing_ids]
    print(f"Found {len(new_videos)} new videos to add to CSV")
    
    if new_videos:
        # Append new videos to CSV
        append_to_csv(new_videos)
        print(f"Successfully added {len(new_videos)} videos to CSV")
        print("\nNew videos added:")
        for video in new_videos:
            print(f"- {video['title']} (ID: {video['id']})")
    else:
        print("No new videos to add")

if __name__ == "__main__":
    main() 