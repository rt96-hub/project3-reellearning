from datetime import datetime, timedelta, timezone
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter
import json
import os
from dotenv import load_dotenv
from typing import Any, Dict, List
import random
# Load environment variables
load_dotenv()

# Test configuration
TEST_USER_ID = "1kkE3MKyyTTYFra4H0lkqjSUPHx2"  # Replace with an actual user ID from your database

# Initialize Firebase
cred = credentials.Certificate('../serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def generate_test_question(user_id: str, video_ids: List[str]):
    """Generate a test question for the given user and video context."""
    try:
        # Initialize Firestore
        user_ref = db.collection('users').document(user_id)
        question_ref = db.collection('questions').document()
        
        # Create test question document
        question_doc = {
            'userId': user_ref,
            'data': {
                'videoId': [db.collection('videos').document(vid) for vid in video_ids],
                'questionText': "Based on the last videos, what is the main concept you learned?",
                'options': ["Option A", "Option B", "Option C"],
                'correctAnswer': 1,
                'explanation': "Option A is correct because it relates to the core concept presented."
            },
            'createdAt': datetime.now(timezone.utc),
            'updatedAt': datetime.now(timezone.utc)
        }
        
        # Store the question in Firestore
        question_ref.set(question_doc)
        
        # get a random video id from the list
        index = random.randint(0, len(video_ids) - 1)
        video_id = video_ids[index]

        # get the video details
        video_doc = db.collection('videos').document(video_id).get()
        video_details = video_doc.to_dict()

        # video details will be used to generate the question later

        # Create a JSON-serializable version of the data
        json_safe_data = {
            'questionId': question_ref.id,
            'data': {
                'userId': user_ref.path,
                'createdAt': question_doc['createdAt'].isoformat(),
                'updatedAt': question_doc['updatedAt'].isoformat(),
                'question': {
                    'videoId': f'videos/{video_id}',  # Store the path instead of DocumentReference
                    'questionText': question_doc['data']['questionText'],
                    'options': question_doc['data']['options'],
                    'correctAnswer': question_doc['data']['correctAnswer'],
                    'explanation': question_doc['data']['explanation']
                }
            }
        }
        
        # Print the created question data
        print(json.dumps(json_safe_data, indent=2))
        
        return {
            'status': 'success',
            'questionId': question_ref.id,
            'question': {
                'videoId': f'videos/{video_id}',  # Return just the ID for simplicity
                'questionText': question_doc['data']['questionText'],
                'options': question_doc['data']['options'],
                'correctAnswer': question_doc['data']['correctAnswer'],
                'explanation': question_doc['data']['explanation']
            }
        }

    except Exception as e:
        print(f"Error generating question: {str(e)}")
        return {'error': f'Error generating question: {str(e)}'}

def get_recent_videos(user_id: str, minutes: int = 2) -> List[str]:
    """Get videos watched by the user in the last N minutes."""
    try:
        user_ref = db.collection('users').document(user_id)
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(minutes=minutes)
        
        # Query userViews collection for recent views
        recent_views = (
            db.collection('userViews')
            .where(filter=FieldFilter('userId', '==', user_ref))
            .where(filter=FieldFilter('watchedAt', '>=', start_time))
            .where(filter=FieldFilter('watchedAt', '<=', end_time))
            .get()
        )
        
        # Extract video IDs
        video_ids = []
        for view in recent_views:
            view_data = view.to_dict()
            video_ref = view_data.get('videoId')
            if video_ref:
                video_ids.append(video_ref.id)
        
        print(f"\nFound {len(video_ids)} videos watched in the last {minutes} minutes:")
        print(json.dumps(video_ids, indent=2))
        
        return video_ids

    except Exception as e:
        print(f"Error getting recent videos: {str(e)}")
        return []

def main():
    print("\nTesting In-Feed Question Generation:")
    print("-" * 30)
    
    # Get recent videos for context
    video_ids = get_recent_videos(TEST_USER_ID)
    
    if not video_ids:
        print("No recent videos found. Using test video IDs...")
        # Use some test video IDs if no recent videos found
        video_ids = ["01DUDtdTW0KYrmM5pelN", "0J7aFtdE1H4B4gy2w4UL"]  # Replace with actual video IDs from your database
    
    # Generate a test question
    result = generate_test_question(TEST_USER_ID, video_ids)
    print(f"\nQuestion Generation Result:")
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main() 