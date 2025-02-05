import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String title;
  final String description;
  final bool isPublic;
  final String thumbnail;
  final DocumentReference creator;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int memberCount;

  ClassModel({
    required this.id,
    required this.title,
    required this.description,
    required this.isPublic,
    required this.thumbnail,
    required this.creator,
    required this.createdAt,
    required this.updatedAt,
    this.memberCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isPublic': isPublic,
      'thumbnail': thumbnail,
      'creator': creator,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'memberCount': memberCount,
    };
  }

  factory ClassModel.fromMap(String id, Map<String, dynamic> map) {
    return ClassModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isPublic: map['isPublic'] ?? true,
      thumbnail: map['thumbnail'] ?? '',
      creator: map['creator'] as DocumentReference,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      memberCount: map['memberCount'] ?? 0,
    );
  }

  ClassModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isPublic,
    String? thumbnail,
    DocumentReference? creator,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? memberCount,
  }) {
    return ClassModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      thumbnail: thumbnail ?? this.thumbnail,
      creator: creator ?? this.creator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }
} 