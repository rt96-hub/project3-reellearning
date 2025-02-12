import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionModel {
  final String id;
  final String videoId;  // Single video ID since we're only using one video
  final String questionText;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final DateTime createdAt;

  QuestionModel({
    required this.id,
    required this.videoId,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.createdAt,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['questionId'],
      videoId: json['question']['videoId'],  // This will be in format 'videos/videoId'
      questionText: json['question']['questionText'],
      options: List<String>.from(json['question']['options']),
      correctAnswer: json['question']['correctAnswer'],
      explanation: json['question']['explanation'],
      createdAt: DateTime.now(),  // We'll use local time since this is for feed ordering
    );
  }

  // Helper method to get just the ID portion from the video path
  String get videoIdOnly => videoId.split('/').last;
} 