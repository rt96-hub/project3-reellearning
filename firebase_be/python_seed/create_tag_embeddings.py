import os
from pinecone import Pinecone
from openai import OpenAI
import firebase_admin
from firebase_admin import credentials, firestore
from typing import List, Dict, Tuple
import logging
from dotenv import load_dotenv
import time
import csv
from datetime import datetime

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Initialize clients
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
pc = Pinecone(api_key=os.getenv('PINECONE_API_KEY'))
index = pc.Index(os.getenv('PINECONE_INDEX'))

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('../serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
db = firestore.client()

def create_tracking_csv(filename: str = 'tag_tracking.csv') -> List[str]:
    """Create or load a CSV file tracking all tags and their processing status."""
    # Check if tracking file exists
    if os.path.isfile(filename):
        # Load existing tracking data
        with open(filename, 'r', newline='') as f:
            reader = csv.DictReader(f)
            processed_ids = [row['tag_id'] for row in reader if row['status'] == 'completed']
        logger.info(f"Found existing tracking file with {len(processed_ids)} completed tags")
        return processed_ids
    
    # Create new tracking file with all tags
    tags = get_all_tags()
    
    with open(filename, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['tag_id', 'tag', 'status', 'timestamp'])
        writer.writeheader()
        
        # Write all tag IDs with 'pending' status
        for tag in tags:
            writer.writerow({
                'tag_id': tag['id'],
                'tag': tag['tag'],
                'status': 'pending',
                'timestamp': ''
            })
    
    logger.info(f"Created new tracking file for {len(tags)} tags")
    return []

def update_tracking_status(tag_id: str, tag: str, status: str, filename: str = 'tag_tracking.csv'):
    """Update the status of a tag in the tracking CSV."""
    # Read existing data
    rows = []
    with open(filename, 'r', newline='') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    # Update status for the tag
    for row in rows:
        if row['tag_id'] == tag_id:
            row['status'] = status
            row['timestamp'] = datetime.now().isoformat()
    
    # Write updated data back
    with open(filename, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['tag_id', 'tag', 'status', 'timestamp'])
        writer.writeheader()
        writer.writerows(rows)

def get_all_tags() -> List[Dict]:
    """Fetch all tags from Firestore videoTags collection"""
    try:
        tags_ref = db.collection('videoTags')
        return [{
            'id': doc.id,
            'tag': doc.get('tag'),
            'count': doc.get('count')
        } for doc in tags_ref.stream()]
    except Exception as e:
        logger.error(f"Error fetching tags: {e}")
        raise

def generate_embedding(text: str) -> List[float]:
    """Generate embedding using OpenAI's text-embedding-3-small model"""
    try:
        response = openai_client.embeddings.create(
            input=text,
            model="text-embedding-3-small"
        )
        return response.data[0].embedding
    except Exception as e:
        logger.error(f"Error generating embedding: {e}")
        raise

def store_embeddings(tags: List[Dict], processed_ids: List[str]) -> None:
    """Store embeddings for all tags in Pinecone"""
    logger.info(f"Storing embeddings for {len(tags)} tags...")
    
    for tag_doc in tags:
        # Skip already processed tags
        if tag_doc['id'] in processed_ids:
            logger.info(f"Skipping already processed tag: {tag_doc['tag']}")
            continue
            
        try:
            # Remove '#' if present and use as embedding text
            tag_text = tag_doc['tag'].replace('#', '')
            
            # Generate embedding
            embedding = generate_embedding(tag_text)
            
            # Store in Pinecone
            index.upsert(vectors=[(
                tag_doc['id'],
                embedding,
                {
                    'tag': tag_doc['tag'],
                    'count': tag_doc['count']
                }
            )])
            
            # Update tracking status
            update_tracking_status(tag_doc['id'], tag_doc['tag'], 'completed')
            logger.info(f"Stored embedding for tag: {tag_doc['tag']}")
            time.sleep(1)  # Rate limiting
            
        except Exception as e:
            # Update tracking status for failed tags
            update_tracking_status(tag_doc['id'], tag_doc['tag'], 'failed')
            logger.error(f"Error storing embedding for tag {tag_doc['tag']}: {e}")
            continue

def find_related_tags(tags: List[Dict]) -> None:
    """Find 5 most related tags for each tag and update Firestore"""
    logger.info("Finding related tags...")
    
    # Create a batch for Firestore updates
    batch = db.batch()
    
    for tag_doc in tags:
        try:
            # Query Pinecone for similar tags
            results = index.query(
                id=tag_doc['id'],
                top_k=6,  # Get 6 to account for self-match
                include_metadata=True
            )
            
            # Filter out self-match and get just the tags
            related_tags = []
            for match in results.matches:
                if match.id != tag_doc['id']:  # Skip self-match
                    related_tags.append(match.metadata['tag'])
            
            # Update Firestore document
            tag_ref = db.collection('videoTags').document(tag_doc['id'])
            batch.update(tag_ref, {
                'relatedTags': related_tags[:5]  # Keep only top 5
            })
            
            logger.info(f"Found related tags for: {tag_doc['tag']}")
            # time.sleep(1)  # Rate limiting
            
        except Exception as e:
            logger.error(f"Error finding related tags for {tag_doc['tag']}: {e}")
            continue
    
    # Commit all updates
    try:
        batch.commit()
        logger.info("Successfully updated all tags with related tags")
    except Exception as e:
        logger.error(f"Error committing batch updates: {e}")
        raise

def main():
    try:
        # 1. Get all tags from Firestore
        tags = get_all_tags()
        if not tags:
            logger.error("No tags found in Firestore")
            return
            
        # 2. Create or load tracking file
        processed_ids = create_tracking_csv()
        
        # 3. Store embeddings in Pinecone
        store_embeddings(tags, processed_ids)
        logger.info("Finished storing embeddings")
        
        # 4. Find related tags and update Firestore
        find_related_tags(tags)
        logger.info("Successfully completed tag embedding process")
        
    except Exception as e:
        logger.error(f"Error in main process: {e}")
        raise

if __name__ == "__main__":
    main() 