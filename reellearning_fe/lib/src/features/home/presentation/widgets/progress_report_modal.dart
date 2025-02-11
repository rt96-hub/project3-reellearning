import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

// Provider to track if a report is being generated for a source
final reportGenerationInProgressProvider = StateProvider.family<bool, String>((ref, sourceId) => false);

class ProgressReportModal extends ConsumerStatefulWidget {
  final String sourceType; // 'user' or 'class'
  final String sourceId;

  const ProgressReportModal({
    super.key,
    required this.sourceType,
    required this.sourceId,
  });

  @override
  ConsumerState<ProgressReportModal> createState() => _ProgressReportModalState();
}

class _ProgressReportModalState extends ConsumerState<ProgressReportModal> {
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;

  // TODO: Move this to a configuration file
  static const String _functionBaseUrl = 'https://us-central1-reellearning-prj3.cloudfunctions.net';

  @override
  void initState() {
    super.initState();
    // Check if report generation is in progress
    if (ref.read(reportGenerationInProgressProvider(widget.sourceId))) {
      // Show message and close modal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A report is already being generated'),
            backgroundColor: Colors.orange,
          ),
        );
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          // If end date is before start date, update it
          if (endDate != null && endDate!.isBefore(picked)) {
            endDate = picked;
          }
        } else {
          endDate = picked;
          // If start date is after end date, update it
          if (startDate != null && startDate!.isAfter(picked)) {
            startDate = picked;
          }
        }
      });
    }
  }

  Future<void> _generateReport() async {
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Get the current user's ID token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final token = await user.getIdToken();

      final functionName = widget.sourceType == 'user' 
          ? 'generate_user_report' 
          : 'generate_class_report';

      // Create DateTime objects for start of start date and end of end date
      final startDateTime = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final endDateTime = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);

      final url = Uri.parse('$_functionBaseUrl/$functionName');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': widget.sourceId,
          'startTime': startDateTime.toIso8601String(),
          'endTime': endDateTime.toIso8601String(),
          'type': 'custom',
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Set the in-progress state
        ref.read(reportGenerationInProgressProvider(widget.sourceId).notifier).state = true;
        
        if (mounted) {
          Navigator.of(context).pop(); // Close the modal
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report generation started'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (response.statusCode == 409) {
        // Report already in progress
        ref.read(reportGenerationInProgressProvider(widget.sourceId).notifier).state = true;
        if (mounted) {
          Navigator.of(context).pop(); // Close the modal
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A report is already being generated'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        throw Exception(responseData['error'] ?? 'Failed to generate report');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if report generation is in progress
    final isGenerating = ref.watch(reportGenerationInProgressProvider(widget.sourceId));
    if (isGenerating) {
      return const SizedBox.shrink(); // Don't show modal if report is being generated
    }

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Generate Progress Report',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            
            // Start Date Selection
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(
                startDate != null 
                    ? DateFormat.yMMMd().format(startDate!) 
                    : 'Select start date',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, true),
            ),
            
            // End Date Selection
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(
                endDate != null 
                    ? DateFormat.yMMMd().format(endDate!) 
                    : 'Select end date',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, false),
            ),
            
            const SizedBox(height: 24),
            
            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _generateReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generate Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 