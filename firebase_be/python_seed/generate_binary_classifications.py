import os
import csv
import json
from typing import Dict, List
from openai import OpenAI
from dotenv import load_dotenv
import pandas as pd
from uuid import uuid4
from pydantic import BaseModel, Field
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import time

# Load environment variables
load_dotenv()

# Initialize OpenAI client
client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('../serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
db = firestore.client()

class VideoMetadata(BaseModel):
    """Model for video metadata from Firestore."""
    title: str
    description: str
    transcript: str
    hashtags: List[str] = []
    targetAudience: str = ""
    prerequisites: List[str] = []

class BinaryClassification(BaseModel):
    """Model for binary classification results."""
    chemistry_organic: bool = Field(..., description="Topics related to organic chemistry")
    chemistry_inorganic: bool = Field(..., description="Topics related to inorganic chemistry")
    chemistry_bonding: bool = Field(..., description="Topics related to chemical bonding")
    chemistry_thermodynamics: bool = Field(..., description="Topics related to chemical thermodynamics")
    chemistry_electrochemistry: bool = Field(..., description="Topics related to electrochemistry")
    
    physics_classical_mechanics: bool = Field(..., description="Topics related to classical mechanics")
    physics_electromagnetism: bool = Field(..., description="Topics related to electromagnetism")
    physics_quantum: bool = Field(..., description="Topics related to quantum physics")
    physics_thermodynamics: bool = Field(..., description="Topics related to physics thermodynamics")
    physics_relativity: bool = Field(..., description="Topics related to relativity")
    
    biology_cell: bool = Field(..., description="Topics related to cell biology")
    biology_genetics: bool = Field(..., description="Topics related to genetics")
    biology_human_anatomy: bool = Field(..., description="Topics related to human anatomy")
    biology_ecology: bool = Field(..., description="Topics related to ecology")
    biology_microbiology: bool = Field(..., description="Topics related to microbiology")
    
    math_calculus: bool = Field(..., description="Topics related to calculus")
    math_linear_algebra: bool = Field(..., description="Topics related to linear algebra")
    math_probability: bool = Field(..., description="Topics related to probability")
    math_number_theory: bool = Field(..., description="Topics related to number theory")
    math_logic: bool = Field(..., description="Topics related to mathematical logic")
    
    comp_sci_programming: bool = Field(..., description="Topics related to programming")
    comp_sci_data_structures: bool = Field(..., description="Topics related to data structures")
    comp_sci_databases: bool = Field(..., description="Topics related to databases")
    comp_sci_machine_learning: bool = Field(..., description="Topics related to machine learning")
    comp_sci_web_dev: bool = Field(..., description="Topics related to web development")
    
    economics_micro: bool = Field(..., description="Topics related to microeconomics")
    economics_macro: bool = Field(..., description="Topics related to macroeconomics")
    economics_international: bool = Field(..., description="Topics related to international economics")
    economics_policy: bool = Field(..., description="Topics related to economic policy")
    economics_trade: bool = Field(..., description="Topics related to trade economics")
    
    history_ancient: bool = Field(..., description="Topics related to ancient history")
    history_world_war: bool = Field(..., description="Topics related to world war history")
    history_industrial: bool = Field(..., description="Topics related to industrial history")
    history_modern: bool = Field(..., description="Topics related to modern history")
    history_colonial: bool = Field(..., description="Topics related to colonial history")
    
    geography_physical: bool = Field(..., description="Topics related to physical geography")
    geography_human: bool = Field(..., description="Topics related to human geography")
    geography_climate: bool = Field(..., description="Topics related to climate geography")
    geography_cartography: bool = Field(..., description="Topics related to cartography")
    geography_environmental: bool = Field(..., description="Topics related to environmental geography")
    
    literature_classical: bool = Field(..., description="Topics related to classical literature")
    literature_modern: bool = Field(..., description="Topics related to modern literature")
    literature_poetry: bool = Field(..., description="Topics related to poetry")
    literature_drama: bool = Field(..., description="Topics related to drama")
    literature_comparative: bool = Field(..., description="Topics related to comparative literature")
    
    anthropology_cultural: bool = Field(..., description="Topics related to cultural anthropology")
    anthropology_archaeology: bool = Field(..., description="Topics related to archaeology")
    anthropology_linguistic: bool = Field(..., description="Topics related to linguistic anthropology")
    anthropology_ethnology: bool = Field(..., description="Topics related to ethnology")
    anthropology_biological: bool = Field(..., description="Topics related to biological anthropology")
    
    geology_mineralogy: bool = Field(..., description="Topics related to mineralogy")
    geology_plate_tectonics: bool = Field(..., description="Topics related to plate tectonics")
    geology_rock_formation: bool = Field(..., description="Topics related to rock formation")
    geology_earth_history: bool = Field(..., description="Topics related to earth history")
    geology_volcanology: bool = Field(..., description="Topics related to volcanology")
    
    astronomy_solar_system: bool = Field(..., description="Topics related to the solar system")
    astronomy_stellar_evolution: bool = Field(..., description="Topics related to stellar evolution")
    astronomy_cosmology: bool = Field(..., description="Topics related to cosmology")
    astronomy_space_exploration: bool = Field(..., description="Topics related to space exploration")
    astronomy_exoplanets: bool = Field(..., description="Topics related to exoplanets")
    
    engineering_mechanical: bool = Field(..., description="Topics related to mechanical engineering")
    engineering_electrical: bool = Field(..., description="Topics related to electrical engineering")
    engineering_civil: bool = Field(..., description="Topics related to civil engineering")
    engineering_software: bool = Field(..., description="Topics related to software engineering")
    engineering_chemical: bool = Field(..., description="Topics related to chemical engineering")
    
    medicine_human_physiology: bool = Field(..., description="Topics related to human physiology")
    medicine_diagnosis: bool = Field(..., description="Topics related to medical diagnosis")
    medicine_pharmacology: bool = Field(..., description="Topics related to pharmacology")
    medicine_public_health: bool = Field(..., description="Topics related to public health")
    medicine_surgery: bool = Field(..., description="Topics related to surgery")
    
    law_constitutional: bool = Field(..., description="Topics related to constitutional law")
    law_criminal: bool = Field(..., description="Topics related to criminal law")
    law_civil: bool = Field(..., description="Topics related to civil law")
    law_international: bool = Field(..., description="Topics related to international law")
    law_corporate: bool = Field(..., description="Topics related to corporate law")
    
    business_management: bool = Field(..., description="Topics related to business management")
    business_entrepreneurship: bool = Field(..., description="Topics related to entrepreneurship")
    business_strategic_planning: bool = Field(..., description="Topics related to strategic planning")
    business_organizational_behavior: bool = Field(..., description="Topics related to organizational behavior")
    business_ethics: bool = Field(..., description="Topics related to business ethics")
    
    finance_markets: bool = Field(..., description="Topics related to financial markets")
    finance_investment: bool = Field(..., description="Topics related to investment")
    finance_corporate: bool = Field(..., description="Topics related to corporate finance")
    finance_personal: bool = Field(..., description="Topics related to personal finance")
    finance_risk_management: bool = Field(..., description="Topics related to financial risk management")
    
    marketing_digital: bool = Field(..., description="Topics related to digital marketing")
    marketing_research: bool = Field(..., description="Topics related to market research")
    marketing_brand: bool = Field(..., description="Topics related to brand marketing")
    marketing_consumer_behavior: bool = Field(..., description="Topics related to consumer behavior")
    marketing_content: bool = Field(..., description="Topics related to content marketing")
    
    philosophy_general: bool = Field(..., description="Topics related to general philosophy")
    music_theory: bool = Field(..., description="Topics related to music theory")
    art_history: bool = Field(..., description="Topics related to art history")
    sociology_general: bool = Field(..., description="Topics related to general sociology")
    psychology_general: bool = Field(..., description="Topics related to general psychology")
    math_general: bool = Field(..., description="Topics related to general mathematics")

def classify_text(text: str) -> BinaryClassification:
    """Send text to ChatGPT and get binary classifications using response_format."""
    try:
        completion = client.beta.chat.completions.parse(
            model="gpt-4o-mini-2024-07-18",
            messages=[
                {"role": "system", "content": "Analyze the video metadata and classify it into different educational topics. Be precise and strict in classification."},
                {"role": "user", "content": f"Analyze this metadata and determine which educational topics it relates to: {text}"}
            ],
            response_format=BinaryClassification
        )
        
        return completion.choices[0].message.parsed
        
    except Exception as e:
        print(f"Error classifying text: {e}")
        return None

def save_vector(text_id: str, classification: BinaryClassification, output_file: str):
    """Save the classification vector to a CSV file."""
    # Convert the model to a dictionary and get values as a list
    vector = list(classification.model_dump().values())
    
    # Check if file exists to write headers
    file_exists = os.path.isfile(output_file)
    
    with open(output_file, 'a', newline='') as f:
        writer = csv.writer(f)
        
        # Write headers if file is new
        if not file_exists:
            headers = ['id'] + list(classification.model_dump().keys())
            writer.writerow(headers)
        
        # Write the vector
        writer.writerow([text_id] + vector)

def get_video_metadata(video_doc) -> VideoMetadata:
    """Extract relevant metadata from a Firestore video document."""
    doc_dict = video_doc.to_dict()
    metadata = doc_dict.get('metadata', {})
    classification = doc_dict.get('classification', {}).get('explicit', {})
    
    return VideoMetadata(
        title=metadata.get('title', ''),
        description=classification.get('description', ''),
        transcript=metadata.get('transcript', ''),
        hashtags=classification.get('hashtags', []),
        targetAudience=classification.get('targetAudience', ''),
        prerequisites=classification.get('prerequisites', [])
    )

def create_classification_text(metadata: VideoMetadata) -> str:
    """Create a comprehensive text from video metadata for classification."""
    parts = [
        f"Title: {metadata.title}",
        f"Description: {metadata.description}",
        f"Transcript: {metadata.transcript}",
        f"Hashtags: {', '.join(metadata.hashtags)}",
        f"Target Audience: {metadata.targetAudience}",
        f"Prerequisites: {', '.join(metadata.prerequisites)}"
    ]
    return "\n".join(parts)

def create_tracking_csv(filename: str = 'video_tracking.csv') -> List[str]:
    """Create or load a CSV file tracking all videos and their processing status."""
    # Check if tracking file exists
    if os.path.isfile(filename):
        # Load existing tracking data
        with open(filename, 'r', newline='') as f:
            reader = csv.DictReader(f)
            processed_ids = [row['video_id'] for row in reader if row['status'] == 'completed']
        print(f"Found existing tracking file with {len(processed_ids)} completed videos")
        return processed_ids
    
    # Create new tracking file
    videos_ref = db.collection('videos')
    docs = videos_ref.stream()
    
    with open(filename, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['video_id', 'status', 'timestamp'])
        writer.writeheader()
        
        # Write all video IDs with 'pending' status
        for doc in docs:
            writer.writerow({
                'video_id': doc.id,
                'status': 'pending',
                'timestamp': ''
            })
    
    print(f"Created new tracking file for videos")
    return []

def update_tracking_status(video_id: str, status: str, filename: str = 'video_tracking.csv'):
    """Update the status of a video in the tracking CSV."""
    # Read existing data
    rows = []
    with open(filename, 'r', newline='') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    # Update status for the video
    for row in rows:
        if row['video_id'] == video_id:
            row['status'] = status
            row['timestamp'] = datetime.now().isoformat()
    
    # Write updated data back
    with open(filename, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['video_id', 'status', 'timestamp'])
        writer.writeheader()
        writer.writerows(rows)

def process_video_document(video_doc, output_file: str = 'video_classifications.csv') -> str:
    """Process a single video document and generate its classification vector."""
    try:
        video_id = video_doc.id
        
        # Extract metadata
        metadata = get_video_metadata(video_doc)
        
        # Create classification text
        classification_text = create_classification_text(metadata)
        
        # Get classifications
        classifications = classify_text(classification_text)
        
        if classifications:
            # Save to CSV
            save_vector(video_id, classifications, output_file)
            # Update tracking status
            update_tracking_status(video_id, 'completed')
            return video_id
        else:
            # Update tracking status for failed classification
            update_tracking_status(video_id, 'failed')
            
    except Exception as e:
        print(f"Error processing video document {video_doc.id}: {e}")
        # Update tracking status for error
        update_tracking_status(video_doc.id, 'error')
    
    return None

def process_all_videos(batch_size: int = 100):
    """Process all videos in Firestore and generate classification vectors."""
    try:
        # Get or create tracking CSV
        processed_ids = create_tracking_csv()
        
        # Get all videos from Firestore
        videos_ref = db.collection('videos')
        docs = list(videos_ref.stream())  # Convert to list to avoid stream timeout
        
        processed_count = 0
        success_count = len(processed_ids)  # Start with previously completed count
        error_count = 0
        consecutive_failures = 0
        max_consecutive_failures = 3
        cooldown_period = 60  # 1 minute in seconds
        
        for doc in docs:
            # Skip already processed videos
            if doc.id in processed_ids:
                print(f"Skipping already processed video: {doc.id}")
                continue
            
            retry_attempt = 0
            while retry_attempt < max_consecutive_failures:
                try:
                    video_id = process_video_document(doc)
                    time.sleep(1)  # Basic rate limiting
                    processed_count += 1
                    
                    if video_id:
                        success_count += 1
                        consecutive_failures = 0  # Reset consecutive failures on success
                        break  # Exit retry loop on success
                    else:
                        retry_attempt += 1
                        consecutive_failures += 1
                        print(f"Failed attempt {retry_attempt} for video {doc.id}")
                        
                        if retry_attempt < max_consecutive_failures:
                            print(f"Waiting {cooldown_period} seconds before retry...")
                            time.sleep(cooldown_period)
                        else:
                            error_count += 1
                            print(f"Max retries reached for video {doc.id}, moving to next video")
                
                except Exception as e:
                    retry_attempt += 1
                    consecutive_failures += 1
                    print(f"Error on attempt {retry_attempt} for video {doc.id}: {str(e)}")
                    
                    if consecutive_failures >= max_consecutive_failures:
                        print("Maximum consecutive failures reached. Terminating process.")
                        return
                    
                    if retry_attempt < max_consecutive_failures:
                        print(f"Waiting {cooldown_period} seconds before retry...")
                        time.sleep(cooldown_period)
                    else:
                        error_count += 1
                        print(f"Max retries reached for video {doc.id}, moving to next video")
            
            if processed_count % 10 == 0:
                print(f"Processed {processed_count} new videos, {success_count} total successful, {error_count} errors...")
        
        print(f"\nFinished processing {processed_count} new videos.")
        print(f"Total successful: {success_count}")
        print(f"Total errors: {error_count}")
        
    except Exception as e:
        print(f"Error processing videos: {e}")

if __name__ == "__main__":
    # Process all videos
    process_all_videos() 