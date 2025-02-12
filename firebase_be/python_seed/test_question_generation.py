from datetime import datetime, timedelta, timezone
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter
import json
import os
from dotenv import load_dotenv
from typing import Any, Dict, List
import random
from openai import OpenAI
from pydantic import BaseModel, Field
# Load environment variables
load_dotenv()

# Test configuration
TEST_USER_ID = "1kkE3MKyyTTYFra4H0lkqjSUPHx2"  # Replace with an actual user ID from your database

# Initialize Firebase
cred = credentials.Certificate('../serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

class QuestionResponse(BaseModel):
    questionText: str = Field(..., description="The question text that tests understanding of the video content")
    options: List[str] = Field(..., description="Four possible answer options, with the first one being correct")
    explanation: str = Field(..., description="Detailed explanation of why the correct answer is right")

def generate_test_question(user_id: str, video_ids: List[str]):
    """Generate a test question for the given user and video context."""
    try:
        # Initialize OpenAI client
        openai_api_key = os.getenv('OPENAI_API_KEY')
        if not openai_api_key:
            print("Error: OPENAI_API_KEY not found in environment variables")
            return
    
        client = OpenAI(api_key=openai_api_key)

        # Initialize Firestore
        user_ref = db.collection('users').document(user_id)
        question_ref = db.collection('questions').document()
                
        # get a random video id from the list
        index = random.randint(0, len(video_ids) - 1)
        video_id = video_ids[index]

        # get the video details
        video_doc = db.collection('videos').document(video_id).get()
        video_details = {
            'title': video_doc.to_dict()['metadata']['title'],
            'description': video_doc.to_dict()['metadata']['description'],
            'transcript': video_doc.to_dict()['metadata']['transcript'],
            'description2': video_doc.to_dict()['classification']['explicit']['description'],
        }

        # video details will be used to generate the question later
        print(f"Video details: {json.dumps(video_details, indent=2)}")

        # generate the question
        question = generate_question_from_video(client, video_details)
        print(f"Question: {json.dumps(question, indent=2)}")


        # Create test question document
        question_doc = {
            'userId': user_ref,
            'data': {
                'videoId': f'videos/{video_id}',
                'questionText': question['questionText'],
                'options': question['options'],
                'correctAnswer': question['correctAnswer'],
                'explanation': question['explanation']
            },
            'createdAt': datetime.now(timezone.utc),
            'updatedAt': datetime.now(timezone.utc)
        }
        
        # Store the question in Firestore
        question_ref.set(question_doc)

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

def generate_question_from_video(client: OpenAI, video_details: Dict) -> dict:
    """
    Generate a question based on the video content using OpenAI.
    
    Args:
        client: OpenAI client instance
        video_details: Dictionary containing video information (title, description, transcript, etc.)
        
    Returns:
        dict: Generated question data including:
            - questionText: str
            - options: List[str]
            - explanation: str
    """
    prompt = f"""Based on the following video content, generate an educational question that tests the viewer's understanding.
    
Video Title: {video_details['title']}
Video Description: {video_details['description']}
Video Transcript: {video_details['transcript']}
Additional Context: {video_details['description2']}

Generate a multiple-choice question that:
1. Tests comprehension of the main concepts
2. Has 4 options where the FIRST option is ALWAYS the correct answer
3. Includes a clear explanation of why the correct answer is right
4. Ensures wrong options are plausible but clearly incorrect
5. Uses clear, unambiguous language
6. Mention the video title in the question
"""

    try:
        completion = client.beta.chat.completions.parse(
            model="gpt-4o-mini-2024-07-18",
            messages=[
                {"role": "system", "content": "You are an expert educational content creator, skilled at generating clear, unambiguous multiple choice questions that test understanding."},
                {"role": "user", "content": prompt}
            ],
            response_format=QuestionResponse
        )
        
        # Get the response data
        response_data = completion.choices[0].message.parsed.model_dump()
        
        print(f"Response data: {json.dumps(response_data, indent=2)}")
        # Shuffle options and update correct answer index
        options = response_data['options']
        correct_option = options[0]  # Save the correct answer (which was first)
        random.shuffle(options)  # Shuffle all options
        correct_answer = options.index(correct_option)  # Find new index of correct answer
        
        # Return shuffled data
        return {
            'questionText': response_data['questionText'],
            'options': options,
            'correctAnswer': correct_answer,
            'explanation': response_data['explanation']
        }

    except Exception as e:
        print(f"Error in OpenAI question generation: {str(e)}")
        # Return the placeholder as fallback
        return {
            'questionText': "What is the main topic discussed in this video?",
            'options': [
                "Placeholder option A",
                "Placeholder option B",
                "Placeholder option C",
                "Placeholder option D"
            ],
            'correctAnswer': 0,
            'explanation': "This is a placeholder explanation for the correct answer."
        }

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