from datetime import datetime, timedelta, timezone
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter
import json
import os
from dotenv import load_dotenv
from openai import OpenAI
from typing import Any, Dict

# Load environment variables
load_dotenv()

# Test configuration
TEST_USER_ID = "1kkE3MKyyTTYFra4H0lkqjSUPHx2"  # Replace with an actual user ID from your database
TEST_CLASS_ID = "bcBdtl9X26TPNlUabqlV"  # Replace with an actual class ID from your database

# Use UTC timestamps
START_TIME = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
END_TIME = datetime.now(timezone.utc).isoformat()

# Initialize OpenAI client
client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Initialize Firebase
cred = credentials.Certificate('../serviceAccountKey.json')

firebase_admin.initialize_app(cred)
db = firestore.client()

def generate_user_report(user_id: str, start_time: str, end_time: str, report_type: str = 'custom'):  
    try:
        # Initialize Firestore
        user_ref = db.collection('users').document(user_id)
        
        # Check for in-progress reports
        in_progress_reports = (
            db.collection('userProgressReports')
            .where(filter=FieldFilter('userId', '==', user_ref))
            .where(filter=FieldFilter('status', '==', 'in_progress'))
            .limit(1)
            .get()
        )
        
        if len(in_progress_reports) > 0:
            return {'error': 'A report is already being generated for this user', 'reportId': in_progress_reports[0].id}
        
        # Instead of creating a new document, we'll simulate the ID
        simulated_report_id = "simulated_user_report_123"
        
        # Create initial report data
        report_data = {
            'userId': user_ref,
            'createdAt': datetime.now(timezone.utc),
            'startDate': datetime.fromisoformat(start_time),
            'endDate': datetime.fromisoformat(end_time),
            'type': report_type,
            'status': 'in_progress'
        }

        print(json.dumps({
            'reportId': simulated_report_id,
            'data': {
                'userId': user_ref.path,
                'createdAt': report_data['createdAt'].isoformat(),
                'startDate': report_data['startDate'].isoformat(),
                'endDate': report_data['endDate'].isoformat(),
                'type': report_type,
                'status': 'in_progress'
            }
        }, indent=2))

        try:
            # Query data for the time period
            start_date = datetime.fromisoformat(start_time).replace(tzinfo=timezone.utc)
            end_date = datetime.fromisoformat(end_time).replace(tzinfo=timezone.utc)
            
            # Get videos watched in time period
            videos_watched_docs = (
                db.collection('userViews')
                .where(filter=FieldFilter('userId', '==', user_ref))
                .where(filter=FieldFilter('watchedAt', '>=', start_date))
                .where(filter=FieldFilter('watchedAt', '<=', end_date))
            ).get()
            videos_watched = len(videos_watched_docs)
            
            # Get videos liked in time period
            videos_liked_docs = (
                db.collection('userLikes')
                .where(filter=FieldFilter('userId', '==', user_ref))
                .where(filter=FieldFilter('likedAt', '>=', start_date))
                .where(filter=FieldFilter('likedAt', '<=', end_date))
            ).get()
            videos_liked = len(videos_liked_docs)
            
            # Get the full video details for liked videos
            liked_video_refs = [doc.get('videoId') for doc in videos_liked_docs]
            liked_videos = []
            for video_ref in liked_video_refs:
                video_doc = video_ref.get()
                if video_doc.exists:
                    video_data = video_doc.to_dict()
                    liked_videos.append({
                        'id': video_doc.id,
                        'title': video_data['metadata']['title'],
                        'description': video_data['metadata']['description'],
                        'description2': video_data['classification']['explicit']['description'],
                        'transcript': video_data['metadata'].get('transcript', ''),
                        'hashtags': video_data['classification']['explicit'].get('hashtags', [])
                    })

            # Get videos bookmarked in time period
            videos_bookmarked_docs = (
                db.collection('userBookmarks')
                .where(filter=FieldFilter('userId', '==', user_ref))
                .where(filter=FieldFilter('addedAt', '>=', start_date))
                .where(filter=FieldFilter('addedAt', '<=', end_date))
            ).get()
            videos_bookmarked = len(videos_bookmarked_docs)
            
            # Get the full video details for bookmarked videos
            bookmarked_video_refs = [doc.get('videoId') for doc in videos_bookmarked_docs]
            bookmarked_videos = []
            for video_ref in bookmarked_video_refs:
                video_doc = video_ref.get()
                if video_doc.exists:
                    video_data = video_doc.to_dict()
                    bookmarked_videos.append({
                        'id': video_doc.id,
                        'title': video_data['metadata']['title'],
                        'description': video_data['metadata']['description'],
                        'description2': video_data['classification']['explicit']['description'],
                        'transcript': video_data['metadata'].get('transcript', ''),
                        'hashtags': video_data['classification']['explicit'].get('hashtags', [])
                    })

            # Query classes created in time period
            classes_created_docs = (
                db.collection('classes')
                .where(filter=FieldFilter('creator', '==', user_ref))
                .where(filter=FieldFilter('createdAt', '>=', start_date))
                .where(filter=FieldFilter('createdAt', '<=', end_date))
            ).get()
            classes_created = len(classes_created_docs)
            
            # Get full details of created classes
            created_classes = []
            for class_doc in classes_created_docs:
                class_data = class_doc.to_dict()
                created_classes.append({
                    'id': class_doc.id,
                    'title': class_data['title'],
                    'description': class_data['description'],
                    'memberCount': class_data['memberCount'],
                    'isPublic': class_data['isPublic'],
                    'tagPreferences': class_data.get('tagPreferences', {})
                })

            # Query video comprehensions in time period
            comprehension_docs = (
                db.collection('videoComprehension')
                .where(filter=FieldFilter('userId', '==', user_ref))
                .where(filter=FieldFilter('assessedAt', '>=', start_date))
                .where(filter=FieldFilter('assessedAt', '<=', end_date))
            ).get()
            
            # Initialize comprehension stats and videos
            comprehension_stats = {
                'not_understood': 0,
                'partially_understood': 0,
                'fully_understood': 0
            }
            comprehension_videos = {
                'not_understood': [],
                'partially_understood': [],
                'fully_understood': []
            }
            
            # Process comprehension documents
            for doc in comprehension_docs:
                comp_data = doc.to_dict()
                level = comp_data.get('comprehensionLevel')
                if level in comprehension_stats:
                    comprehension_stats[level] += 1
                    
                    # Get video details
                    video_ref = comp_data.get('videoId')
                    if video_ref:
                        video_doc = video_ref.get()
                        if video_doc.exists:
                            video_data = video_doc.to_dict()
                            video_info = {
                                'id': video_doc.id,
                                'title': video_data['metadata']['title'],
                                'description': video_data['metadata']['description'],
                                'description2': video_data['classification']['explicit']['description'],
                                'transcript': video_data['metadata'].get('transcript', ''),
                                'hashtags': video_data['classification']['explicit'].get('hashtags', []),
                                'watchCount': comp_data.get('watchCount', 0),
                                'assessedAt': comp_data.get('assessedAt').isoformat()
                            }
                            comprehension_videos[level].append(video_info)

            # Store all the detailed data for LLM context
            report_details = {
                'videos_watched_count': videos_watched,
                'liked_videos': liked_videos,
                'bookmarked_videos': bookmarked_videos,
                'created_classes': created_classes,
                'comprehension_videos': comprehension_videos
            }

            # Generate LLM response
            llm_response, llm_duration = user_report_llm_response(report_details, report_type)

            # Print the final report data
            print(json.dumps({
                'reportId': simulated_report_id,
                'data': {
                    'status': 'complete',
                    'reportData': {
                        'videosWatched': videos_watched,
                        'videosLiked': videos_liked,
                        'videosBookmarked': videos_bookmarked,
                        'classesCreated': classes_created,
                        'comprehension': comprehension_stats,
                        'body': llm_response,
                        'llmDuration': llm_duration
                    }
                }
            }, indent=2))

            return {'success': True, 'reportId': simulated_report_id}

        except Exception as e:
            print(json.dumps({
                'reportId': simulated_report_id,
                'data': {
                    'status': 'error',
                    'error': str(e)
                }
            }, indent=2))
            raise e

    except Exception as e:
        return {'error': f'Error generating report: {str(e)}'}

def user_report_llm_response(report_details: Dict, report_type: str = 'custom') -> tuple[str, float]:
    """Generate an LLM response for user progress report."""
    
    start_time = datetime.now()
    
    # Get the appropriate time period message based on report type
    time_period_msg = {
        'daily': "Here's your daily learning recap! Let's look at what you've accomplished today.",
        'weekly': "Here's your weekly activity summary! Let's review what you've achieved this week.",
        'monthly': "Your month in review! Let's explore your learning journey over the past month.",
        'yearly': "Your year in review! Let's celebrate your learning achievements over the past year.",
        'custom': "Here's your learning progress report for this period."
    }.get(report_type, "Here's your learning progress report for this period.")
    
    # Format the prompt with report details
    prompt = f"""You are an AI learning assistant providing a personal progress report directly to a user. Use "you" and "your" when referring to their activities.
Your tone should be encouraging, supportive, and motivating - celebrate their achievements and frame areas for improvement positively.
Avoid using markdown formatting. Use simple text formatting only.

{time_period_msg}

Activity Summary:
- Videos Watched: {report_details['videos_watched_count']} videos
- Videos Liked: {len(report_details['liked_videos'])} videos
- Videos Bookmarked: {len(report_details['bookmarked_videos'])} videos
- Classes Created: {len(report_details['created_classes'])} classes
- Your Comprehension Levels:
  * Not Understood: {len(report_details['comprehension_videos']['not_understood'])} videos
  * Partially Understood: {len(report_details['comprehension_videos']['partially_understood'])} videos
  * Fully Understood: {len(report_details['comprehension_videos']['fully_understood'])} videos

Detailed Information:
1. Videos you liked: {json.dumps([{'title': v['title'], 'description': v['description']} for v in report_details['liked_videos']], indent=2)}
2. Videos you bookmarked: {json.dumps([{'title': v['title'], 'description': v['description']} for v in report_details['bookmarked_videos']], indent=2)}
3. Classes you created: {json.dumps([{'title': c['title'], 'description': c['description'], 'memberCount': c['memberCount']} for c in report_details['created_classes']], indent=2)}
4. Videos you're still working to understand: {json.dumps([{'title': v['title'], 'description': v['description']} for v in report_details['comprehension_videos']['not_understood']], indent=2)}
5. Videos you're getting better at: {json.dumps([{'title': v['title'], 'description': v['description']} for v in report_details['comprehension_videos']['partially_understood']], indent=2)}
6. Videos you've mastered: {json.dumps([{'title': v['title'], 'description': v['description']} for v in report_details['comprehension_videos']['fully_understood']], indent=2)}

Please provide:
1. An encouraging summary of their learning activity and engagement, using "you" and "your"
2. A positive analysis of their comprehension patterns and interests
3. Constructive suggestions for improving their learning experience
4. Celebration of their achievements and milestones
5. Personalized recommendations for future content based on their interests

Keep the response personal, encouraging, and actionable. Focus on their progress and potential."""

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini-2024-07-18",
            messages=[
                {"role": "system", "content": "You are an AI learning assistant providing insights on user learning progress."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=1000
        )
        
        end_time = datetime.now()
        duration_seconds = (end_time - start_time).total_seconds()
        
        return response.choices[0].message.content, duration_seconds
        
    except Exception as e:
        return "Error generating report analysis. Please try again later.", 0.0

def generate_class_report(class_id: str, start_time: str, end_time: str, report_type: str = 'custom'):
    try:
        # Initialize Firestore
        class_ref = db.collection('classes').document(class_id)
        
        # Check for in-progress reports
        in_progress_reports = (
            db.collection('classProgressReports')
            .where(filter=FieldFilter('classId', '==', class_ref))
            .where(filter=FieldFilter('status', '==', 'in_progress'))
            .limit(1)
            .get()
        )
        
        if len(in_progress_reports) > 0:
            return {'error': 'A report is already being generated for this class', 'reportId': in_progress_reports[0].id}
        
        # Instead of creating a new document, we'll simulate the ID
        simulated_report_id = "simulated_class_report_456"
        
        # Create initial report data
        report_data = {
            'classId': class_ref,
            'createdAt': datetime.now(timezone.utc),
            'startDate': datetime.fromisoformat(start_time),
            'endDate': datetime.fromisoformat(end_time),
            'type': report_type,
            'status': 'in_progress'
        }

        print(json.dumps({
            'reportId': simulated_report_id,
            'data': {
                'classId': class_ref.path,
                'createdAt': report_data['createdAt'].isoformat(),
                'startDate': report_data['startDate'].isoformat(),
                'endDate': report_data['endDate'].isoformat(),
                'type': report_type,
                'status': 'in_progress'
            }
        }, indent=2))

        try:
            # Query data for the time period
            start_date = datetime.fromisoformat(start_time).replace(tzinfo=timezone.utc)
            end_date = datetime.fromisoformat(end_time).replace(tzinfo=timezone.utc)
            
            # Get class details
            class_doc = class_ref.get()
            if not class_doc.exists:
                raise Exception(f"Class {class_id} not found")
            
            class_data = class_doc.to_dict()
            active_members = class_data.get('memberCount', 0)
            class_details = {
                'id': class_doc.id,
                'title': class_data.get('title', ''),
                'description': class_data.get('description', ''),
                'memberCount': active_members,
                'isPublic': class_data.get('isPublic', True),
                'creator': class_data.get('creator', {}).path if class_data.get('creator') else None
            }
            
            # Get members who joined in the time period
            members_joined_docs = (
                db.collection('classMembership')
                .where(filter=FieldFilter('classId', '==', class_ref))
                .where(filter=FieldFilter('joinedAt', '>=', start_date))
                .where(filter=FieldFilter('joinedAt', '<=', end_date))
            ).get()
            members_joined = len(members_joined_docs)
            
            # Get member details
            joined_members = []
            for member_doc in members_joined_docs:
                member_data = member_doc.to_dict()
                user_ref = member_data.get('userId')
                if user_ref:
                    user_doc = user_ref.get()
                    if user_doc.exists:
                        user_data = user_doc.to_dict()
                        profile = user_data.get('profile', {})
                        joined_members.append({
                            'id': user_doc.id,
                            'displayName': profile.get('displayName', ''),
                            'biography': profile.get('biography', ''),
                            'email': user_data.get('email', ''),
                            'joinedAt': member_data.get('joinedAt').isoformat(),
                            'role': member_data.get('role', 'follower'),
                            'onboardingCompleted': user_data.get('onboardingCompleted', False)
                        })
            
            # Get videos liked in time period
            videos_liked_docs = (
                db.collection('userLikes')
                .where(filter=FieldFilter('classId', 'array_contains', class_ref))
                .where(filter=FieldFilter('likedAt', '>=', start_date))
                .where(filter=FieldFilter('likedAt', '<=', end_date))
            ).get()
            videos_liked = len(videos_liked_docs)
            
            # Get video details for liked videos
            liked_videos = []
            for like_doc in videos_liked_docs:
                like_data = like_doc.to_dict()
                video_ref = like_data.get('videoId')
                if video_ref:
                    video_doc = video_ref.get()
                    if video_doc.exists:
                        video_data = video_doc.to_dict()
                        liked_videos.append({
                            'id': video_doc.id,
                            'title': video_data['metadata']['title'],
                            'description': video_data['metadata']['description'],
                            'description2': video_data['classification']['explicit']['description'],
                            'transcript': video_data['metadata'].get('transcript', ''),
                            'hashtags': video_data['classification']['explicit'].get('hashtags', []),
                            'likedAt': like_data.get('likedAt').isoformat(),
                            'likedBy': like_data.get('userId').path if like_data.get('userId') else None
                        })
            
            # Get videos bookmarked in time period
            videos_bookmarked_docs = (
                db.collection('userBookmarks')
                .where(filter=FieldFilter('classId', 'array_contains', class_ref))
                .where(filter=FieldFilter('addedAt', '>=', start_date))
                .where(filter=FieldFilter('addedAt', '<=', end_date))
            ).get()
            videos_bookmarked = len(videos_bookmarked_docs)
            
            # Get video details for bookmarked videos
            bookmarked_videos = []
            for bookmark_doc in videos_bookmarked_docs:
                bookmark_data = bookmark_doc.to_dict()
                video_ref = bookmark_data.get('videoId')
                if video_ref:
                    video_doc = video_ref.get()
                    if video_doc.exists:
                        video_data = video_doc.to_dict()
                        bookmarked_videos.append({
                            'id': video_doc.id,
                            'title': video_data['metadata']['title'],
                            'description': video_data['metadata']['description'],
                            'description2': video_data['classification']['explicit']['description'],
                            'transcript': video_data['metadata'].get('transcript', ''),
                            'hashtags': video_data['classification']['explicit'].get('hashtags', []),
                            'addedAt': bookmark_data.get('addedAt').isoformat(),
                            'addedBy': bookmark_data.get('userId').path if bookmark_data.get('userId') else None,
                            'notes': bookmark_data.get('notes', '')
                        })

            # Store all the detailed data for LLM context
            report_details = {
                'class': class_details,
                'joined_members': joined_members,
                'liked_videos': liked_videos,
                'bookmarked_videos': bookmarked_videos
            }

            # Generate LLM response
            llm_response, llm_duration = class_report_llm_response(report_details, report_type)

            # Print the final report data
            print(json.dumps({
                'reportId': simulated_report_id,
                'data': {
                    'status': 'complete',
                    'reportData': {
                        'membersActive': active_members,
                        'membersJoined': members_joined,
                        'videosLiked': videos_liked,
                        'videosBookmarked': videos_bookmarked,
                        'body': llm_response,
                        'llmDuration': llm_duration
                    }
                }
            }, indent=2))

            return {'success': True, 'reportId': simulated_report_id}

        except Exception as e:
            print(json.dumps({
                'reportId': simulated_report_id,
                'data': {
                    'status': 'error',
                    'error': str(e)
                }
            }, indent=2))
            raise e

    except Exception as e:
        return {'error': f'Error generating report: {str(e)}'}

def class_report_llm_response(report_details: Dict, report_type: str = 'custom') -> tuple[str, float]:
    """Generate an LLM response for class progress report."""
    
    start_time = datetime.now()
    
    # Get the appropriate time period message based on report type
    time_period_msg = {
        'daily': "Here's your class's daily activity recap! Let's look at what your members accomplished today.",
        'weekly': "Here's your class's weekly summary! Let's review what your members achieved this week.",
        'monthly': "Your class's month in review! Let's explore your class's learning journey over the past month.",
        'yearly': "Your class's year in review! Let's celebrate your class's achievements over the past year.",
        'custom': "Here's your class's progress report for this period."
    }.get(report_type, "Here's your class's progress report for this period.")
    
    # Format the prompt with report details
    prompt = f"""You are an AI learning assistant providing a class progress report to the class creator/instructor.
Your tone should be encouraging and constructive, highlighting successes while providing actionable insights for improvement.
Avoid using markdown formatting. Use simple text formatting only.

{time_period_msg}

Class Information:
Title: {report_details['class']['title']}
Description: {report_details['class']['description']}
Active Members: {report_details['class']['memberCount']}
Public: {report_details['class']['isPublic']}

Activity Summary:
- New Members Joined: {len(report_details['joined_members'])} members
- Videos Your Class Members Liked: {len(report_details['liked_videos'])} videos
- Videos Your Class Members Bookmarked: {len(report_details['bookmarked_videos'])} videos

Detailed Information:
1. New members who joined your class: {json.dumps([{
    'displayName': m['displayName'],
    'biography': m['biography'],
    'joinedAt': m['joinedAt'],
    'role': m['role']
} for m in report_details['joined_members']], indent=2)}

2. Videos your class members liked: {json.dumps([{
    'title': v['title'],
    'description': v['description'],
    'hashtags': v['hashtags'],
    'likedAt': v['likedAt'],
    'likedBy': v['likedBy']
} for v in report_details['liked_videos']], indent=2)}

3. Videos your class members bookmarked: {json.dumps([{
    'title': v['title'],
    'description': v['description'],
    'hashtags': v['hashtags'],
    'addedAt': v['addedAt'],
    'addedBy': v['addedBy'],
    'notes': v['notes']
} for v in report_details['bookmarked_videos']], indent=2)}

Please provide:
1. An encouraging summary of your class's activity and engagement
2. A positive analysis of your class's content preferences and learning patterns
3. Constructive insights about member participation and interaction
4. Celebration of class achievements and milestones
5. Actionable recommendations for improving class engagement
6. Tailored suggestions for future content based on your class's interests

Keep the response personal, encouraging, and actionable. Focus on the class's progress and potential."""

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini-2024-07-18",
            messages=[
                {"role": "system", "content": "You are an AI learning assistant providing insights on class progress and engagement."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=1000
        )
        
        end_time = datetime.now()
        duration_seconds = (end_time - start_time).total_seconds()
        
        return response.choices[0].message.content, duration_seconds
        
    except Exception as e:
        return "Error generating report analysis. Please try again later.", 0.0

def format_video_response(doc: Any) -> Dict:
    """Format a video document into the response format."""
    data = doc.to_dict()
    metadata = data.get('metadata', {})
    engagement = data.get('engagement', {
        'views': 0,
        'likes': 0,
        'shares': 0,
        'completionRate': 0.0,
        'averageWatchTime': 0.0
    })
    
    return {
        'id': doc.id,
        'title': metadata.get('title', ''),
        'description': metadata.get('description', ''),
        'videoUrl': metadata.get('videoUrl', ''),
        'thumbnailUrl': metadata.get('thumbnailUrl', ''),
        'duration': float(metadata.get('duration', 0)),
        'uploadedAt': metadata.get('uploadedAt', datetime.now(timezone.utc)).isoformat(),
        'updatedAt': metadata.get('updatedAt', datetime.now(timezone.utc)).isoformat(),
        'creator': {
            'path': get_creator_path(data),
            'type': 'documentReference'
        },
        'engagement': engagement
    }

def main():
    # Test time period (last 7 days)
    end_time = END_TIME
    start_time = START_TIME
    
    print("\nTesting User Report Generation:")
    print("-" * 30)
    user_result = generate_user_report(TEST_USER_ID, start_time, end_time)
    print(f"User Report Result: {json.dumps(user_result, indent=2)}")
    
    print("\nTesting Class Report Generation:")
    print("-" * 30)
    class_result = generate_class_report(TEST_CLASS_ID, start_time, end_time)
    print(f"Class Report Result: {json.dumps(class_result, indent=2)}")

if __name__ == "__main__":
    main() 