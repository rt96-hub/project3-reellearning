import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/filtered_videos_provider.dart';

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
                  final video = videos[index];
                  final thumbnailUrl = video['thumbnailUrl'] as String?;

                  return InkWell(
                    onTap: () {
                      // TODO: Navigate to video detail screen
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
