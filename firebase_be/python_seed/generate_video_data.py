import os
from typing import Dict, List
import json
from datetime import datetime
import csv
from pydantic import BaseModel, Field
import firebase_admin
from firebase_admin import credentials, firestore
from openai import OpenAI
import random
from dotenv import load_dotenv

load_dotenv()

# Initialize OpenAI client
client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Initialize Firebase
cred = credentials.Certificate('../serviceAccountKey.json')

firebase_admin.initialize_app(cred)
db = firestore.client()

class VideoMetadata(BaseModel):
    title: str = Field(..., description="An engaging title for the video")
    description: str = Field(..., description="A dense description of video content based on transcript, title, and tags")
    tags: List[str] = Field(..., description="3-5 relevant hashtags")
    targetAudience: str = Field(..., description="The intended audience for this video")
    prerequisites: List[str] = Field(default_factory=list, description="List of prerequisite topics or skills")
    transcript: str = Field(..., description="The transcript of the video, simulate the transcript of everything the speaker would discuss in around a minute")
    short_description: str = Field(..., description="A short description of the video content")


class VideoBatch(BaseModel):
    videos: List[VideoMetadata] = Field(..., description="A batch of 10 related videos")

def generate_batch_video_metadata(topic_area: str) -> List[Dict]:
    """Generate metadata for multiple videos using OpenAI with Pydantic validation."""

    prompt = f"""Generate metadata for 10 related educational videos about {topic_area}.
    The videos should build upon each other in a logical sequence, getting progressively more advanced.
    Each video should have unique content while maintaining thematic consistency."""

    completion = client.beta.chat.completions.parse(
        model="gpt-4o-mini-2024-07-18",
        messages=[
            {"role": "system", "content": "Generate educational video metadata with transcripts. Each video should build upon previous ones in complexity."},
            {"role": "user", "content": prompt}
        ],
        response_format=VideoBatch

    )
    
    return [video.model_dump() for video in completion.choices[0].message.parsed.videos]

def create_video_document(metadata: Dict) -> Dict:
    """Create a properly formatted video document for Firestore."""
    now = datetime.utcnow()
    
    return {
        "creator": None,  # Will be set later
        "metadata": {
            "title": metadata["title"],
            "description": metadata["short_description"],
            "thumbnailUrl": "",  # Will be set later
            "videoUrl": "",      # Will be set later
            "duration": random.randint(30, 180),  # Random duration between 30-180 seconds
            "uploadedAt": now,
            "updatedAt": now,
            "transcript": metadata["transcript"]

        },
        "classification": {
            "explicit": {
                "hashtags": metadata["tags"],
                "description": metadata["description"],
                "targetAudience": metadata["targetAudience"],
                "prerequisites": metadata["prerequisites"]
            }
        },
        "engagement": {
            "views": 0,
            "likes": 0,
            "bookmarks": 0,
            "shares": 0,
            "completionRate": 0,
            "averageWatchTime": 0
        }
    }

def batch_upload_to_firestore(video_documents: List[Dict], batch_size: int = 500) -> List[str]:
    """Upload multiple video documents to Firestore in batches."""
    doc_ids = []
    
    # Process in batches to respect Firestore limits
    for i in range(0, len(video_documents), batch_size):
        batch = db.batch()
        current_batch = video_documents[i:i + batch_size]
        
        # Add each document to the batch
        for doc in current_batch:
            doc_ref = db.collection('videos').document()
            batch.set(doc_ref, doc)
            doc_ids.append(doc_ref.id)
        
        # Commit the batch
        batch.commit()
    
    return doc_ids

def write_videos_to_csv(videos: List[Dict], filename: str = "generated_videos.csv", first_write: bool = False):
    """Write video information to a CSV file.
    Args:
        videos: List of video dictionaries to write
        filename: Name of the CSV file
        first_write: If True, create new file with headers. If False, append to existing file.
    """
    mode = 'w' if first_write else 'a'
    with open(filename, mode, newline='', encoding='utf-8') as csvfile:
        fieldnames = ['id', 'title', 'topic_area']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        if first_write:
            writer.writeheader()
        
        for video in videos:
            writer.writerow(video)
    
    print(f"\nVideo information {'written to' if first_write else 'appended to'} {filename}")

def main():
    # Topic areas to generate videos for
    high_level_topics = [
        "Chemistry",
        "Physics",
        "Biology",
        "Mathematics",
        "Computer Science",
        "Economics",
        "History",
        "Geography",
        "Literature",
        "Art",
        "Music",
        "Philosophy",
        "Psychology",
        "Sociology",
        "Anthropology",
        "Geology",
        "Astronomy",
        "Engineering",
        "Medicine",
        "Law",
        "Business",
        "Finance",
        "Marketing",
    ]

    # Map each high-level topic to 3-5 specific subtopics
    topic_mapping = {
        "Chemistry": [
            "Organic Chemistry Fundamentals",
            "Chemical Bonding and Molecular Structure",
            "Thermodynamics and Chemical Reactions",
            "Electrochemistry Basics"
        ],
        "Physics": [
            "Classical Mechanics",
            "Electromagnetism Principles",
            "Quantum Physics Basics",
            "Thermodynamics and Energy"
        ],
        "Biology": [
            "Cell Biology and Structure",
            "Genetics and Inheritance",
            "Human Anatomy Essentials",
            "Ecology and Ecosystems"
        ],
        "Mathematics": [
            "Calculus Fundamentals",
            "Linear Algebra Basics",
            "Probability and Statistics",
            "Number Theory Introduction",
            "Mathematical Logic"
        ],
        "Computer Science": [
            "Programming Fundamentals",
            "Data Structures and Algorithms",
            "Database Systems",
            "Machine Learning Basics",
            "Web Development"
        ],
        "Economics": [
            "Microeconomics Principles",
            "Macroeconomics Basics",
            "International Trade",
            "Economic Policy"
        ],
        "History": [
            "Ancient Civilizations",
            "World War Era",
            "Industrial Revolution",
            "Modern History"
        ],
        "Geography": [
            "Physical Geography",
            "Human Geography",
            "Climate and Weather",
            "Cartography Basics"
        ],
        "Literature": [
            "Classical Literature",
            "Modern Fiction",
            "Poetry Analysis",
            "Literary Theory"
        ],
        "Art": [
            "Art History",
            "Drawing Techniques",
            "Color Theory",
            "Digital Art"
        ],
        "Music": [
            "Music Theory Basics",
            "Musical Instruments",
            "Music Composition",
            "Music History"
        ],
        "Philosophy": [
            "Ethics and Morality",
            "Logic and Reasoning",
            "Metaphysics Introduction",
            "Political Philosophy"
        ],
        "Psychology": [
            "Cognitive Psychology",
            "Developmental Psychology",
            "Social Psychology",
            "Abnormal Psychology",
            "Neuroscience Basics"
        ],
        "Sociology": [
            "Social Theory",
            "Cultural Studies",
            "Social Research Methods",
            "Social Institutions"
        ],
        "Anthropology": [
            "Cultural Anthropology",
            "Physical Anthropology",
            "Archaeological Methods",
            "Linguistic Anthropology"
        ],
        "Geology": [
            "Mineralogy Basics",
            "Plate Tectonics",
            "Rock Formation",
            "Earth's History"
        ],
        "Astronomy": [
            "Solar System",
            "Stellar Evolution",
            "Cosmology Basics",
            "Space Exploration"
        ],
        "Engineering": [
            "Mechanical Engineering Basics",
            "Electrical Engineering Fundamentals",
            "Civil Engineering Principles",
            "Software Engineering Practices",
            "Chemical Engineering Essentials"
        ],
        "Medicine": [
            "Human Physiology",
            "Medical Diagnosis",
            "Pharmacology Basics",
            "Public Health"
        ],
        "Law": [
            "Constitutional Law",
            "Criminal Law Basics",
            "Civil Law Introduction",
            "International Law"
        ],
        "Business": [
            "Business Management",
            "Entrepreneurship",
            "Strategic Planning",
            "Organizational Behavior"
        ],
        "Finance": [
            "Financial Markets",
            "Investment Basics",
            "Corporate Finance",
            "Personal Finance"
        ],
        "Marketing": [
            "Digital Marketing",
            "Market Research",
            "Brand Management",
            "Consumer Behavior"
        ]
    }

    # Create a flattened list of all topic areas
    topic_areas = []
    for high_level, subtopics in topic_mapping.items():
        topic_areas.extend(subtopics)
        print(f"Added {len(subtopics)} subtopics for {high_level}")

    print(f"\nTotal number of topic areas: {len(topic_areas)}")
    print("\nFirst few topic areas as example:")
    for topic in topic_areas[:5]:
        print(f"- {topic}")

    all_created_videos = []
    first_topic = True
    
    for topic_area in topic_areas:
        print(f"\nGenerating batch of videos for topic area: {topic_area}")
        
        topic_videos = []
        
        try:
            # Generate metadata for 10 related videos
            video_metadata_list = generate_batch_video_metadata(topic_area)
            
            # Create video documents
            video_documents = [create_video_document(metadata) for metadata in video_metadata_list]
            
            # Batch upload to Firestore
            doc_ids = batch_upload_to_firestore(video_documents)
            
            # Store created video information
            for i, doc_id in enumerate(doc_ids):
                video_info = {
                    "id": doc_id,
                    "title": video_metadata_list[i]["title"],
                    "topic_area": topic_area
                }
                topic_videos.append(video_info)
                all_created_videos.append(video_info)
            
            print(f"Created {len(doc_ids)} videos for {topic_area}")
            
            # Write this topic's videos to CSV
            write_videos_to_csv(topic_videos, first_write=first_topic)
            first_topic = False
            
        except Exception as e:
            print(f"Error processing topic {topic_area}: {str(e)}")
            # Still try to write any videos that were created before the error
            if topic_videos:
                write_videos_to_csv(topic_videos, first_write=first_topic)
                first_topic = False
    
    # Print final summary
    print("\nCreated Videos Summary:")
    for topic_area in topic_areas:
        print(f"\n{topic_area}:")
        topic_videos = [v for v in all_created_videos if v["topic_area"] == topic_area]
        for video in topic_videos:
            print(f"- {video['title']} (ID: {video['id']})")

if __name__ == "__main__":
    main() 