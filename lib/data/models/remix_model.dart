import 'package:cloud_firestore/cloud_firestore.dart';

enum RemixStatus { idle, generating, completed, error }

class RemixModel {
  final String id;
  final String userId;
  final String originalImagePath;
  final List<String> generatedImagePaths;
  final RemixStatus status;
  final String? errorMessage;
  final DateTime createdAt;

  RemixModel({
    required this.id,
    required this.userId,
    required this.originalImagePath,
    required this.generatedImagePaths,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  factory RemixModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RemixModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      originalImagePath: data['originalImagePath'] ?? '',
      generatedImagePaths: List<String>.from(data['generatedImagePaths'] ?? []),
      status: _parseStatus(data['status']),
      errorMessage: data['errorMessage'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'originalImagePath': originalImagePath,
      'generatedImagePaths': generatedImagePaths,
      'status': status.name,
      'errorMessage': errorMessage,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static RemixStatus _parseStatus(String? status) {
    switch (status) {
      case 'idle':
        return RemixStatus.idle;
      case 'generating':
        return RemixStatus.generating;
      case 'completed':
        return RemixStatus.completed;
      case 'error':
        return RemixStatus.error;
      default:
        return RemixStatus.idle;
    }
  }

  RemixModel copyWith({
    String? id,
    String? userId,
    String? originalImagePath,
    List<String>? generatedImagePaths,
    RemixStatus? status,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return RemixModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      generatedImagePaths: generatedImagePaths ?? this.generatedImagePaths,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
