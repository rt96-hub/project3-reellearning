import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserReportDetailScreen extends StatelessWidget {
  final String reportId;

  const UserReportDetailScreen({
    super.key,
    required this.reportId,
  });

  String _formatDate(Timestamp timestamp) {
    // Convert UTC DateTime to local time before formatting
    final utcDateTime = timestamp.toDate();
    final localDateTime = utcDateTime.toLocal();
    return DateFormat.yMMMd().add_jm().format(localDateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('userProgressReports')
            .doc(reportId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final report = snapshot.data!.data() as Map<String, dynamic>;
          final reportData = report['reportData'] as Map<String, dynamic>;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  FutureBuilder<DocumentSnapshot>(
                    future: (report['userId'] as DocumentReference).get(),
                    builder: (context, userSnapshot) {
                      final userName = userSnapshot.hasData
                          ? (userSnapshot.data!.data() as Map<String, dynamic>)['profile']['displayName'] ?? 'Unknown User'
                          : 'Loading...';
                      
                      return Text(
                        userName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDate(report['startDate'])} - ${_formatDate(report['endDate'])}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    report['type'].toString().toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Metrics Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMetricTile(
                              'Videos Watched',
                              reportData['videosWatched']?.toString() ?? '0',
                            ),
                            _buildMetricTile(
                              'Classes Created',
                              reportData['classesCreated']?.toString() ?? '0',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMetricTile(
                              'Videos Liked',
                              reportData['videosLiked']?.toString() ?? '0',
                            ),
                            _buildMetricTile(
                              'Videos Bookmarked',
                              reportData['videosBookmarked']?.toString() ?? '0',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Comprehension Metrics
                  const Text(
                    'Comprehension',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'Not Understood',
                          (reportData['comprehension']?['not_understood'] ?? 0).toString(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricTile(
                          'Partially',
                          (reportData['comprehension']?['partially_understood'] ?? 0).toString(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricTile(
                          'Fully',
                          (reportData['comprehension']?['fully_understood'] ?? 0).toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Report Body
                  if (reportData['body'] != null) ...[
                    const Text(
                      'Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reportData['body'],
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 