import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/remix_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  // Authentication
  Future<User> ensureUserSignedIn() async {
    try {
      var user = _auth.currentUser;
      debugPrint('Current user: ${user?.uid}');

      if (user == null) {
        debugPrint('No current user, signing in anonymously...');
        final cred = await _auth.signInAnonymously();
        user = cred.user!;
        debugPrint('Anonymous sign in successful: ${user.uid}');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Force refresh token to ensure it's valid
      debugPrint('Getting fresh ID token...');
      final token = await user.getIdToken(true);
      debugPrint('Token obtained, length: ${token?.length ?? 0}');

      // Double check user is still valid
      await user.reload();
      user = _auth.currentUser!;
      debugPrint('User reloaded successfully: ${user.uid}');

      return user;
    } catch (e) {
      debugPrint('Authentication error: $e');
      rethrow;
    }
  }

  // Storage
  Future<String> uploadImage({
    required File imageFile,
    required String userId,
    required String remixId,
    required String fileName,
  }) async {
    final path = 'images/$userId/$remixId/$fileName';
    final ref = _storage.ref().child(path);

    await ref.putFile(
      imageFile,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    return await ref.getDownloadURL();
  }

  Future<List<String>> getGeneratedImageUrls(List<String> paths) async {
    final urls = <String>[];
    for (final path in paths) {
      try {
        final ref = _storage.ref().child(path);
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        debugPrint('Error getting URL for $path: $e');
      }
    }
    return urls;
  }

  // Firestore
  Future<RemixModel> createRemix({
    required String userId,
    required String originalImagePath,
  }) async {
    final remixRef = _firestore.collection('remixes').doc();
    final remix = RemixModel(
      id: remixRef.id,
      userId: userId,
      originalImagePath: originalImagePath,
      generatedImagePaths: [],
      status: RemixStatus.idle,
      createdAt: DateTime.now(),
    );

    await remixRef.set(remix.toFirestore());
    return remix;
  }

  Future<void> updateRemixImagePath(String remixId, String imagePath) async {
    await _firestore.collection('remixes').doc(remixId).update({
      'originalImagePath': imagePath,
    });
  }

  Stream<RemixModel> watchRemix(String remixId) {
    return _firestore
        .collection('remixes')
        .doc(remixId)
        .snapshots(includeMetadataChanges: true)
        .map((doc) => RemixModel.fromFirestore(doc));
  }

  // Cloud Functions
  Future<Map<String, dynamic>> generateImages(String remixId) async {
    try {
      debugPrint('Calling generateImages function with remixId: $remixId');

      final callable = _functions.httpsCallable('generateImages');
      debugPrint('Callable created successfully');

      final result = await callable.call({'remixId': remixId});
      debugPrint('Function call successful: ${result.data}');

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Function call error: $e');
      rethrow;
    }
  }
}
