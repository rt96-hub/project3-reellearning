// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:reellearning_fe/src/features/videos/data/providers/video_provider.dart';
import 'package:flutter/services.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  
  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _debugInfo = '';
  Map<String, String> _videoStats = {};

  void _updateDebugInfo(String info) {
    if (mounted) {
      setState(() {
        _debugInfo += '$info\n';
      });
      print(info); // Also print to console
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _updateDebugInfo('Starting video initialization...');
      
      // Original code
      final videoUrl = await getVideoUrl(widget.videoUrl);
      
      // Testing with sample URL
      // const videoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
      _updateDebugInfo('Video URL: $videoUrl');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      
      // Initialize and catch any errors
      _updateDebugInfo('Initializing controller...');
      await _controller.initialize().then((_) {
        if (mounted) {
          // Collect video statistics
          _videoStats = {
            'Duration': '${_controller.value.duration}',
            'Size': '${_controller.value.size}',
            'Aspect Ratio': '${_controller.value.aspectRatio}',
            'Position': '${_controller.value.position}',
            'Is Playing': '${_controller.value.isPlaying}',
            'Is Looping': '${_controller.value.isLooping}',
            'Is Buffering': '${_controller.value.isBuffering}',
            'Volume': '${_controller.value.volume}',
            'Playback Speed': '${_controller.value.playbackSpeed}',
          };

          _updateDebugInfo('Controller initialized successfully');
          _updateDebugInfo('Video stats:\n${_videoStats.entries.join('\n')}');
          
          setState(() {
            _isInitialized = true;
          });
          _controller.play().then((_) {
            _updateDebugInfo('Video playback started');
          }).catchError((playError) {
            _updateDebugInfo('Play error: $playError');
          });
        }
      }).catchError((error) {
        _updateDebugInfo('Initialization error: $error');
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });

    } catch (e) {
      _updateDebugInfo('Setup error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: _hasError 
                ? Center(
                    child: Text(
                      'Error loading video\n\nDebug Info:\n$_debugInfo',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _isInitialized
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: Container(
                              color: Colors.transparent,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                if (_controller.value.isPlaying) {
                                  _controller.pause();
                                  _updateDebugInfo('Video paused');
                                } else {
                                  _controller.play();
                                  _updateDebugInfo('Video resumed');
                                }
                              });
                            },
                            child: Icon(
                              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
          ),
          // Debug information panel
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black.withOpacity(0.8),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Info:',
                    style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _debugInfo,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (_isInitialized) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Current Playback State:',
                      style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Position: ${_controller.value.position}\n'
                      'Buffering: ${_controller.value.isBuffering}\n'
                      'Playing: ${_controller.value.isPlaying}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _updateDebugInfo('Disposing controller');
    _controller.dispose();
    super.dispose();
  }
} 