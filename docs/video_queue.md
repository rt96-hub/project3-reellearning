# Video Queue Architecture and Future Plans

This document provides an overview of the video queuing system implemented for our project. It covers both the backend endpoint and the frontend integration, along with potential future extensions.

## 1. Backend - Firebase Function Endpoint

### Overview
- **Endpoint:** A Firebase Cloud Function (`get_videos`) is responsible for fetching a batch of video metadata from Firestore.
- **Data Returned:** The function returns a JSON object containing a list of videos. Each video object includes:
  - `id`, `title`, `description`, `videoUrl`, `thumbnailUrl`
  - `duration`, `uploadedAt`, `updatedAt`
  - A structured `creator` object (with a valid Firestore document path)
  - `engagement` metrics (views, likes, shares, completionRate, averageWatchTime)

### How it Works
- **Time-based Random Sampling:**
  - The function defines several time windows (e.g., last 7 days, last 30 days, last year) and assigns different probabilities for each.
  - It uses Firestore queries with an offset to provide a randomized selection of videos based on the window.
  - If the requested number of videos (limit) is not met by the time windows, it fetches additional videos randomly from the entire collection.

- **Creator Handling:**
  - Instead of returning the raw string of a DocumentReference, the function extracts the actual Firestore document path from the creator reference and returns it in a structured way.

- **Error Handling & Future Extensions:**
  - Currently, the function handles missing data using defaults. In future versions, caching mechanisms, engagement-based sorting, and recommendation integration may be added.

### Example Call
```bash
GET https://us-central1-<project-id>.cloudfunctions.net/get_videos?limit=5
```

## 2. Frontend - Video Data Integration

### Overview
The frontend uses the data provided by the Firebase Function to build and manage a video queue for endless scrolling.

### Key Components

#### a. Video Model
- **File:** `reellearning_fe/lib/src/features/videos/data/models/video_model.dart`
- **Purpose:** Defines the `VideoModel` class with all required fields including the creator (as a Firestore DocumentReference) and engagement metrics.

#### b. Video Provider
- **File:** `reellearning_fe/lib/src/features/videos/data/providers/video_provider.dart`
- **Purpose:** Implements `PaginatedVideoNotifier` that manages the list (queue) of videos.
  - Fetches a new batch of videos from the Firebase Function via HTTP GET.
  - Processes each video: converting GS URLs to downloadable URLs, formatting engagement data, and creating Firestore document references for creators.
  - Manages the queue size: initially appends videos until the queue reaches 50 with logic to remove the oldest batch when new videos are added.

#### c. Video State Provider
- **File:** `reellearning_fe/lib/src/features/videos/data/providers/video_state_provider.dart`
- **Purpose:** Provides the current video index being viewed. This is used by both the video provider and the home screen to manage the video queue intelligently.

#### d. Home Screen
- **File:** `reellearning_fe/lib/src/features/home/presentation/screens/home_screen.dart`
- **Purpose:** Renders the video feed using a `PageView.builder` which displays individual `VideoPlayerWidget`.
  - Handles scrolling events to trigger loading more videos when the user nears the end of the current queue.
  - Updates the current video index using the state provider, so the video provider can manage queue pruning efficiently.

#### e. Video Player Widget
- **File:** `reellearning_fe/lib/src/features/videos/presentation/widgets/video_player_widget.dart`
- **Purpose:** Initializes the video player controller when a video is about to be played. Downloads the video on-demand, ensuring efficient usage of resources.

### Data Flow Summary
1. **Fetching Data:**
   - The function is called with the desired limit, and returns a list of video objects.
2. **Queue Building:**
   - The `PaginatedVideoNotifier` processes and appends new videos to the existing queue.
   - When the queue exceeds a certain threshold (e.g., 50 videos), older entries are pruned in fixed batches.
3. **Displaying Videos:**
   - The home screen uses a `PageView` to display videos. Only the current video is downloaded and played, while others’ data remains in the queue.
4. **User Interaction:**
   - Scrolling triggers additional loading if the proximity to the end is detected.
   - The application handles duplicate videos for now, with future enhancements to a recommendation system.

## 3. Future Extensions

- **Engagement-Based Sorting and Recommendations:**
  - Enhance the backend to sort videos based on engagement metrics or user-specific data (e.g., classId, userId).
- **Caching and Performance Improvements:**
  - Implement caching on the backend for repeated queries.
  - Preload portions of upcoming videos to ensure smooth playback transitions.
- **More Intelligent Queue Management:**
  - Track which videos have been watched and adjust retrieval accordingly.
  - Potentially manage multiple queues (e.g., prioritized for recommendations vs. random).

This document should serve as a comprehensive overview of how our video queuing system is structured, how data flows from the backend to the frontend, and what improvements we plan to implement in future iterations.
