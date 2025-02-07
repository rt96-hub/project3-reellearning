from firebase_functions import https_fn
from firebase_admin import initialize_app, firestore, auth
from datetime import datetime, timedelta
import json
import random

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

@https_fn.on_request()
def get_videos(req: https_fn.Request) -> https_fn.Response:
    # Set CORS headers for all responses
    cors_headers = {
        'Access-Control-Allow-Origin': '*',  # In production, you might want to restrict this
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

    # Get user_id and class_id from query parameters
    # Note: We now have the verified user_id from the token, but we'll still accept it from params
    # for flexibility (though in production you might want to enforce they match)
    user_id_param = req.args.get('user_id', user_id)  # Default to the token's user_id
    class_id = req.args.get('class_id', None)
    
    # Note: Currently these parameters don't affect the video selection
    # They will be used in future implementations for filtered feeds

    # Get number of videos requested (default: 10)
    limit = int(req.args.get('limit', 10))
    
    # TODO: Future recommendation parameters
    # region = req.headers.get('CF-IPCountry')  # CloudFlare header for user region
    # device_type = req.headers.get('User-Agent')  # For device-specific optimizations
    
    # Initialize Firestore
    db = firestore.client()
    videos_ref = db.collection('videos')
    
    # TODO: In production, first check cache
    # cache_key = f"random_videos:{limit}:{datetime.now().strftime('%Y%m%d_%H')}"
    # cached_videos = redis_client.get(cache_key)
    # if cached_videos:
    #     return https_fn.Response(cached_videos, ...)
    
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
        
        # TODO: In production, add engagement-based sorting
        # query = videos_ref
        #     .where('metadata.uploadedAt', '>=', window_start)
        #     .where('metadata.region', '==', user_region)  # Geo-based sharding
        #     .orderBy('engagement.trending_score', 'desc')  # Pre-computed score
        
        # Query for this time window
        query = videos_ref.where('metadata.uploadedAt', '>=', window_start)
        
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
        query = videos_ref
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
    
    # TODO: In production, cache the results
    # redis_client.setex(cache_key, 300, json.dumps({'videos': videos}))  # Cache for 5 minutes
    
    return https_fn.Response(
        json.dumps({'videos': videos}),
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
                # Get user's liked videos
                likes_ref = db.collection('userLikes')
                likes = likes_ref.where('userId', '==', source_id).get()
                
                # Get the video documents for each like
                for like in likes:
                    video_id = like.get('videoId')
                    if video_id:
                        video_doc = videos_ref.document(video_id).get()
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
                # Get user's bookmarked videos
                bookmarks_ref = db.collection('userBookmarks')
                bookmarks = bookmarks_ref.where('userId', '==', source_id).get()
                
                # Get the video documents for each bookmark
                for bookmark in bookmarks:
                    video_id = bookmark.get('videoId')
                    if video_id:
                        video_doc = videos_ref.document(video_id).get()
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