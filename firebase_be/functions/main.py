from firebase_functions import https_fn, scheduler_fn
from firebase_admin import initialize_app, firestore, auth
import firebase_admin
from datetime import datetime, timedelta, timezone
import json
import random
import numpy as np
from typing import List, Dict, Any, Tuple
import os
from openai import OpenAI
import requests
import aiohttp
import asyncio
import calendar
import google.auth
import google.auth.transport.requests
import google.oauth2.id_token
import random
from pydantic import BaseModel, Field


class QuestionResponse(BaseModel):
    questionText: str = Field(..., description="The question text that tests understanding of the video content")
    options: List[str] = Field(..., description="Four possible answer options, with the first one being correct")
    explanation: str = Field(..., description="Detailed explanation of why the correct answer is right")

def validate_environment():
    """Validate required environment variables are set."""
    required_vars = [
        # Add any globally required environment variables here
    ]
    
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        raise EnvironmentError(
            f"Missing required environment variables: {', '.join(missing_vars)}\n"
            "Please set these variables in your .env file for local development "
            "or in Firebase Console for production."
        )

# Validate environment variables at startup
validate_environment()

# Initialize Firebase app
initialize_app()


# TODO: Production Optimizations Required:
# 1. Firestore Indexes:
#    - Create composite index on metadata.uploadedAt (ASC) and metadata.views (DESC)
#    - Create composite index on metadata.uploadedAt (ASC) and engagement.likes (DESC)
#    - Create composite index on metadata.classId and metadata.uploadedAt
#
# 2. Caching Layer:
#    - Implement Redis/Memcached to store:
#      - Pre-computed random video batches (refresh every 5 mins)
#      - Popular video metadata (refresh every hour)
#      - User preferences (refresh daily)
#
# 3. Performance Monitoring:
#    - Add logging for query execution time
#    - Track cache hit/miss rates
#    - Monitor video load times by region
#
# 4. CDN Integration:
#    - Store video files in Firebase Storage with CDN
#    - Use different CDN edge locations based on user region
#    - Implement adaptive bitrate streaming
#
# 5. Database Optimization:
#    - Implement database sharding based on:
#      - Geographic region (user_region field)
#      - Time periods (upload_date field)
#    - Add denormalized fields for faster queries:
#      - total_engagement = likes + shares + comments
#      - trending_score = recent_views / time_window
#
# 6. Recommendation System Integration:
#    - Add fields for ML-based ranking:
#      - user_embedding: vector<float>[128]
#      - content_embedding: vector<float>[128]
#      - category_scores: map<string, float>
#      - popularity_score: float
#      - freshness_score: float

# Helper function to safely get creator path
def get_creator_path(data):
    try:
        creator = data.get('creator')
        if creator and hasattr(creator, 'path'):
            return creator.path
    except Exception as e:
        print(f"Error getting creator path: {e}")
    return 'users/unknown'

def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
    """Calculate cosine similarity between two vectors."""
    if not vec1 or not vec2 or len(vec1) != len(vec2):
        return 0.0
    
    vec1_np = np.array(vec1)
    vec2_np = np.array(vec2)
    
    norm1 = np.linalg.norm(vec1_np)
    norm2 = np.linalg.norm(vec2_np)
    
    if norm1 == 0 or norm2 == 0:
        return 0.0
        
    return float(np.dot(vec1_np, vec2_np) / (norm1 * norm2))

def calculate_tag_overlap(tags1: Dict[str, float], tags2: List[str], debug_info: Dict) -> float:
    """Calculate overlap score between two tag preference dictionaries.
    tags1: user tag preferences (dict with lowercase keys)
    tags2: video hashtags (list of strings)"""
    if not tags1 or not tags2:
        return 0.0
    
    # Convert all tags to lowercase for comparison
    user_tags = {tag.lower(): weight for tag, weight in tags1.items()}
    video_tags = [tag.lower() for tag in tags2]
    
    # Track matched tags for debugging
    matched_tags = []
    total_score = 0.0
    
    # For each user tag preference
    for user_tag, weight in user_tags.items():
        # Check if any video tag contains this user tag or vice versa
        for video_tag in video_tags:
            if user_tag in video_tag or video_tag in user_tag:
                total_score += weight
                matched_tags.append({
                    'user_tag': user_tag,
                    'video_tag': video_tag,
                    'weight': weight
                })
                break  # Move to next user tag once we find a match
    
    # Normalize by maximum possible score (sum of all weights)
    max_possible_score = sum(user_tags.values())
    
    if max_possible_score == 0:
        return 0.0
    
    # Add debug info about tag matching
    if 'tag_matches' not in debug_info:
        debug_info['tag_matches'] = []
    debug_info['tag_matches'].extend(matched_tags)
    
    # Add debug info about all tags for comparison
    if 'tag_comparison' not in debug_info:
        debug_info['tag_comparison'] = []
    debug_info['tag_comparison'].append({
        'user_tags': list(user_tags.keys()),
        'video_tags': video_tags,
        'score': float(total_score / max_possible_score)
    })
    
    return float(total_score / max_possible_score)  # Normalize by maximum possible score

def get_vector_profile(db: Any, source_type: str, source_id: str) -> tuple:
    """Get vector and tag preferences for a user or class."""
    collection_name = 'userVectors' if source_type == 'user' else 'classVectors'
    doc_ref = db.collection(collection_name).document(source_id)
    doc = doc_ref.get()
    
    if not doc.exists:
        return [], {}
        
    data = doc.to_dict()
    return data.get('vector', []), data.get('tagPreferences', {})

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
        'uploadedAt': metadata.get('uploadedAt', datetime.now()).isoformat(),
        'updatedAt': metadata.get('updatedAt', datetime.now()).isoformat(),
        'creator': {
            'path': get_creator_path(data),
            'type': 'documentReference'
        },
        'engagement': {
            'views': engagement.get('views', 0),
            'likes': engagement.get('likes', 0),
            'shares': engagement.get('shares', 0),
            'completionRate': float(engagement.get('completionRate', 0)),
            'averageWatchTime': float(engagement.get('averageWatchTime', 0))
        },
        'similarity_score': 0.0  # Will be populated later
    }

@https_fn.on_request()
def get_videos(req: https_fn.Request) -> https_fn.Response:
    # Set CORS headers for all responses
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '3600',
    }
    
    # Initialize debug info
    debug_info = {
        'source_vector_info': None,
        'time_windows': [],
        'similarity_scores': [],
        'excluded_videos': [],
        'total_candidates': 0,
        'final_selected': 0,
        'decision_path': {
            'case': None,
            'reason': None,
            'details': {}
        }
    }
    
    # Handle OPTIONS request (preflight)
    if req.method == 'OPTIONS':
        debug_info['decision_path'] = {
            'case': 'preflight',
            'reason': 'OPTIONS request received',
            'details': {}
        }
        return https_fn.Response('', headers=cors_headers, status=204)
    
    # Verify authentication
    auth_header = req.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        debug_info['decision_path'] = {
            'case': 'auth_error',
            'reason': 'Invalid token format',
            'details': {'header': auth_header[:10] + '...' if auth_header else 'None'}
        }
        return https_fn.Response(
            json.dumps({
                'error': 'Unauthorized - Invalid token format',
                'debug_info': debug_info
            }),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )
    
    try:
        token = auth_header.split('Bearer ')[1]
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
    except Exception as e:
        debug_info['decision_path'] = {
            'case': 'auth_error',
            'reason': 'Token verification failed',
            'details': {'error': str(e)}
        }
        return https_fn.Response(
            json.dumps({
                'error': f'Unauthorized - Invalid token: {str(e)}',
                'debug_info': debug_info
            }),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )

    # Get request parameters
    source_type = req.args.get('source_type', 'user')  # 'user' or 'class'
    source_id = req.args.get('source_id', user_id)  # defaults to user_id if not specified
    limit = int(req.args.get('limit', 10))
    
    if source_type not in ['user', 'class']:
        debug_info['decision_path'] = {
            'case': 'validation_error',
            'reason': 'Invalid source_type parameter',
            'details': {'provided_source_type': source_type}
        }
        return https_fn.Response(
            json.dumps({
                'error': 'Invalid source_type. Must be "user" or "class"',
                'debug_info': debug_info
            }),
            status=400,
            headers=cors_headers,
            content_type='application/json'
        )

    # Initialize Firestore
    db = firestore.client()
    
    # Get recently watched videos (within last 24 hours)
    recently_watched = set()
    try:
        # Query userViews collection instead of userWatchHistory
        user_ref = db.collection('users').document(user_id)
        views_query = (
            db.collection('userViews')
            .where('userId', '==', user_ref)
            .where('watchedAt', '>=', datetime.now() - timedelta(hours=1))
            .get()
        )
        
        for view in views_query:
            view_data = view.to_dict()
            video_ref = view_data.get('videoId')
            if video_ref:
                video_id = video_ref.id
                recently_watched.add(video_id)
                debug_info['excluded_videos'].append({
                    'video_id': video_id,
                    'watched_at': view_data.get('watchedAt').isoformat(),
                    'reason': 'watched_within_last_hour'
                })
    except Exception as e:
        print(f"Error fetching user views: {e}")
        debug_info['errors'] = debug_info.get('errors', []) + [f"Error fetching user views: {e}"]
    
    # Get the source vector profile
    source_vector, source_tags = get_vector_profile(db, source_type, source_id)
    debug_info['source_vector_info'] = {
        'has_vector': bool(source_vector),
        'vector_length': len(source_vector) if source_vector else 0,
        'tags': source_tags,
        'source_type': source_type,
        'source_id': source_id
    }
    
    # If no vector profile AND no tags exist, fall back to time-based recommendations
    if not source_vector and not source_tags:
        debug_info['decision_path'] = {
            'case': 'time_based_fallback',
            'reason': 'No vector profile or tags found',
            'details': {
                'source_type': source_type,
                'source_id': source_id,
                'recently_watched_count': len(recently_watched)
            }
        }
        # Strategy 1: Time-based random sampling
        # Get videos from last 7 days with higher probability, older ones with lower probability
        time_windows = [
            (datetime.now() - timedelta(days=7), 0.6),    # 60% chance from last 7 days
            (datetime.now() - timedelta(days=30), 0.3),   # 30% chance from last 30 days
            (datetime.now() - timedelta(days=365), 0.1),  # 10% chance from last year
        ]
        
        videos = []
        remaining_limit = limit
        
        for window_start, probability in time_windows:
            if remaining_limit <= 0:
                break
            
            # Calculate how many videos to fetch from this window
            window_limit = int(limit * probability) + 1
            
            # Query for this time window
            query = db.collection('videos').where('metadata.uploadedAt', '>=', window_start)
            
            # Use Firestore's offset for basic random sampling
            # Note: In production, you'd want to use a more sophisticated ranking system
            count = query.count().get()[0][0].value
            if count > 0:
                offset = random.randint(0, max(0, count - window_limit))
                window_docs = query.offset(offset).limit(window_limit).get()
                
                for doc in window_docs:
                    if remaining_limit <= 0:
                        break
                    
                    data = doc.to_dict()
                    metadata = data.get('metadata', {})
                    engagement = data.get('engagement', {
                        'views': 0,
                        'likes': 0,
                        'shares': 0,
                        'completionRate': 0.0,
                        'averageWatchTime': 0.0
                    })
                    
                    video = {
                        'id': doc.id,
                        'title': metadata.get('title', ''),
                        'description': metadata.get('description', ''),
                        'videoUrl': metadata.get('videoUrl', ''),
                        'thumbnailUrl': metadata.get('thumbnailUrl', ''),
                        'duration': float(metadata.get('duration', 0)),
                        'uploadedAt': metadata.get('uploadedAt', datetime.now()).isoformat(),
                        'updatedAt': metadata.get('updatedAt', datetime.now()).isoformat(),
                        'creator': {
                            'path': get_creator_path(data),
                            'type': 'documentReference'
                        },
                        'engagement': {
                            'views': engagement.get('views', 0),
                            'likes': engagement.get('likes', 0),
                            'shares': engagement.get('shares', 0),
                            'completionRate': float(engagement.get('completionRate', 0)),
                            'averageWatchTime': float(engagement.get('averageWatchTime', 0))
                        }
                    }
                    videos.append(video)
                    remaining_limit -= 1
        
        # If we still need more videos, get them randomly from any time
        if remaining_limit > 0:
            query = db.collection('videos')
            count = query.count().get()[0][0].value
            if count > 0:
                offset = random.randint(0, max(0, count - remaining_limit))
                remaining_docs = query.offset(offset).limit(remaining_limit).get()
                
                for doc in remaining_docs:
                    data = doc.to_dict()
                    metadata = data.get('metadata', {})
                    engagement = data.get('engagement', {
                        'views': 0,
                        'likes': 0,
                        'shares': 0,
                        'completionRate': 0.0,
                        'averageWatchTime': 0.0
                    })
                    
                    video = {
                        'id': doc.id,
                        'title': metadata.get('title', ''),
                        'description': metadata.get('description', ''),
                        'videoUrl': metadata.get('videoUrl', ''),
                        'thumbnailUrl': metadata.get('thumbnailUrl', ''),
                        'duration': float(metadata.get('duration', 0)),
                        'uploadedAt': metadata.get('uploadedAt', datetime.now()).isoformat(),
                        'updatedAt': metadata.get('updatedAt', datetime.now()).isoformat(),
                        'creator': {
                            'path': get_creator_path(data),
                            'type': 'documentReference'
                        },
                        'engagement': {
                            'views': engagement.get('views', 0),
                            'likes': engagement.get('likes', 0),
                            'shares': engagement.get('shares', 0),
                            'completionRate': float(engagement.get('completionRate', 0)),
                            'averageWatchTime': float(engagement.get('averageWatchTime', 0))
                        }
                    }
                    videos.append(video)
        
        return https_fn.Response(
            json.dumps({
                'videos': videos,
                'debug_info': debug_info
            }),
            headers=cors_headers,
            content_type='application/json'
        )

    # Vector and/or tag-based recommendations
    debug_info['decision_path'] = {
        'case': 'recommendation',
        'reason': 'Vector and tag profile found' if source_vector and source_tags
                 else 'Only vector profile found' if source_vector
                 else 'Only tag profile found',
        'details': {
            'has_vector': bool(source_vector),
            'vector_length': len(source_vector) if source_vector else 0,
            'tag_count': len(source_tags),
            'recently_watched_count': len(recently_watched)
        }
    }
    
    all_videos = []
    debug_info['recommendation_type'] = ('vector_and_tag_based' if source_vector and source_tags
                                       else 'vector_based' if source_vector
                                       else 'tag_based')
    candidates = set()
    
    try:
        # Track query stats for debugging
        query_stats = {
            'recent_videos': 0,
            'popular_videos': 0,
            'tag_matched_videos': 0
        }
        
        # Get recent videos (last 30 days)
        recent_query = (
            db.collection('videos')
            .where('metadata.uploadedAt', '>=', datetime.now() - timedelta(days=30))
            .order_by('metadata.uploadedAt', direction=firestore.Query.DESCENDING)
            .limit(50)
        )
        recent_docs = recent_query.get()
        for doc in recent_docs:
            if doc.id not in recently_watched:
                candidates.add(doc)
                query_stats['recent_videos'] += 1
        
        # Get popular videos
        popular_query = (
            db.collection('videos')
            .order_by('engagement.views', direction=firestore.Query.DESCENDING)
            .limit(50)
        )
        popular_docs = popular_query.get()
        for doc in popular_docs:
            if doc.id not in recently_watched and doc.id not in {d.id for d in candidates}:
                candidates.add(doc)
                query_stats['popular_videos'] += 1
        
        # Get videos with matching tags if source_tags exist
        if source_tags:
            # Sort tags by their weights and take top 5
            weighted_tags = sorted(
                [(tag.lower(), weight) for tag, weight in source_tags.items()],
                key=lambda x: x[1],
                reverse=True
            )[:5]
            
            debug_info['tag_selection'] = {
                'selected_tags': weighted_tags,
                'total_tags': len(source_tags)
            }
            
            # Query videos for each top tag
            for tag, weight in weighted_tags:
                tag_query = (
                    db.collection('videos')
                    .where('classification.explicit.hashtags', 'array_contains', tag)
                    .limit(20)
                )
                tag_docs = tag_query.get()
                
                for doc in tag_docs:
                    if (doc.id not in recently_watched and 
                        doc.id not in {d.id for d in candidates}):
                        candidates.add(doc)
                        query_stats['tag_matched_videos'] += 1
                        
                        # Add debug info about which tag matched
                        debug_info.setdefault('tag_matches', []).append({
                            'video_id': doc.id,
                            'matched_tag': tag,
                            'weight': weight
                        })
        
        debug_info['candidate_selection'] = {
            'query_stats': query_stats,
            'total_candidates': len(candidates)
        }
        
        # Process candidates and calculate similarity scores
        for doc in candidates:
            video_data = doc.to_dict()
            video_vector = video_data.get('classification', {}).get('videoVector', [])
            video_tags = video_data.get('classification', {}).get('explicit', {}).get('hashtags', [])
            
            # Add debug info for video data
            debug_info['video_details'] = debug_info.get('video_details', [])
            debug_info['video_details'].append({
                'video_id': doc.id,
                'has_vector': bool(video_vector),
                'vector_length': len(video_vector) if video_vector else 0,
                'tags': video_tags,
                'source': [
                    source for source, count in query_stats.items() 
                    if count > 0 and doc in list(candidates)[:count]
                ]
            })
            
            # Calculate similarity scores
            vector_similarity = cosine_similarity(source_vector, video_vector) if source_vector else 0.0
            tag_similarity = calculate_tag_overlap(source_tags, video_tags, debug_info) if source_tags else 0.0
            
            # Adjust weights based on available data
            if source_vector and source_tags:
                # Both vector and tags available
                similarity_score = (0.7 * vector_similarity) + (0.3 * tag_similarity)
            elif source_vector:
                # Only vector available
                similarity_score = vector_similarity
            else:
                # Only tags available
                similarity_score = tag_similarity
            
            debug_info['similarity_scores'].append({
                'video_id': doc.id,
                'vector_similarity': vector_similarity,
                'tag_similarity': tag_similarity,
                'combined_score': similarity_score,
                'video_tags': video_tags,
                'matching_tags': [tag for tag in video_tags if tag.lower() in source_tags] if source_tags else []
            })
            
            video_response = format_video_response(doc)
            video_response['similarity_score'] = similarity_score
            all_videos.append(video_response)
            
    except Exception as e:
        print(f"Error fetching videos: {e}")
        debug_info['errors'] = debug_info.get('errors', []) + [f"Error fetching videos: {e}"]
    
    debug_info['total_candidates'] = len(all_videos)
    
    # Sort by similarity score and limit
    recommended_videos = sorted(
        all_videos,
        key=lambda x: (x['similarity_score'], x['engagement']['views']),
        reverse=True
    )[:limit]
    
    debug_info['final_selected'] = len(recommended_videos)
    
    # Remove similarity score from response
    for video in recommended_videos:
        del video['similarity_score']
    
    # If we didn't find any videos after all processing
    if not recommended_videos:
        debug_info['decision_path']['case'] = 'empty_results'
        debug_info['decision_path']['reason'] = 'No videos found after filtering'
        debug_info['decision_path']['details']['total_candidates_processed'] = len(all_videos)

    return https_fn.Response(
        json.dumps({
            'videos': recommended_videos,
            'debug_info': debug_info
        }),
        headers=cors_headers,
        content_type='application/json'
    )

@https_fn.on_request()
def get_filtered_videos(req: https_fn.Request) -> https_fn.Response:
    # Set CORS headers for all responses
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '3600',
    }
    
    # Handle OPTIONS request (preflight)
    if req.method == 'OPTIONS':
        return https_fn.Response(
            '',
            headers=cors_headers,
            status=204
        )
    
    # Get the Authorization header
    auth_header = req.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return https_fn.Response(
            json.dumps({'error': 'Unauthorized - Invalid token format'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )
    
    # Extract and verify the token
    token = auth_header.split('Bearer ')[1]
    try:
        # Verify the Firebase token
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Unauthorized - Invalid token: {str(e)}'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )

    # Get required parameters
    source_type = req.args.get('source_type')  # 'user' or 'class'
    source_id = req.args.get('source_id')  # user_id or class_id
    video_type = req.args.get('video_type')  # 'likes', 'bookmarks', or 'videos'
    
    if not all([source_type, source_id, video_type]):
        return https_fn.Response(
            json.dumps({'error': 'Missing required parameters'}),
            status=400,
            headers=cors_headers,
            content_type='application/json'
        )
    
    if source_type not in ['user', 'class']:
        return https_fn.Response(
            json.dumps({'error': 'Invalid source_type'}),
            status=400,
            headers=cors_headers,
            content_type='application/json'
        )
    
    if video_type not in ['likes', 'bookmarks', 'videos']:
        return https_fn.Response(
            json.dumps({'error': 'Invalid video_type'}),
            status=400,
            headers=cors_headers,
            content_type='application/json'
        )

    # Initialize Firestore
    db = firestore.client()
    videos_ref = db.collection('videos')
    videos = []

    try:
        if source_type == 'user':
            if video_type == 'likes':
                # Get user's liked videos by userId field
                likes_ref = db.collection('userLikes')
                user_ref = db.collection('users').document(source_id)
                likes = likes_ref.where('userId', '==', user_ref).get()
                
                # Get the video documents for each like
                for like in likes:
                    video_ref = like.get('videoId')
                    if video_ref:
                        video_doc = video_ref.get()
                        if video_doc.exists:
                            data = video_doc.to_dict()
                            metadata = data.get('metadata', {})
                            engagement = data.get('engagement', {
                                'views': 0,
                                'likes': 0,
                                'shares': 0,
                                'completionRate': 0.0,
                                'averageWatchTime': 0.0
                            })
                            
                            video = {
                                'id': video_doc.id,
                                'title': metadata.get('title', ''),
                                'description': metadata.get('description', ''),
                                'videoUrl': metadata.get('videoUrl', ''),
                                'thumbnailUrl': metadata.get('thumbnailUrl', ''),
                                'duration': float(metadata.get('duration', 0)),
                                'uploadedAt': metadata.get('uploadedAt', datetime.now()).isoformat(),
                                'updatedAt': metadata.get('updatedAt', datetime.now()).isoformat(),
                                'creator': {
                                    'path': get_creator_path(data),
                                    'type': 'documentReference'
                                },
                                'engagement': {
                                    'views': engagement.get('views', 0),
                                    'likes': engagement.get('likes', 0),
                                    'shares': engagement.get('shares', 0),
                                    'completionRate': float(engagement.get('completionRate', 0)),
                                    'averageWatchTime': float(engagement.get('averageWatchTime', 0))
                                }
                            }
                            videos.append(video)

            elif video_type == 'bookmarks':
                # Get user's bookmarked videos by userId field
                bookmarks_ref = db.collection('userBookmarks')
                user_ref = db.collection('users').document(source_id)
                bookmarks = bookmarks_ref.where('userId', '==', user_ref).get()
                
                # Get the video documents for each bookmark
                for bookmark in bookmarks:
                    video_ref = bookmark.get('videoId')
                    if video_ref:
                        video_doc = video_ref.get()
                        if video_doc.exists:
                            data = video_doc.to_dict()
                            metadata = data.get('metadata', {})
                            engagement = data.get('engagement', {
                                'views': 0,
                                'likes': 0,
                                'shares': 0,
                                'completionRate': 0.0,
                                'averageWatchTime': 0.0
                            })
                            
                            video = {
                                'id': video_doc.id,
                                'title': metadata.get('title', ''),
                                'description': metadata.get('description', ''),
                                'videoUrl': metadata.get('videoUrl', ''),
                                'thumbnailUrl': metadata.get('thumbnailUrl', ''),
                                'duration': float(metadata.get('duration', 0)),
                                'uploadedAt': metadata.get('uploadedAt', datetime.now()).isoformat(),
                                'updatedAt': metadata.get('updatedAt', datetime.now()).isoformat(),
                                'creator': {
                                    'path': get_creator_path(data),
                                    'type': 'documentReference'
                                },
                                'engagement': {
                                    'views': engagement.get('views', 0),
                                    'likes': engagement.get('likes', 0),
                                    'shares': engagement.get('shares', 0),
                                    'completionRate': float(engagement.get('completionRate', 0)),
                                    'averageWatchTime': float(engagement.get('averageWatchTime', 0))
                                }
                            }
                            videos.append(video)

            else:  # video_type == 'videos'
                # Get videos created by the user
                creator_ref = db.collection('users').document(source_id)
                user_videos = videos_ref.where('creator', '==', creator_ref).order_by('metadata.uploadedAt', direction=firestore.Query.DESCENDING).get()
                
                for doc in user_videos:
                    data = doc.to_dict()
                    metadata = data.get('metadata', {})
                    engagement = data.get('engagement', {
                        'views': 0,
                        'likes': 0,
                        'shares': 0,
                        'completionRate': 0.0,
                        'averageWatchTime': 0.0
                    })
                    
                    video = {
                        'id': doc.id,
                        'title': metadata.get('title', ''),
                        'description': metadata.get('description', ''),
                        'videoUrl': metadata.get('videoUrl', ''),
                        'thumbnailUrl': metadata.get('thumbnailUrl', ''),
                        'duration': float(metadata.get('duration', 0)),
                        'uploadedAt': metadata.get('uploadedAt', datetime.now()).isoformat(),
                        'updatedAt': metadata.get('updatedAt', datetime.now()).isoformat(),
                        'creator': {
                            'path': get_creator_path(data),
                            'type': 'documentReference'
                        },
                        'engagement': {
                            'views': engagement.get('views', 0),
                            'likes': engagement.get('likes', 0),
                            'shares': engagement.get('shares', 0),
                            'completionRate': float(engagement.get('completionRate', 0)),
                            'averageWatchTime': float(engagement.get('averageWatchTime', 0))
                        }
                    }
                    videos.append(video)

        else:  # source_type == 'class'
            if video_type == 'bookmarks':
                # For now, return empty array as requested
                videos = []

    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Error fetching videos: {str(e)}'}),
            status=500,
            headers=cors_headers,
            content_type='application/json'
        )

    # Sort videos by uploadedAt in descending order
    videos.sort(key=lambda x: x['uploadedAt'], reverse=True)

    return https_fn.Response(
        json.dumps({'videos': videos}),
        headers=cors_headers,
        content_type='application/json'
    )

@https_fn.on_request()
def generate_user_report(req: https_fn.Request) -> https_fn.Response:
    # Set CORS headers for all responses
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '3600',
    }
    
    # Handle OPTIONS request (preflight)
    if req.method == 'OPTIONS':
        return https_fn.Response('', headers=cors_headers, status=204)
    
    # Verify authentication
    auth_header = req.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return https_fn.Response(
            json.dumps({'error': 'Unauthorized - Invalid token format'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )
    
    # Get token outside try block
    token = auth_header.split('Bearer ')[1]
    
    try:
        # First try to verify as a Firebase ID token (for app calls)
        try:
            decoded_token = auth.verify_id_token(token)
            user_id = decoded_token['uid']
        except Exception as firebase_error:
            # If Firebase verification fails, verify as a Google Cloud token
            try:
                import google.auth.transport.requests
                import google.oauth2.id_token
                
                auth_req = google.auth.transport.requests.Request()
                
                # Verify the token against Google Cloud
                decoded_token = google.oauth2.id_token.verify_token(
                    token,
                    auth_req,
                    audience=None  # or your specific function URL
                )
                # For internal calls, we'll trust the Cloud Platform
                user_id = 'service-account'
            except Exception as cloud_error:
                return https_fn.Response(
                    json.dumps({'error': f'Unauthorized - Invalid token. Firebase error: {str(firebase_error)}. Cloud error: {str(cloud_error)}'}),
                    status=401,
                    headers=cors_headers,
                    content_type='application/json'
                )
    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Authentication error: {str(e)}'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )

    # Validate OpenAI API key is available
    if not os.getenv('OPENAI_API_KEY'):
        return https_fn.Response(
            json.dumps({'error': 'OpenAI API key not configured'}),
            status=500,
            headers=cors_headers,
            content_type='application/json'
        )
    
    # Initialize OpenAI client
    client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
    
    try:
        # Parse request body
        request_json = req.get_json()
        user_id = request_json.get('id')  # This is now the user ID
        start_time = request_json.get('startTime')
        end_time = request_json.get('endTime')
        report_type = request_json.get('type', 'custom')

        if not all([user_id, start_time, end_time]):
            return https_fn.Response(
                json.dumps({'error': 'Missing required parameters'}),
                status=400,
                headers=cors_headers,
                content_type='application/json'
            )

        # Validate report type
        valid_types = ['daily', 'weekly', 'monthly', 'yearly', 'custom']
        if report_type not in valid_types:
            return https_fn.Response(
                json.dumps({'error': f'Invalid report type. Must be one of: {", ".join(valid_types)}'}),
                status=400,
                headers=cors_headers,
                content_type='application/json'
            )

        # Initialize Firestore
        db = firestore.client()
        
        # Check for in-progress reports
        user_ref = db.collection('users').document(user_id)
        in_progress_reports = (
            db.collection('userProgressReports')
            .where('userId', '==', user_ref)
            .where('status', '==', 'in_progress')
            .limit(1)
            .get()
        )
        
        if len(in_progress_reports) > 0:
            return https_fn.Response(
                json.dumps({
                    'error': 'A report is already being generated for this user',
                    'reportId': in_progress_reports[0].id
                }),
                status=409,  # Conflict
                headers=cors_headers,
                content_type='application/json'
            )
        
        # Create report document with generated ID and initial in_progress status
        new_report_ref = db.collection('userProgressReports').document()
        
        # Create initial report data
        report_data = {
            'userId': user_ref,
            'createdAt': datetime.now(),
            'startDate': datetime.fromisoformat(start_time),
            'endDate': datetime.fromisoformat(end_time),
            'type': report_type,
            'status': 'in_progress'
        }

        # Set the initial data
        new_report_ref.set(report_data)

        try:
            # Query data for the time period
            start_date = datetime.fromisoformat(start_time)
            end_date = datetime.fromisoformat(end_time)
            
            # Get videos watched in time period
            videos_watched_docs = (
                db.collection('userViews')
                .where('userId', '==', user_ref)
                .where('watchedAt', '>=', start_date)
                .where('watchedAt', '<=', end_date)
            ).get()
            videos_watched = len(videos_watched_docs)
            
            # Get videos liked in time period
            videos_liked_docs = (
                db.collection('userLikes')
                .where('userId', '==', user_ref)
                .where('likedAt', '>=', start_date)
                .where('likedAt', '<=', end_date)
            ).get()
            videos_liked = len(videos_liked_docs)
            
            # Get the full video details for liked videos
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
                            'hashtags': video_data['classification']['explicit'].get('hashtags', [])
                        })

            # Get videos bookmarked in time period
            videos_bookmarked_docs = (
                db.collection('userBookmarks')
                .where('userId', '==', user_ref)
                .where('addedAt', '>=', start_date)
                .where('addedAt', '<=', end_date)
            ).get()
            videos_bookmarked = len(videos_bookmarked_docs)
            
            # Get the full video details for bookmarked videos
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

            # Query classes created in time period
            classes_created_docs = (
                db.collection('classes')
                .where('creator', '==', user_ref)
                .where('createdAt', '>=', start_date)
                .where('createdAt', '<=', end_date)
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
                .where('userId', '==', user_ref)
                .where('assessedAt', '>=', start_date)
                .where('assessedAt', '<=', end_date)
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
            llm_response, llm_duration = user_report_llm_response(client, report_details, report_type)

            # Update report with AI-generated content and complete status
            new_report_ref.update({
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
            })

            return https_fn.Response(
                json.dumps({
                    'success': True,
                    'reportId': new_report_ref.id
                }),
                headers=cors_headers,
                content_type='application/json'
            )

        except Exception as e:
            # If AI processing fails, update status to error
            new_report_ref.update({
                'status': 'error',
                'error': str(e)
            })
            raise e

    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Error generating report: {str(e)}'}),
            status=500,
            headers=cors_headers,
            content_type='application/json'
        )

def user_report_llm_response(client: OpenAI, report_details: Dict, report_type: str = 'custom') -> tuple[str, float]:
    """Generate an LLM response for user progress report."""
    
    start_time = datetime.now()
    
    # Get the appropriate time period message based on report type
    time_period_msg = {
        'daily': "Here's your daily learning recap! Let's look at what you've accomplished yesterday.",
        'weekly': "Here's your weekly activity summary! Let's review what you've achieved last week.",
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

@https_fn.on_request()
def generate_class_report(req: https_fn.Request) -> https_fn.Response:
    # Set CORS headers for all responses
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '3600',
    }
    
    # Handle OPTIONS request (preflight)
    if req.method == 'OPTIONS':
        return https_fn.Response('', headers=cors_headers, status=204)
    
    # Verify authentication
    auth_header = req.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return https_fn.Response(
            json.dumps({'error': 'Unauthorized - Invalid token format'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )
    
    # Get token outside try block
    token = auth_header.split('Bearer ')[1]
    
    try:
        # First try to verify as a Firebase ID token (for app calls)
        try:
            decoded_token = auth.verify_id_token(token)
            user_id = decoded_token['uid']
        except Exception as firebase_error:
            # If Firebase verification fails, verify as a Google Cloud token
            try:
                import google.auth.transport.requests
                import google.oauth2.id_token
                
                auth_req = google.auth.transport.requests.Request()
                
                # Verify the token against Google Cloud
                decoded_token = google.oauth2.id_token.verify_token(
                    token,
                    auth_req,
                    audience=None  # or your specific function URL
                )
                # For internal calls, we'll trust the Cloud Platform
                user_id = 'service-account'
            except Exception as cloud_error:
                return https_fn.Response(
                    json.dumps({'error': f'Unauthorized - Invalid token. Firebase error: {str(firebase_error)}. Cloud error: {str(cloud_error)}'}),
                    status=401,
                    headers=cors_headers,
                    content_type='application/json'
                )
    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Authentication error: {str(e)}'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )

    # Validate OpenAI API key is available
    if not os.getenv('OPENAI_API_KEY'):
        return https_fn.Response(
            json.dumps({'error': 'OpenAI API key not configured'}),
            status=500,
            headers=cors_headers,
            content_type='application/json'
        )
    
    # Initialize OpenAI client
    client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
    
    # Rest of your existing code...

    try:
        # Parse request body
        request_json = req.get_json()
        class_id = request_json.get('id')  # This is now the class ID
        start_time = request_json.get('startTime')
        end_time = request_json.get('endTime')
        report_type = request_json.get('type', 'custom')

        if not all([class_id, start_time, end_time]):
            return https_fn.Response(
                json.dumps({'error': 'Missing required parameters'}),
                status=400,
                headers=cors_headers,
                content_type='application/json'
            )

        # Validate report type
        valid_types = ['daily', 'weekly', 'monthly', 'yearly', 'custom']
        if report_type not in valid_types:
            return https_fn.Response(
                json.dumps({'error': f'Invalid report type. Must be one of: {", ".join(valid_types)}'}),
                status=400,
                headers=cors_headers,
                content_type='application/json'
            )

        # Initialize Firestore
        db = firestore.client()
        
        # Check for in-progress reports
        class_ref = db.collection('classes').document(class_id)
        in_progress_reports = (
            db.collection('classProgressReports')
            .where('classId', '==', class_ref)
            .where('status', '==', 'in_progress')
            .limit(1)
            .get()
        )
        
        if len(in_progress_reports) > 0:
            return https_fn.Response(
                json.dumps({
                    'error': 'A report is already being generated for this class',
                    'reportId': in_progress_reports[0].id
                }),
                status=409,  # Conflict
                headers=cors_headers,
                content_type='application/json'
            )
        
        # Create report document with generated ID and initial in_progress status
        new_report_ref = db.collection('classProgressReports').document()
        
        # Create initial report data
        report_data = {
            'classId': class_ref,
            'createdAt': datetime.now(),
            'startDate': datetime.fromisoformat(start_time),
            'endDate': datetime.fromisoformat(end_time),
            'type': report_type,
            'status': 'in_progress'
        }

        # Set the initial data
        new_report_ref.set(report_data)

        try:
            # Query data for the time period
            start_date = datetime.fromisoformat(start_time)
            end_date = datetime.fromisoformat(end_time)
            
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
                .where('classId', '==', class_ref)
                .where('joinedAt', '>=', start_date)
                .where('joinedAt', '<=', end_date)
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
                .where('classId', 'array_contains', class_ref)
                .where('likedAt', '>=', start_date)
                .where('likedAt', '<=', end_date)
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
                .where('classId', 'array_contains', class_ref)
                .where('addedAt', '>=', start_date)
                .where('addedAt', '<=', end_date)
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
            llm_response, llm_duration = class_report_llm_response(client, report_details, report_type)

            # Update report with AI-generated content and complete status
            new_report_ref.update({
                'status': 'complete',
                'reportData': {
                    'membersActive': active_members,
                    'membersJoined': members_joined,
                    'videosLiked': videos_liked,
                    'videosBookmarked': videos_bookmarked,
                    'body': llm_response,
                    'llmDuration': llm_duration
                }
            })

            return https_fn.Response(
                json.dumps({
                    'success': True,
                    'reportId': new_report_ref.id
                }),
                headers=cors_headers,
                content_type='application/json'
            )

        except Exception as e:
            # If AI processing fails, update status to error
            new_report_ref.update({
                'status': 'error',
                'error': str(e)
            })
            raise e

    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Error generating report: {str(e)}'}),
            status=500,
            headers=cors_headers,
            content_type='application/json'
        )

def class_report_llm_response(client: OpenAI, report_details: Dict, report_type: str = 'custom') -> tuple[str, float]:
    """Generate an LLM response for class progress report."""
    
    start_time = datetime.now()
    
    # Get the appropriate time period message based on report type
    time_period_msg = {
        'daily': "Here's your class's daily activity recap! Let's look at what your members accomplished yesterday.",
        'weekly': "Here's your class's weekly summary! Let's review what your members achieved last week.",
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

def get_report_types_and_dates() -> Tuple[str, datetime, datetime]:
    """Determine which report type to generate based on current date.
    Returns a tuple of (report_type, start_date, end_date).
    
    Priority order:
    1. Yearly (January 1st)
    2. Monthly (1st of any month)
    3. Weekly (Mondays)
    4. Daily (default)
    """
    now = datetime.now()
    
    # Check if it's first day of the year
    if now.month == 1 and now.day == 1:
        yearly_end = now
        yearly_start = datetime(now.year - 1, 1, 1)
        return ('yearly', yearly_start, yearly_end)
    
    # Check if it's first of the month
    if now.day == 1:
        # Get first day of previous month
        if now.month == 1:
            monthly_start = datetime(now.year - 1, 12, 1)
        else:
            monthly_start = datetime(now.year, now.month - 1, 1)
        monthly_end = now
        return ('monthly', monthly_start, monthly_end)
    
    # Check if it's Monday
    if now.weekday() == 0:
        weekly_end = now
        weekly_start = weekly_end - timedelta(days=7)
        return ('weekly', weekly_start, weekly_end)
    
    # Default to daily report
    daily_end = now
    daily_start = daily_end - timedelta(days=1)
    return ('daily', daily_start, daily_end)

async def trigger_user_report(session: aiohttp.ClientSession, function_url_base: str, user_doc: Any, report_type: str, start_time: datetime, end_time: datetime, auth_header: Dict[str, str]) -> None:
    """Trigger report generation for a single user."""
    try:
        # Prepare request data
        user_data = {
            'id': user_doc.id,
            'startTime': start_time.isoformat(),
            'endTime': end_time.isoformat(),
            'type': report_type
        }
        
        # Call the user report generation endpoint
        async with session.post(
            f"{function_url_base}/generate_user_report",
            json=user_data,
            headers=auth_header
        ) as response:
            if not response.ok:
                response_text = await response.text()
                print(f"Error generating {report_type} report for user {user_doc.id}: {response_text}")
            
    except Exception as e:
        print(f"Error triggering {report_type} report for user {user_doc.id}: {str(e)}")

async def trigger_class_report(session: aiohttp.ClientSession, function_url_base: str, class_doc: Any, report_type: str, start_time: datetime, end_time: datetime, auth_header: Dict[str, str]) -> None:
    """Trigger report generation for a single class."""
    try:
        # Prepare request data
        class_data = {
            'id': class_doc.id,
            'startTime': start_time.isoformat(),
            'endTime': end_time.isoformat(),
            'type': report_type
        }
        
        # Call the class report generation endpoint
        async with session.post(
            f"{function_url_base}/generate_class_report",
            json=class_data,
            headers=auth_header
        ) as response:
            if not response.ok:
                response_text = await response.text()
                print(f"Error generating {report_type} report for class {class_doc.id}: {response_text}")
            
    except Exception as e:
        print(f"Error triggering {report_type} report for class {class_doc.id}: {str(e)}")


@scheduler_fn.on_schedule(schedule="0 15 * * *")
def trigger_daily_reports(event: scheduler_fn.ScheduledEvent) -> None:
    """Trigger report generation for all active users and classes at 9am."""
    return _trigger_reports()

@https_fn.on_request()
def trigger_reports_manually(req: https_fn.Request) -> https_fn.Response:
    """HTTP endpoint to manually trigger report generation.
    This endpoint is restricted to admin users only."""
    
    # Set CORS headers for all responses
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '3600',
    }
    
    # Handle OPTIONS request (preflight)
    if req.method == 'OPTIONS':
        return https_fn.Response('', headers=cors_headers, status=204)
    
    # Verify authentication
    auth_header = req.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return https_fn.Response(
            json.dumps({'error': 'Unauthorized - Invalid token format'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )
    
    try:
        # Verify the token and get user info
        token = auth_header.split('Bearer ')[1]
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
        
        # Get user's admin status from Firestore
        db = firestore.client()
        user_doc = db.collection('users').document(user_id).get()
        
        if not user_doc.exists:
            return https_fn.Response(
                json.dumps({'error': 'User not found'}),
                status=404,
                headers=cors_headers,
                content_type='application/json'
            )
        
        user_data = user_doc.to_dict()
        is_admin = user_data.get('isAdmin', False)
        
        if not is_admin:
            return https_fn.Response(
                json.dumps({'error': 'Unauthorized - Admin access required'}),
                status=403,
                headers=cors_headers,
                content_type='application/json'
            )
        
    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Authentication error: {str(e)}'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )
    
    try:
        # Log the manual trigger event
        db.collection('adminLogs').add({
            'event': 'manual_report_trigger',
            'triggeredBy': user_id,
            'timestamp': datetime.now()
        })
        
        _trigger_reports()
        return https_fn.Response(
            json.dumps({
                'success': True,
                'message': 'Report generation triggered successfully',
                'triggeredBy': user_id
            }),
            headers=cors_headers,
            content_type='application/json'
        )
    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Error triggering reports: {str(e)}'}),
            status=500,
            headers=cors_headers,
            content_type='application/json'
        )

def _trigger_reports() -> None:
    """Internal function containing the report generation logic.
    This is shared between the scheduled and manual triggers."""
    try:
        # Initialize Firestore
        db = firestore.client()
        
        # Get the function URL base from environment
        function_url_base = os.getenv('FUNCTION_URL_BASE')
        if not function_url_base:
            raise ValueError("FUNCTION_URL_BASE environment variable not set")
        
        # Create a custom token for internal service-to-service calls
        try:
            # Get app instance
            app = firebase_admin.get_app()
            
            # Create a custom token for internal service account
            custom_token = auth.create_custom_token('service-account')
            
            # Exchange custom token for ID token using Firebase Auth REST API
            firebase_api_key = os.getenv('PYTHON_FIREBASE_API_KEY')
            if not firebase_api_key:
                raise ValueError("FIREBASE_API_KEY environment variable not set")
                
            exchange_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={firebase_api_key}"
            
            # Make the token exchange request
            response = requests.post(
                exchange_url,
                json={'token': custom_token.decode(), 'returnSecureToken': True}
            )
            
            if not response.ok:
                raise Exception(f"Failed to exchange custom token: {response.text}")
                
            # Extract the ID token from the response
            id_token = response.json()['idToken']
            auth_header = {'Authorization': f'Bearer {id_token}'}
            
        except Exception as e:
            print(f"Error creating auth token: {str(e)}")
            raise e
        
        # Get report type and date range
        report_type, start_time, end_time = get_report_types_and_dates()
        
        # Get unique users who have viewed videos in the time period
        active_user_refs = set()
        user_views = (
            db.collection('userViews')
            .where('watchedAt', '>=', start_time)
            .where('watchedAt', '<=', end_time)
            .get()
        )
        for view in user_views:
            view_data = view.to_dict()
            if 'userId' in view_data:
                active_user_refs.add(view_data['userId'])
        
        # Get the actual user documents
        active_users = [ref.get() for ref in active_user_refs if ref.get().exists]
        
        # Get unique classes that have likes or bookmarks in the time period
        active_class_refs = set()
        
        # Check userLikes for class activity
        class_likes = (
            db.collection('userLikes')
            .where('likedAt', '>=', start_time)
            .where('likedAt', '<=', end_time)
            .get()
        )
        for like in class_likes:
            like_data = like.to_dict()
            if 'classId' in like_data:
                # classId is an array in userLikes
                for class_ref in like_data['classId']:
                    active_class_refs.add(class_ref)
        
        # Check userBookmarks for class activity
        class_bookmarks = (
            db.collection('userBookmarks')
            .where('addedAt', '>=', start_time)
            .where('addedAt', '<=', end_time)
            .get()
        )
        for bookmark in class_bookmarks:
            bookmark_data = bookmark.to_dict()
            if 'classId' in bookmark_data:
                # classId is an array in userBookmarks
                for class_ref in bookmark_data['classId']:
                    active_class_refs.add(class_ref)
        
        # Get the actual class documents
        active_classes = [ref.get() for ref in active_class_refs if ref.get().exists]
        
        async def main():
            # Create a shared session for all requests
            async with aiohttp.ClientSession() as session:
                tasks = []
                
                # Add user report tasks
                user_tasks = [
                    trigger_user_report(
                        session, function_url_base, user_doc, 
                        report_type, start_time, end_time, auth_header
                    )
                    for user_doc in active_users
                ]
                tasks.extend(user_tasks)
                
                # Add class report tasks
                class_tasks = [
                    trigger_class_report(
                        session, function_url_base, class_doc,
                        report_type, start_time, end_time, auth_header
                    )
                    for class_doc in active_classes
                ]
                tasks.extend(class_tasks)
                
                # Run all tasks concurrently
                await asyncio.gather(*tasks)
        
        # Run the async tasks
        asyncio.run(main())
                
    except Exception as e:
        print(f"Error in trigger_daily_reports: {str(e)}")
        raise e

@https_fn.on_request()
def generate_in_feed_question(req: https_fn.Request) -> https_fn.Response:
    """Generate a multiple choice question based on recently watched videos."""
    # Set CORS headers for all responses
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '3600',
    }
    
    # Handle OPTIONS request (preflight)
    if req.method == 'OPTIONS':
        return https_fn.Response('', headers=cors_headers, status=204)
    
    # Verify authentication
    auth_header = req.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return https_fn.Response(
            json.dumps({'error': 'Unauthorized - Invalid token format'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )
    
    try:
        # Verify the token
        token = auth_header.split('Bearer ')[1]
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Authentication error: {str(e)}'}),
            status=401,
            headers=cors_headers,
            content_type='application/json'
        )
    
    try:
        # Parse request body
        request_json = req.get_json()
        video_ids = request_json.get('videoIds', [])
        
        if not video_ids:
            return https_fn.Response(
                json.dumps({'error': 'No video IDs provided'}),
                status=400,
                headers=cors_headers,
                content_type='application/json'
            )

        # Initialize Firestore
        db = firestore.client()
        
        # Create question document in Firestore with test data
        user_ref = db.collection('users').document(user_id)
        question_ref = db.collection('questions').document()
        
        # get the random video details
        index = random.randint(0, len(video_ids) - 1)
        video_id = video_ids[index]
        video_doc = db.collection('videos').document(video_id).get()
        video_details = {
            'title': video_doc.to_dict()['metadata']['title'],
            'description': video_doc.to_dict()['metadata']['description'],
            'transcript': video_doc.to_dict()['metadata']['transcript'],
            'description2': video_doc.to_dict()['classification']['explicit']['description'],
        }

        # Initialize OpenAI client
        client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

        # Generate the question from openai
        question = generate_question_from_video(client, video_details)


        # Store the question in Firestore
        # make sure only the 1 video is selected
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
        
        # Create a JSON-safe version of the response
        response_data = {
            'status': 'success',
            'questionId': question_ref.id,
            'question': {
                'videoId': f'videos/{video_id}',
                'questionText': question_doc['data']['questionText'],
                'options': question_doc['data']['options'],
                'correctAnswer': question_doc['data']['correctAnswer'],
                'explanation': question_doc['data']['explanation']
            }
        }
        
        # Return the question data
        return https_fn.Response(
            json.dumps(response_data),
            headers=cors_headers,
            content_type='application/json'
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({'error': f'Error generating question: {str(e)}'}),
            status=500,
            headers=cors_headers,
            content_type='application/json'
        )

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
1. Mention the video title in the question
2. Tests comprehension of the main concepts
3. Has 4 options where the FIRST option is ALWAYS the correct answer
4. Includes a clear explanation of why the correct answer is right
5. Ensures wrong options are plausible but clearly incorrect
6. Uses clear, unambiguous language
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
            'questionText': "Looks like we had an error generating a question. Go ahead and pick C...",
            'options': [
                "Option A",
                "Option B",
                "Option C",
                "Option D"
            ],
            'correctAnswer': 2,
            'explanation': "Thought we would try to help you out. Sorry for the inconvenience!"
        }

