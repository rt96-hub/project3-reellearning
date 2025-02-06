from firebase_functions import https_fn
from firebase_admin import initialize_app, firestore
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

@https_fn.on_request()
def get_videos(req: https_fn.Request) -> https_fn.Response:
    # Get number of videos requested (default: 10)
    limit = int(req.args.get('limit', 10))
    
    # TODO: Future recommendation parameters
    # class_id = req.args.get('class_id')  # Will be used to fetch relevant class videos
    # user_id = req.args.get('user_id')    # Will be used to fetch personalized recommendations
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
                engagement = data.get('engagement', {'views': 0, 'likes': 0})
                
                # TODO: In production, transform video URLs to closest CDN edge
                # video_url = get_cdn_url(metadata.get('videoUrl', ''), user_region)
                
                video = {
                    'id': doc.id,
                    'title': metadata.get('title', ''),
                    'description': metadata.get('description', ''),
                    'videoUrl': metadata.get('videoUrl', ''),
                    'thumbnailUrl': metadata.get('thumbnailUrl', ''),
                    'duration': float(metadata.get('duration', 0)),
                    'uploadedAt': metadata.get('uploadedAt', datetime.now()).isoformat(),
                    'updatedAt': metadata.get('updatedAt', datetime.now()).isoformat(),
                    'creator': str(data.get('creator', 'users/unknown')),
                    'engagement': engagement
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
                engagement = data.get('engagement', {'views': 0, 'likes': 0})
                
                video = {
                    'id': doc.id,
                    'title': metadata.get('title', ''),
                    'description': metadata.get('description', ''),
                    'videoUrl': metadata.get('videoUrl', ''),
                    'thumbnailUrl': metadata.get('thumbnailUrl', ''),
                    'duration': float(metadata.get('duration', 0)),
                    'uploadedAt': metadata.get('uploadedAt', datetime.now()).isoformat(),
                    'updatedAt': metadata.get('updatedAt', datetime.now()).isoformat(),
                    'creator': str(data.get('creator', 'users/unknown')),
                    'engagement': engagement
                }
                videos.append(video)
    
    # TODO: In production, cache the results
    # redis_client.setex(cache_key, 300, json.dumps({'videos': videos}))  # Cache for 5 minutes
    
    # Set CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET',
        'Access-Control-Allow-Headers': 'Content-Type',
    }
    
    return https_fn.Response(
        json.dumps({'videos': videos}),
        headers=headers,
        content_type='application/json'
    )