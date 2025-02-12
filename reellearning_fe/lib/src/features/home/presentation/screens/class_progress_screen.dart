import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../data/models/class_model.dart';
import '../widgets/progress_report_modal.dart';
import '../widgets/loading_character_animation.dart';
import 'class_report_detail_screen.dart';

class LoadingCharacterAnimation extends StatefulWidget {
  final Color color;
  
  const LoadingCharacterAnimation({
    super.key,
    required this.color,
  });

  @override
  State<LoadingCharacterAnimation> createState() => _LoadingCharacterAnimationState();
}

class _LoadingCharacterAnimationState extends State<LoadingCharacterAnimation> {
  final List<OverlayEntry> _activeOverlays = [];
  final random = math.Random();
  final GlobalKey _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _startEmittingCharacters());
  }

  @override
  void dispose() {
    for (final overlay in _activeOverlays) {
      overlay.remove();
    }
    _activeOverlays.clear();
    super.dispose();
  }

  void _startEmittingCharacters() {
    if (!mounted) return;
    
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _emitCharacter();
      _emitCharacter(); // Emit two at once for better effect
      _startEmittingCharacters();
    });
  }

  Offset _getButtonCenter() {
    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    
    final position = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    
    // Get the parent button's width to find its center
    final RenderBox? parentBox = context.findRenderObject() as RenderBox?;
    final parentWidth = parentBox?.size.width ?? 200; // Fallback width
    
    return Offset(
      position.dx + (parentWidth / 2),
      position.dy + (buttonSize.height / 2),
    );
  }

  void _emitCharacter() {
    const availableSymbols = '∑∏∆∇∫≈≠∞αβγπΩ∄∋=+%';
    final symbol = availableSymbols[random.nextInt(availableSymbols.length)];
    final buttonCenter = _getButtonCenter();
    
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 40 + random.nextDouble() * 40;
    // Set size once at creation instead of during animation
    final size = 16.0;

    late final OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final dx = math.cos(angle) * speed * value;
                  final dy = math.sin(angle) * speed * value;
                  
                  return Positioned(
                    left: buttonCenter.dx + dx - (size / 2),
                    top: buttonCenter.dy + dy - (size / 2),
                    child: Opacity(
                      opacity: 1.0 - (value * 0.8),
                      child: Transform.rotate(
                        angle: value * math.pi,
                        child: Text(
                          symbol,
                          style: TextStyle(
                            fontSize: size,
                            color: widget.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  overlay.remove();
                  _activeOverlays.remove(overlay);
                },
              ),
            ],
          ),
        );
      },
    );

    _activeOverlays.add(overlay);
    Overlay.of(context).insert(overlay);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _buttonKey,
      width: 1,  // Make this tiny so it doesn't affect layout
      height: 1,
    );
  }
}

class ClassProgressScreen extends ConsumerStatefulWidget {
  final String classId;

  const ClassProgressScreen({
    super.key,
    required this.classId,
  });

  @override
  ConsumerState<ClassProgressScreen> createState() => _ClassProgressScreenState();
}

class _ClassProgressScreenState extends ConsumerState<ClassProgressScreen> {
  bool _isModalOpen = false;

  void _showGenerateReportModal(BuildContext context, String classId) {
    setState(() {
      _isModalOpen = true;
    });
    
    showDialog(
      context: context,
      builder: (context) => ProgressReportModal(
        sourceType: 'class',
        sourceId: classId,
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isModalOpen = false;
        });
      }
    });
  }

  String _formatDate(Timestamp timestamp) {
    return DateFormat.yMMMd().format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    // Watch the report generation state
    final isGenerating = ref.watch(reportGenerationInProgressProvider(widget.classId));

    return PopScope(
      canPop: !_isModalOpen, // Only block navigation when modal is open
      onPopInvoked: (didPop) {
        print('[ClassProgressScreen] Back navigation attempted, modal open: $_isModalOpen');
        if (_isModalOpen) {
          // Close the modal when back gesture is detected and modal is open
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Class Progress Report'),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('classes')
              .doc(widget.classId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final classModel = ClassModel.fromMap(widget.classId, data);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('classProgressReports')
                        .where('classId', isEqualTo: FirebaseFirestore.instance.doc('/classes/${widget.classId}'))
                        .where('status', isEqualTo: 'in_progress')
                        .limit(1)
                        .snapshots(),
                    builder: (context, reportSnapshot) {
                      if (reportSnapshot.hasError) {
                      }

                      if (reportSnapshot.hasData) {
                        final hasInProgressReport = reportSnapshot.data!.docs.isNotEmpty;

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final previousState = ref.read(reportGenerationInProgressProvider(widget.classId));
                          if (previousState != hasInProgressReport) {
                            ref.read(reportGenerationInProgressProvider(widget.classId).notifier).state = hasInProgressReport;
                          }
                        });
                      }

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isGenerating ? null : () => _showGenerateReportModal(context, widget.classId),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isGenerating) 
                                    const Icon(Icons.add, color: Colors.white),
                                  if (!isGenerating) 
                                    const SizedBox(width: 8),
                                  Text(isGenerating ? 'Report in Progress' : 'Generate Report'),
                                ],
                              ),
                              if (isGenerating)
                                LoadingCharacterAnimation(color: Colors.blue),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('classProgressReports')
                          .where('classId', isEqualTo: FirebaseFirestore.instance.doc('/classes/${widget.classId}'))
                          .where('status', isEqualTo: 'complete')
                          .orderBy('createdAt', descending: true)
                          .limit(10)
                          .snapshots(),
                      builder: (context, reportsSnapshot) {
                        if (reportsSnapshot.hasError) {
                          return Center(child: Text('Error: ${reportsSnapshot.error}'));
                        }

                        if (!reportsSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final reports = reportsSnapshot.data!.docs;

                        if (reports.isEmpty) {
                          return const Center(
                            child: Text('No reports generated yet'),
                          );
                        }

                        return ListView.builder(
                          itemCount: reports.length,
                          itemBuilder: (context, index) {
                            final report = reports[index].data() as Map<String, dynamic>;
                            return Card(
                              child: ListTile(
                                title: Text('${report['type'].toString().toUpperCase()} Report'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('From: ${_formatDate(report['startDate'] as Timestamp)}'),
                                    Text('To: ${_formatDate(report['endDate'] as Timestamp)}'),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ClassReportDetailScreen(
                                        reportId: reports[index].id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
} 