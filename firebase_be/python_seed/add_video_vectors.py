import os
import csv
import firebase_admin
from firebase_admin import credentials, firestore
from typing import Dict, List
import numpy as np

# Initialize Firebase
cred = credentials.Certificate('../serviceAccountKey.json')
try:
    firebase_admin.initialize_app(cred)
except ValueError:
    # App already initialized
    pass

db = firestore.client()

def read_classifications(file_path: str) -> Dict[str, List[float]]:
    """Read the video classifications CSV and convert to vectors."""
    video_vectors = {}
    
    with open(file_path, 'r') as f:
        reader = csv.DictReader(f)
        # Get all field names except 'id'
        feature_columns = [col for col in reader.fieldnames if col != 'id']
        
        for row in reader:
            # Convert boolean strings to float (0.0 or 1.0)
            vector = [1.0 if row[col].lower() == 'true' else 0.0 for col in feature_columns]
            video_vectors[row['id']] = vector
    
    return video_vectors

def update_video_vectors(video_vectors: Dict[str, List[float]], batch_size: int = 500):
    """Update Firestore documents with video vectors."""
    batch = db.batch()
    count = 0
    total_updated = 0
    
    for video_id, vector in video_vectors.items():
        doc_ref = db.collection('videos').document(video_id)
        batch.update(doc_ref, {
            'classification.videoVector': vector
        })
        
        count += 1
        if count >= batch_size:
            # Commit the batch
            batch.commit()
            total_updated += count
            print(f"Updated {total_updated} videos...")
            # Reset for next batch
            batch = db.batch()
            count = 0
    
    # Commit any remaining updates
    if count > 0:
        batch.commit()
        total_updated += count
    
    print(f"\nCompleted! Total videos updated: {total_updated}")

def main():
    classifications_path = 'video_classifications.csv'
    print("Reading video classifications...")
    video_vectors = read_classifications(classifications_path)
    
    print(f"Found {len(video_vectors)} video classifications")
    print(f"Vector dimension: {len(next(iter(video_vectors.values())))} features")
    
    print("\nUpdating video documents in Firestore...")
    update_video_vectors(video_vectors)

if __name__ == "__main__":
    main() 