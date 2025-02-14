import firebase_admin
from firebase_admin import credentials, firestore
import os
from dotenv import load_dotenv
from pinecone import Pinecone
from openai import OpenAI
import json
from typing import Dict, List

# Load environment variables
load_dotenv()

# Initialize Firebase
cred = credentials.Certificate('../serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def initialize_pinecone():
    """Initialize Pinecone client."""
    try:
        pc = Pinecone(api_key=os.getenv('PINECONE_API_KEY'))
        index = pc.Index(os.getenv('PINECONE_INDEX'))
        return index
    except Exception as e:
        print(f"Error initializing Pinecone: {str(e)}")
        return None

def get_embedding(text: str) -> List[float]:
    """Get embedding for text using OpenAI's API."""
    try:
        client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        response = client.embeddings.create(
            model="text-embedding-3-small",
            input=text,
            encoding_format="float"
        )
        return response.data[0].embedding
    except Exception as e:
        print(f"Error getting embedding: {str(e)}")
        return []

def get_suggested_tags(class_name: str, class_description: str, top_k: int = 20):
    """Get tag suggestions for a class based on its name and description."""
    try:
        # Initialize Pinecone
        index = initialize_pinecone()
        if not index:
            return {'error': 'Failed to initialize Pinecone'}

        # Combine class name and description for embedding
        combined_text = f"{class_name}. {class_description}"
        
        # Get embedding for the combined text
        embedding = get_embedding(combined_text)
        if not embedding:
            return {'error': 'Failed to generate embedding'}

        # Query Pinecone for similar vectors
        query_response = index.query(
            vector=embedding,
            top_k=top_k,
            include_metadata=True
        )

        # Extract tag IDs directly from Pinecone results
        tag_ids = [match.id for match in query_response.matches]
        print(f"\nFound {len(tag_ids)} matching tags in Pinecone")

        # Get tag details directly from videoTags collection
        tag_details = []
        for tag_id in tag_ids:
            tag_doc = db.collection('videoTags').document(tag_id).get()
            if tag_doc.exists:
                tag_data = tag_doc.to_dict()
                # Format to match the Dart TagData model
                tag_details.append({
                    'id': tag_id,
                    'tag': tag_data.get('tag', f'#{tag_id}'),  # Ensure tag has # prefix if needed
                    'relatedTags': tag_data.get('relatedTags', []),
                    'score': next((match.score for match in query_response.matches if match.id == tag_id), None)
                })
            else:
                print(f"Warning: Tag {tag_id} not found in videoTags collection")

        # Sort by score
        tag_details.sort(key=lambda x: x['score'] if x['score'] is not None else -1, reverse=True)

        return {
            'status': 'success',
            'tags': tag_details
        }

    except Exception as e:
        print(f"Error getting suggested tags: {str(e)}")
        return {'error': f'Error getting suggested tags: {str(e)}'}

def main():
    print("\nTesting Class Tag Suggestions:")
    print("-" * 30)
    
    # Test cases
    test_cases = [
        {
            'name': 'Modern Art History',
            'description': 'A comprehensive course covering art movements and artists from the late 19th century to present day. Focus on impressionism, cubism, and contemporary art.'
        },
        {
            'name': 'Digital Photography Basics',
            'description': 'Learn fundamental photography concepts, camera settings, composition techniques, and basic photo editing.'
        }
    ]
    
    for test_case in test_cases:
        print(f"\nTesting with class: {test_case['name']}")
        print(f"Description: {test_case['description']}")
        
        result = get_suggested_tags(test_case['name'], test_case['description'])
        print("\nSuggested Tags:")
        print(json.dumps(result, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main() 