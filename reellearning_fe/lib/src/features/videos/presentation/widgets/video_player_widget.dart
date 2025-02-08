import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/video_model.dart';
import '../../data/providers/video_controller_provider.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  final VideoModel video;
  final bool autoPlay;
  final bool looping;
  final bool isMuted;
  final ValueChanged<bool> onMuteChanged;
  final String userId;
  final String? classId;

  const VideoPlayerWidget({
    Key? key,
    required this.video,
    this.autoPlay = true,
    this.looping = true,
    required this.isMuted,
    required this.onMuteChanged,
    required this.userId,
    this.classId,
  }) : super(key: key);

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showPlayPauseOverlay = false;
  bool _showSeekOverlay = false;
  String _seekDirection = '';
  bool _hasRecordedView = false;  // Track if view has been recorded
  bool _isActivelyPlaying = false;  // Track if video is actively playing

  @override
  void initState() {
    super.initState();
    debugPrint('Initializing VideoPlayerWidget for video: ${widget.video.id}');
    _initializeController();
  }

  Future<void> _recordView() async {
    if (_hasRecordedView) {
      debugPrint('View already recorded for this session, skipping...');
      return;
    }
    
    // Set flag immediately to prevent concurrent calls
    _hasRecordedView = true;
    debugPrint('Recording view for video: ${widget.video.id}');
    
    try {
      final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.video.id);
      final userViewsRef = FirebaseFirestore.instance.collection('userViews');
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      
      // Create view record with auto-generated ID
      final docRef = await userViewsRef.add({
        'userId': userRef,  // Reference to users collection
        'videoId': videoRef,  // Reference to videos collection
        'classId': widget.classId != null ? [
          FirebaseFirestore.instance.collection('classes').doc(widget.classId)
        ] : [],
        'watchedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Created view record with ID: ${docRef.id}');

      // Increment video views
      await videoRef.update({
        'engagement.views': FieldValue.increment(1),
      });

      debugPrint('Updated video view count');
    } catch (e) {
      debugPrint('Error recording view: $e');
      // Reset flag if recording failed
      _hasRecordedView = false;
    }
  }

  void _checkProgress() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    // Only check progress if video is actively playing
    if (!_controller!.value.isPlaying) {
      _isActivelyPlaying = false;
      return;
    }

    // Update active playing state
    if (!_isActivelyPlaying) {
      _isActivelyPlaying = true;
      debugPrint('Video started playing: ${widget.video.id}');
    }
    
    final duration = _controller!.value.duration;
    final position = _controller!.value.position;
    final progress = position.inMilliseconds / duration.inMilliseconds;
    
    // Record view when 90% of video is watched and it's actively playing
    if (progress >= 0.9 && !_hasRecordedView && _isActivelyPlaying) {
      debugPrint('Video reached 90% completion. Progress: ${(progress * 100).toStringAsFixed(1)}%');
      debugPrint('Position: ${position.inSeconds}s / Duration: ${duration.inSeconds}s');
      _recordView();
    }
  }

  Future<void> _initializeController() async {
    debugPrint('Initializing video controller with URL: ${widget.video.videoUrl}');
    
    try {
      final videoUrl = await widget.video.getDownloadUrl();
      if (!mounted) {
        debugPrint('Widget unmounted during initialization');
        return;
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      
      if (!mounted) {
        debugPrint('Widget unmounted after controller initialization');
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
      });

      // Register the controller with the provider
      ref.read(videoControllerProvider.notifier).setController(controller);

      if (widget.autoPlay) {
        controller.play();
      }
      
      controller.setLooping(widget.looping);
      controller.setVolume(widget.isMuted ? 0 : 1);
      
      // Add listener for video progress
      controller.addListener(_checkProgress);
      debugPrint('Video controller initialized successfully');
      
    } catch (e) {
      debugPrint('Error initializing video controller: $e');
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showPlayPauseOverlay = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showPlayPauseOverlay = false;
        });
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    widget.onMuteChanged(!widget.isMuted);
  }

  void _handleDoubleTapDown(TapDownDetails details, BuildContext context) {
    if (_controller == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;
    final seekDuration = const Duration(seconds: 5);

    if (tapPosition < screenWidth / 3) {
      final newPosition = _controller!.value.position - seekDuration;
      _controller!.seekTo(newPosition);
      setState(() {
        _showSeekOverlay = true;
        _seekDirection = 'backward';
      });
    } else if (tapPosition > (screenWidth * 2 / 3)) {
      final newPosition = _controller!.value.position + seekDuration;
      _controller!.seekTo(newPosition);
      setState(() {
        _showSeekOverlay = true;
        _seekDirection = 'forward';
      });
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showSeekOverlay = false;
        });
      }
    });
  }

  @override
  void dispose() {
    debugPrint('Disposing VideoPlayerWidget for video: ${widget.video.id}');
    if (_controller != null) {
      _controller!.removeListener(_checkProgress);
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('Widget updated. Old video: ${oldWidget.video.id}, New video: ${widget.video.id}');
    
    // Reset tracking state when video changes
    if (oldWidget.video.id != widget.video.id) {
      _hasRecordedView = false;
      _isActivelyPlaying = false;
      debugPrint('Reset view tracking state for new video: ${widget.video.id}');
    }
    
    if (oldWidget.isMuted != widget.isMuted) {
      _controller?.setVolume(widget.isMuted ? 0 : 1);
    }
  }

  double _calculateOptimalScale(BuildContext context) {
    if (_controller == null) return 1.0;

    final screenSize = MediaQuery.of(context).size;
    final videoSize = _controller!.value.size;

    // Calculate video aspect ratio
    final videoAspectRatio = videoSize.width / videoSize.height;
    // Calculate screen aspect ratio
    final screenAspectRatio = screenSize.width / screenSize.height;

    // If video is wider than screen (relative to their heights)
    if (videoAspectRatio > screenAspectRatio) {
      // Scale based on height to fill screen vertically
      return screenSize.height / videoSize.height;
    } else {
      // Scale based on width to fill screen horizontally
      return screenSize.width / videoSize.width;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTapDown: (details) => _handleDoubleTapDown(details, context),
      child: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.black,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 3,
              child: Stack(
                children: [
                  Container(
                    color: Colors.white.withOpacity(0.3),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _controller!,
                    builder: (context, VideoPlayerValue value, child) {
                      final widthFactor = value.duration.inMilliseconds > 0
                          ? value.position.inMilliseconds / value.duration.inMilliseconds
                          : 0.0;
                      return FractionallySizedBox(
                        widthFactor: widthFactor.clamp(0.0, 1.0),
                        child: Container(
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          if (_showSeekOverlay)
            Positioned(
              left: _seekDirection == 'backward' ? 32 : null,
              right: _seekDirection == 'forward' ? 32 : null,
              top: MediaQuery.of(context).size.height / 2 - 25,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _seekDirection == 'forward' ? Icons.forward_5 : Icons.replay_5,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),

          if (_showPlayPauseOverlay)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),

          Positioned(
            top: 48,
            right: 16,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}