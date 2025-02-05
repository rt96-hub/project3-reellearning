import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../data/models/video_model.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoModel video;
  final bool autoPlay;
  final bool looping;

  const VideoPlayerWidget({
    Key? key,
    required this.video,
    this.autoPlay = true,
    this.looping = true,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String _debugInfo = 'Initializing...';

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
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: _isInitialized && _controller != null
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : const CircularProgressIndicator(),
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