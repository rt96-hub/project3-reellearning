import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../data/models/video_model.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoModel video;
  final bool autoPlay;
  final bool looping;
  final bool isMuted;
  final ValueChanged<bool> onMuteChanged;

  const VideoPlayerWidget({
    Key? key,
    required this.video,
    this.autoPlay = true,
    this.looping = true,
    required this.isMuted,
    required this.onMuteChanged,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String _debugInfo = 'Initializing...';
  bool _showPlayPauseOverlay = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    debugPrint('Initializing video with URL: ${widget.video.videoUrl}');
    setState(() {
      _debugInfo = 'Loading URL: ${widget.video.videoUrl}';
    });
    
    try {
      final videoUrl = await widget.video.getDownloadUrl();
      if (!mounted) return;

      setState(() {
        _debugInfo = 'Got download URL: $videoUrl\nInitializing controller...';
      });

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _debugInfo = '''
Debug Info:
File: ${widget.video.id}
URL: $videoUrl
Duration: ${controller.value.duration}
Dimensions: ${controller.value.size.width.toInt()}x${controller.value.size.height.toInt()}
Position: ${controller.value.position}
''';
      });

      debugPrint('Video initialized successfully');
      debugPrint('Video size: ${controller.value.size}');
      debugPrint('Video duration: ${controller.value.duration}');
      
      // Set initial volume based on isMuted prop
      controller.setVolume(widget.isMuted ? 0 : 1);
      
      if (widget.autoPlay) {
        controller.play();
      }
      controller.setLooping(widget.looping);

      // Update debug info periodically
      controller.addListener(() {
        if (mounted) {
          setState(() {
            _debugInfo = '''
Debug Info:
File: ${widget.video.id}
URL: $videoUrl
Duration: ${controller.value.duration}
Dimensions: ${controller.value.size.width.toInt()}x${controller.value.size.height.toInt()}
Position: ${controller.value.position}
''';
          });
        }
      });

    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _debugInfo = 'Error: $e';
        });
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMuted != widget.isMuted) {
      _controller?.setVolume(widget.isMuted ? 0 : 1);
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

    // Hide the overlay after a short delay
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Video Player with Tap Handler
        GestureDetector(
          onTap: _togglePlayPause,
          child: Center(
            child: _isInitialized && _controller != null
              ? AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                )
              : const CircularProgressIndicator(),
          ),
        ),

        // Play/Pause Overlay
        if (_showPlayPauseOverlay && _isInitialized && _controller != null)
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

        // Mute/Unmute Button
        if (_isInitialized && _controller != null)
          Positioned(
            top: 16,
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

        // Debug Info Overlay
        Positioned(
          top: 40,
          left: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _debugInfo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ),
      ],
    );
  }
} 