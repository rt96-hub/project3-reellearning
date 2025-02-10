import os
import firebase_admin
from firebase_admin import credentials, firestore
import logging
from dotenv import load_dotenv

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('../serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
db = firestore.client()

def clean_video_hashtags():
    """Remove '#' from hashtags in videos collection."""
    videos_ref = db.collection('videos')
    batch = db.batch()
    batch_count = 0
    total_updated = 0
    
    try:
        # Get all videos
        videos = videos_ref.stream()
        
        for video in videos:
            try:
                video_data = video.to_dict()
                hashtags = video_data.get('classification', {}).get('explicit', {}).get('hashtags', [])
                
                # Check if any hashtags need cleaning
                cleaned_hashtags = [tag.replace('#', '') for tag in hashtags]
                
                # Only update if changes were made
                if cleaned_hashtags != hashtags:
                    logger.info(f"Cleaning hashtags for video {video.id}")
                    batch.update(video.reference, {
                        'classification.explicit.hashtags': cleaned_hashtags
                    })
                    batch_count += 1
                    total_updated += 1
                
                # Commit batch if it reaches 500 operations
                if batch_count >= 500:
                    batch.commit()
                    logger.info(f"Committed batch of {batch_count} video updates")
                    batch = db.batch()
                    batch_count = 0
            
            except Exception as e:
                logger.error(f"Error processing video {video.id}: {e}")
                continue
        
        # Commit any remaining updates
        if batch_count > 0:
            batch.commit()
            logger.info(f"Committed final batch of {batch_count} video updates")
        
        logger.info(f"Updated hashtags in {total_updated} videos")
        
    except Exception as e:
        logger.error(f"Error cleaning video hashtags: {e}")
        raise

def clean_video_tags():
    """Remove '#' from tags in videoTags collection."""
    tags_ref = db.collection('videoTags')
    batch = db.batch()
    batch_count = 0
    total_updated = 0
    
    try:
        # Get all tags
        tags = tags_ref.stream()
        
        for tag_doc in tags:
            try:
                tag_data = tag_doc.to_dict()
                original_tag = tag_data.get('tag', '')
                related_tags = tag_data.get('relatedTags', [])
                
                # Clean main tag and related tags
                cleaned_tag = original_tag.replace('#', '')
                cleaned_related = [tag.replace('#', '') for tag in related_tags]
                
                # Only update if changes were made
                if cleaned_tag != original_tag or cleaned_related != related_tags:
                    logger.info(f"Cleaning tag {tag_doc.id}")
                    batch.update(tag_doc.reference, {
                        'tag': cleaned_tag,
                        'relatedTags': cleaned_related
                    })
                    batch_count += 1
                    total_updated += 1
                
                # Commit batch if it reaches 500 operations
                if batch_count >= 500:
                    batch.commit()
                    logger.info(f"Committed batch of {batch_count} tag updates")
                    batch = db.batch()
                    batch_count = 0
            
            except Exception as e:
                logger.error(f"Error processing tag {tag_doc.id}: {e}")
                continue
        
        # Commit any remaining updates
        if batch_count > 0:
            batch.commit()
            logger.info(f"Committed final batch of {batch_count} tag updates")
        
        logger.info(f"Updated {total_updated} tags")
        
    except Exception as e:
        logger.error(f"Error cleaning video tags: {e}")
        raise

def main():
    try:
        # 1. Clean hashtags in videos collection
        logger.info("Starting to clean hashtags in videos collection...")
        clean_video_hashtags()
        
        # 2. Clean tags in videoTags collection
        logger.info("Starting to clean tags in videoTags collection...")
        clean_video_tags()
        
        logger.info("Successfully completed cleaning all tags")
        
    except Exception as e:
        logger.error(f"Error in main process: {e}")
        raise

if __name__ == "__main__":
    main() 