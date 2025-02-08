import csv
from moviepy.video.VideoClip import ColorClip, TextClip, VideoClip
from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
import os
from pathlib import Path
import numpy as np
import random
import firebase_admin
from firebase_admin import credentials, storage, firestore
import tempfile
import shutil
import time
from uuid import uuid4

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('../serviceAccountKey.json')
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'reellearning-prj3.firebasestorage.app'  # Replace with your Firebase project ID
    })

bucket = storage.bucket()
db = firestore.client()

# Create directory for local video storage if it doesn't exist
LOCAL_VIDEO_DIR = 'generated_videos'
if not os.path.exists(LOCAL_VIDEO_DIR):
    os.makedirs(LOCAL_VIDEO_DIR)

def update_csv_status(video_id: str, processed: bool = True):
    """
    Update the processed status in the CSV file for a given video ID.
    
    Args:
        video_id: The unique identifier for the video
        processed: Whether the video was successfully processed
    """
    temp_file = 'generated_videos_temp.csv'
    with open('generated_videos.csv', 'r', encoding='utf-8') as file_in, \
         open(temp_file, 'w', newline='', encoding='utf-8') as file_out:
        reader = csv.DictReader(file_in)
        fieldnames = list(reader.fieldnames) if reader.fieldnames else []
        if 'processed' not in fieldnames:
            fieldnames.append('processed')
        
        writer = csv.DictWriter(file_out, fieldnames=fieldnames)
        writer.writeheader()
        
        # Reset file pointer to start
        file_in.seek(0)
        next(reader)  # Skip header
        
        for row in reader:
            if row['id'] == video_id:
                row['processed'] = str(processed).lower()
            elif 'processed' not in row:
                row['processed'] = 'false'
            writer.writerow(row)
    
    # Replace original file with updated file
    shutil.move(temp_file, 'generated_videos.csv')

def upload_to_storage(video_data: bytes, video_id: str) -> str:
    """
    Upload video data to Firebase Storage and make it publicly accessible.
    
    Args:
        video_data: The video file data
        video_id: The unique identifier for the video
        
    Returns:
        The public download URL of the uploaded video
    """

    # You can assign whatever you want.
    token = uuid4()
    metadata = {"firebaseStorageDownloadTokens": token}


    blob = bucket.blob(f'videos/{video_id}.mp4')

    # Assign the token as metadata
    blob.metadata = metadata

    blob.upload_from_string(
        video_data,
        content_type='video/mp4'
    )
    
    # Make the blob publicly readable
    blob.make_public()
    
    # Return both the storage URL and the public download URL
    storage_url = f"gs://{bucket.name}/videos/{video_id}.mp4"
    
    return storage_url  # Return the public URL instead of storage URL

def update_firestore_video(video_id: str, video_url: str):
    """
    Update the video document in Firestore with the video URL.
    
    Args:
        video_id: The unique identifier for the video
        video_url: The storage URL of the video
    """
    video_ref = db.collection('videos').document(video_id)
    video_ref.update({
        'metadata.videoUrl': video_url,
        'metadata.updatedAt': firestore.SERVER_TIMESTAMP
    })

def create_video(title: str, topic_area: str, subject: str, video_id: str, duration: int = 8, save_locally: bool = False):
    """
    Create a video and upload it to Firebase Storage.
    
    Args:
        title: The video title
        topic_area: The topic area of the video
        subject: The subject category
        video_id: The unique identifier for the video
        duration: Length of video in seconds
        save_locally: If True, also save the video to local filesystem
    
    Returns:
        The storage URL of the uploaded video
    """
    video_url = None
    temp_file = None
    try:
        # Video dimensions for portrait mode (vertical video)
        width, height = 1080, 1920  # Swapped for vertical orientation
        
        # Generate random light color (ensuring it's light by using high base values)
        base_color = np.array([
            random.randint(160, 240),  # Red
            random.randint(160, 240),  # Green
            random.randint(160, 240)   # Blue
        ])
        
        # Create pulsing background
        def make_frame(t):
            # Create a subtle pulse effect
            pulse = np.sin(2 * np.pi * t / 4) * 10  # 4-second cycle, ±10 intensity
            color = base_color + pulse  # Base color + pulse
            color = np.clip(color, 0, 255)  # Ensure values stay in valid range
            return np.tile(color.reshape((1, 1, 3)), (height, width, 1)).astype('uint8')
        
        background = VideoClip(make_frame, duration=duration)
        
        # Create text clips - adjusted positions for vertical layout
        title_clip = TextClip(
            text=title,
            font_size=30,
            color='black',
            size=(width-100, None),  # Adjusted margin for vertical layout
            method='label',
            text_align='center',
            horizontal_align='center',
            vertical_align='center',
            transparent=True,
            font='DejaVuSans',
            duration=duration,
        ).with_position(('center', height//4))
        
        topic_clip = TextClip(
            text=f"Topic: {topic_area}",
            font_size=30,
            color='black',
            method='label',
            text_align='center',
            horizontal_align='center',
            vertical_align='center',
            transparent=True,
            font='DejaVuSans',
            duration=duration,
        ).with_position(('center', height//2))
        
        subject_clip = TextClip(
            text=f"Subject: {subject}",
            font_size=30,
            color='black',
            method='label',
            text_align='center',
            horizontal_align='center',
            vertical_align='center',
            transparent=True,
            font='DejaVuSans',
            duration=duration,
        ).with_position(('center', (height*3)//4))
        
        # Combine clips
        video = CompositeVideoClip([
            background,
            title_clip,
            topic_clip,
            subject_clip
        ])
        
        # Create a temporary file to store the video
        temp_file = tempfile.NamedTemporaryFile(suffix='.mp4', delete=False)
        temp_file.close()  # Close immediately to avoid file handle issues
        
        # Write video to temporary file
        video.write_videofile(
            temp_file.name,
            fps=2,  # Increased FPS for smoother playback
            codec='libx264',  # Changed to more widely supported codec
            audio=False,
            preset='medium',
            bitrate='2000k',  # Reduced bitrate for better streaming
            ffmpeg_params=[
                '-pix_fmt', 'yuv420p',  # Required for web playback
                '-profile:v', 'baseline',  # Most compatible profile
                '-level', '3.0',
                '-movflags', '+faststart'  # Enables fast start for web playback
            ]
        )
        
        # Close clips to free up memory
        video.close()
        title_clip.close()
        topic_clip.close()
        subject_clip.close()
        background.close()
        
        # Small delay to ensure file handles are released
        time.sleep(1)
        
        # Save locally if requested
        if save_locally:
            local_path = os.path.join(LOCAL_VIDEO_DIR, f"{video_id}.mp4")
            shutil.copy2(temp_file.name, local_path)
            print(f"Saved video locally to: {local_path}")
        
        # Read and upload the video file
        with open(temp_file.name, 'rb') as video_file:
            video_data = video_file.read()
            video_url = upload_to_storage(video_data, video_id)
            update_firestore_video(video_id, video_url)
        
        return video_url
        
    finally:
        # Cleanup temporary file
        if temp_file and os.path.exists(temp_file.name):
            try:
                time.sleep(1)  # Give extra time for file handles to be released
                os.unlink(temp_file.name)
            except Exception as e:
                print(f"Warning: Could not delete temporary file {temp_file.name}: {str(e)}")

def main():
    # Read CSV file
    with open('generated_videos.csv', 'r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        fieldnames = list(reader.fieldnames) if reader.fieldnames else []
        
        # Process each row
        for i, row in enumerate(reader):
            video_id = row['id']
            
            # Skip if already processed
            if 'processed' in row and row['processed'].lower() == 'true':
                print(f"Skipping video {i+1}: {row['title']} (already processed)")
                continue
                
            title = row['title']
            topic_area = row['topic_area']
            subject = row['subject']
            
            print(f"\nGenerating video {i+1}: {title}")
            try:
                video_url = create_video(
                    title=title,
                    topic_area=topic_area,
                    subject=subject,
                    video_id=video_id,
                    save_locally=False  # Set to True to save videos locally
                )
                print(f"Successfully created and uploaded video: {video_url}")
                update_csv_status(video_id, True)
            except Exception as e:
                print(f"Error processing video {video_id}: {str(e)}")
                update_csv_status(video_id, False)

if __name__ == "__main__":
    main() 