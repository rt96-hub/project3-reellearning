import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../home/presentation/widgets/video_action_buttons.dart';
import '../../../home/presentation/widgets/video_understanding_buttons.dart';
import '../widgets/video_player_widget.dart';
import '../../data/models/video_model.dart';
import '../../data/providers/video_controller_provider.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../../core/navigation/route_observer.dart';

final currentFilteredVideoIndexProvider = StateProvider<int>((ref) => 0);
final currentClassIdProvider = StateProvider<String?>((ref) => null);

class FilteredVideoFeedScreen extends ConsumerStatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;
  final String title;
  final String? classId;

  const FilteredVideoFeedScreen({
    Key? key,
    required this.videos,
    required this.initialIndex,
    required this.title,
    this.classId,
  }) : super(key: key);

  @override
  ConsumerState<FilteredVideoFeedScreen> createState() => _FilteredVideoFeedScreenState();
}

class _FilteredVideoFeedScreenState extends ConsumerState<FilteredVideoFeedScreen> with RouteAware {
  late final PageController _pageController;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(_handlePageChange);
    
    // Set initial index and class ID in post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentFilteredVideoIndexProvider.notifier).state = widget.initialIndex;
        if (widget.classId != null) {
          ref.read(currentClassIdProvider.notifier).state = widget.classId;
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppRouteObservers.shellObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    AppRouteObservers.shellObserver.unsubscribe(this);
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    debugPrint('FilteredVideoFeedScreen - Leaving screen');
    ref.read(videoControllerProvider.notifier).pauseAndRemember();
  }

  @override
  void didPopNext() {
    debugPrint('FilteredVideoFeedScreen - Returning to screen');
    ref.read(videoControllerProvider.notifier).resumeIfNeeded();
  }

  void _handlePageChange() {
    final newIndex = _pageController.page?.round() ?? 0;
    if (newIndex >= 0 && newIndex < widget.videos.length) {
      ref.read(currentFilteredVideoIndexProvider.notifier).state = newIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentFilteredVideoIndexProvider);
    final currentVideo = widget.videos[currentIndex];
    final userProfile = ref.watch(currentUserProvider);
    final currentClassId = ref.watch(currentClassIdProvider);

    if (userProfile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Video PageView
          if (widget.videos.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.videos.length,
              itemBuilder: (context, index) {
                return VideoPlayerWidget(
                  video: widget.videos[index],
                  autoPlay: index == currentIndex,
                  isMuted: _isMuted,
                  onMuteChanged: (muted) => setState(() => _isMuted = muted),
                  userId: userProfile.uid,  // Change from id to uid
                  classId: currentClassId,  // Pass class ID if available
                );
              },
            ),

          // Video Info Overlay
          if (widget.videos.isNotEmpty)
            Positioned(
              left: 16,
              right: 88, // Increased space for action buttons
              bottom: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Avatar
                      StreamBuilder<DocumentSnapshot>(
                        stream: (currentVideo.creator as DocumentReference).snapshots(),
                        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                          if (!snapshot.hasData) {
                            return const CircleAvatar(
                              radius: 20,
                              child: Icon(Icons.person),
                            );
                          }

                          final userData = snapshot.data!.data() as Map<String, dynamic>;
                          final profile = userData['profile'] as Map<String, dynamic>? ?? {};
                          final creatorId = snapshot.data!.id;

                          return GestureDetector(
                            onTap: () => context.go('/profile/$creatorId'),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: profile['avatarUrl'] != null
                                  ? NetworkImage(profile['avatarUrl'])
                                  : null,
                              child: profile['avatarUrl'] == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      // Text Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentVideo.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Creator Name
                            StreamBuilder<DocumentSnapshot>(
                              stream: (currentVideo.creator as DocumentReference).snapshots(),
                              builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final userData = snapshot.data!.data() as Map<String, dynamic>;
                                final profile = userData['profile'] as Map<String, dynamic>? ?? {};
                                final creatorId = snapshot.data!.id;

                                return GestureDetector(
                                  onTap: () => context.go('/profile/$creatorId'),
                                  child: Text(
                                    profile['displayName'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentVideo.description,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Action Buttons (right side)
          if (widget.videos.isNotEmpty)
            Positioned(
              right: 8,
              bottom: 80,
              child: SizedBox(  // Added SizedBox to constrain width
                width: 72,     // Specific width for action buttons column
                child: VideoActionButtons(
                  videoId: currentVideo.id,
                ),
              ),
            ),

          // Understanding Buttons (bottom)
          if (widget.videos.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: VideoUnderstandingButtons(
                videoId: currentVideo.id,
              ),
            ),
        ],
      ),
    );
  }
}
