import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/providers/filtered_videos_provider.dart';
import '../../data/models/video_model.dart';
import './filtered_video_feed_screen.dart';

class VideoGridScreen extends ConsumerStatefulWidget {
  final String title;
  final String sourceType;  // 'user' or 'class'
  final String sourceId;   // userId or classId
  final String videoType;  // 'likes', 'bookmarks', or 'videos'

  const VideoGridScreen({
    super.key,
    required this.title,
    required this.sourceType,
    required this.sourceId,
    required this.videoType,
  });

  @override
  ConsumerState<VideoGridScreen> createState() => _VideoGridScreenState();
}

class _VideoGridScreenState extends ConsumerState<VideoGridScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(filteredVideosProvider.notifier).loadVideos(
        widget.sourceType,
        widget.sourceId,
        widget.videoType,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(filteredVideosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: videosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (videos) => videos.isEmpty
            ? const Center(
                child: Text('No videos found'),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 16 / 9,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final videoData = videos[index];
                  final thumbnailUrl = videoData['thumbnailUrl'] as String?;

                  return InkWell(
                    onTap: () {
                      // Convert the list of video maps to VideoModel objects
                      final videoModels = videos.map((v) {
                        final engagement = v['engagement'] as Map<String, dynamic>;
                        final creatorData = v['creator'] as Map<String, dynamic>;
                        final creatorPath = creatorData['path'] as String;
                        final creatorRef = FirebaseFirestore.instance.doc(creatorPath.trim().replaceAll(RegExp(r'^/+|/+$'), ''));

                        return VideoModel(
                          id: v['id'] as String,
                          title: v['title'] as String,
                          description: v['description'] as String,
                          videoUrl: v['videoUrl'] as String,
                          thumbnailUrl: v['thumbnailUrl'] as String? ?? '',
                          duration: (v['duration'] as num).toDouble(),
                          uploadedAt: DateTime.parse(v['uploadedAt'] as String),
                          updatedAt: DateTime.parse(v['updatedAt'] as String),
                          creator: creatorRef,
                          engagement: VideoEngagement(
                            views: engagement['views'] as int? ?? 0,
                            likes: engagement['likes'] as int? ?? 0,
                            shares: engagement['shares'] as int? ?? 0,
                            completionRate: (engagement['completionRate'] as num?)?.toDouble() ?? 0.0,
                            averageWatchTime: (engagement['averageWatchTime'] as num?)?.toDouble() ?? 0.0,
                          ),
                        );
                      }).toList();
                      
                      // Navigate to the filtered feed screen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FilteredVideoFeedScreen(
                            videos: videoModels,
                            initialIndex: index,
                            title: widget.title,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.video_library, size: 32),
                              ),
                            )
                          : const Icon(Icons.video_library, size: 32),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
