from firebase_functions import https_fn
from firebase_admin import initialize_app, firestore, auth
from datetime import datetime, timedelta
import json
import random
import numpy as np
from typing import List, Dict, Any

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

initialize_app()

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