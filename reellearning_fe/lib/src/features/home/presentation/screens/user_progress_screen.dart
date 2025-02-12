import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/progress_report_modal.dart';
import 'user_report_detail_screen.dart';

// Add a provider to manage the loading dots animation
final _loadingDotsProvider = StateProvider<String>((ref) => '.');

class UserProgressScreen extends ConsumerStatefulWidget {
  final String? userId;
  const UserProgressScreen({super.key, this.userId});

  @override
  ConsumerState<UserProgressScreen> createState() => _UserProgressScreenState();
}

class _UserProgressScreenState extends ConsumerState<UserProgressScreen> {
  bool _isModalOpen = false;

  void _showGenerateReportModal(BuildContext context, String userId) {
    setState(() {
      _isModalOpen = true;
    });
    
    showDialog(
      context: context,
      builder: (context) => ProgressReportModal(
        sourceType: 'user',
        sourceId: userId,
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
    final isGenerating = widget.userId != null ? ref.watch(reportGenerationInProgressProvider(widget.userId!)) : false;

    return PopScope(
      canPop: !_isModalOpen, // Only block navigation when modal is open
      onPopInvoked: (didPop) {
        print('[UserProgressScreen] Back navigation attempted, modal open: $_isModalOpen');
        if (_isModalOpen) {
          // Close the modal when back gesture is detected and modal is open
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress Report'),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .snapshots(),
          builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final profile = userData['profile'] as Map<String, dynamic>? ?? {};
            final displayName = profile['displayName'] ?? 'Unknown User';

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.userId != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('userProgressReports')
                          .where('userId', isEqualTo: FirebaseFirestore.instance.doc('/users/${widget.userId}'))
                          .where('status', isEqualTo: 'in_progress')
                          .limit(1)
                          .snapshots(),
                      builder: (context, reportSnapshot) {
                        if (reportSnapshot.hasError) {
                        }

                        if (reportSnapshot.hasData) {
                          final hasInProgressReport = reportSnapshot.data!.docs.isNotEmpty;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final previousState = ref.read(reportGenerationInProgressProvider(widget.userId!));
                            if (previousState != hasInProgressReport) {
                              ref.read(reportGenerationInProgressProvider(widget.userId!).notifier).state = hasInProgressReport;
                            }
                          });
                        }

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isGenerating ? null : () => _showGenerateReportModal(context, widget.userId!),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isGenerating) 
                                  const Icon(Icons.add, color: Colors.white),
                                if (!isGenerating) 
                                  const SizedBox(width: 8),
                                Text(isGenerating ? 'Report in Progress' : 'Generate Report'),
                                if (isGenerating) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ],
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
                  if (widget.userId != null)
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('userProgressReports')
                            .where('userId', isEqualTo: FirebaseFirestore.instance.doc('/users/${widget.userId}'))
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
                                        builder: (context) => UserReportDetailScreen(
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