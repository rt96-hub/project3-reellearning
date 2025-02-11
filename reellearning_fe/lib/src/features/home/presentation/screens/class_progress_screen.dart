import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../data/models/class_model.dart';
import '../widgets/progress_report_modal.dart';
import 'class_report_detail_screen.dart';

class ClassProgressScreen extends ConsumerWidget {
  final String classId;

  const ClassProgressScreen({
    super.key,
    required this.classId,
  });

  void _showGenerateReportModal(BuildContext context, String classId) {
    showDialog(
      context: context,
      builder: (context) => ProgressReportModal(
        sourceType: 'class',
        sourceId: classId,
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the report generation state
    final isGenerating = ref.watch(reportGenerationInProgressProvider(classId));
    print('Report generation state for class $classId: $isGenerating');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Progress Report'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Error fetching class data: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final classModel = ClassModel.fromMap(classId, data);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('classProgressReports')
                      .where('classId', isEqualTo: FirebaseFirestore.instance.doc('/classes/${classId}'))
                      .where('status', isEqualTo: 'in_progress')
                      .limit(1)
                      .snapshots(),
                  builder: (context, reportSnapshot) {
                    if (reportSnapshot.hasError) {
                      print('Error checking in-progress reports: ${reportSnapshot.error}');
                    }

                    if (reportSnapshot.hasData) {
                      final hasInProgressReport = reportSnapshot.data!.docs.isNotEmpty;
                      print('In-progress report check:\n'
                          'Has in-progress report: $hasInProgressReport\n'
                          'Documents: ${reportSnapshot.data!.docs.map((doc) => doc.data())}');

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final previousState = ref.read(reportGenerationInProgressProvider(classId));
                        if (previousState != hasInProgressReport) {
                          ref.read(reportGenerationInProgressProvider(classId).notifier).state = hasInProgressReport;
                        }
                      });
                    }

                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isGenerating ? null : () => _showGenerateReportModal(context, classId),
                        icon: const Icon(Icons.add),
                        label: Text(isGenerating ? 'Report in Progress...' : 'Generate Report'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
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
                        .where('classId', isEqualTo: FirebaseFirestore.instance.doc('/classes/${classId}'))
                        .where('status', isEqualTo: 'complete')
                        .orderBy('createdAt', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, reportsSnapshot) {
                      print('Fetching completed reports for class $classId');
                      
                      if (reportsSnapshot.hasError) {
                        print('Error fetching completed reports: ${reportsSnapshot.error}');
                        return Center(child: Text('Error: ${reportsSnapshot.error}'));
                      }

                      if (!reportsSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final reports = reportsSnapshot.data!.docs;
                      print('Completed reports query results:\n'
                          'Documents found: ${reports.length}\n'
                          'Documents: ${reports.map((doc) => doc.data())}');

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
    );
  }
} 