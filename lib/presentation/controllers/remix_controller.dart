import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../data/models/remix_model.dart';
import '../../data/services/firebase_service.dart';
import '../../core/utils/image_utils.dart';

class RemixController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  // State
  RemixModel? _currentRemix;
  String? _originalImageUrl;
  List<String> _generatedImageUrls = [];
  bool _isUploading = false;
  bool _isGenerating = false;
  String? _errorMessage;

  // Getters
  RemixModel? get currentRemix => _currentRemix;
  String? get originalImageUrl => _originalImageUrl;
  List<String> get generatedImageUrls => _generatedImageUrls;
  bool get isUploading => _isUploading;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  bool get hasOriginalImage => _originalImageUrl != null;
  bool get canGenerate =>
      _currentRemix != null &&
      !_isGenerating &&
      _currentRemix!.status != RemixStatus.generating;

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> selectImageSource(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImageSourceBottomSheet(context),
    );

    if (source != null) {
      await uploadImage(source);
    }
  }

  Widget _buildImageSourceBottomSheet(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Select Image Source',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSourceOption(
                    context,
                    icon: Icons.camera_alt_rounded,
                    title: 'Take Photo',
                    subtitle: 'Use camera to capture a new photo',
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _buildSourceOption(
                    context,
                    icon: Icons.photo_library_rounded,
                    title: 'Choose from Gallery',
                    subtitle: 'Select an existing photo',
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> uploadImage(ImageSource source) async {
    try {
      _isUploading = true;
      _errorMessage = null;
      _resetState(); // Clear previous state
      notifyListeners();

      final pickedFile = await ImageUtils.pickImage(source: source);
      if (pickedFile == null) {
        _isUploading = false;
        notifyListeners();
        return;
      }

      // Validate file size
      final isValidSize = await ImageUtils.validateImageSize(pickedFile.path);
      if (!isValidSize) {
        _setError('Image too large. Please select an image smaller than 20MB.');
        _isUploading = false;
        return;
      }

      final user = await _firebaseService.ensureUserSignedIn();
      final file = File(pickedFile.path);

      // Create remix document first with proper path
      final originalPath = 'images/${user.uid}/temp/original.jpg';
      final remix = await _firebaseService.createRemix(
        userId: user.uid,
        originalImagePath: originalPath,
      );

      // Upload image
      final downloadUrl = await _firebaseService.uploadImage(
        imageFile: file,
        userId: user.uid,
        remixId: remix.id,
        fileName: 'original.jpg',
      );

      // Update remix with correct image path in Firestore
      final correctPath = 'images/${user.uid}/${remix.id}/original.jpg';
      await _firebaseService.updateRemixImagePath(remix.id, correctPath);

      // Update local state
      final updatedRemix = remix.copyWith(originalImagePath: correctPath);

      _currentRemix = updatedRemix;
      _originalImageUrl = downloadUrl;
      _isUploading = false;

      // Start listening to remix changes
      _listenToRemixChanges(remix.id);

      notifyListeners();
    } catch (e) {
      _isUploading = false;
      _setError(_getUploadErrorMessage(e));
    }
  }

  void _resetState() {
    _currentRemix = null;
    _originalImageUrl = null;
    _generatedImageUrls.clear(); // Use clear() instead of assignment
    _isGenerating = false;
    _errorMessage = null; // Also clear error message
  }

  void _listenToRemixChanges(String remixId) {
    _firebaseService
        .watchRemix(remixId)
        .listen(
          (remix) async {
            _currentRemix = remix;

            if (remix.status == RemixStatus.generating) {
              _isGenerating = true;
            } else {
              _isGenerating = false;
            }

            // Always refresh generated URLs when paths change
            if (remix.generatedImagePaths.isNotEmpty) {
              final newUrls = await _firebaseService.getGeneratedImageUrls(
                remix.generatedImagePaths,
              );
              // Only update if URLs actually changed
              if (!_listEquals(_generatedImageUrls, newUrls)) {
                _generatedImageUrls = newUrls;
              }
            } else {
              // Clear URLs if no paths
              _generatedImageUrls.clear();
            }

            if (remix.errorMessage != null && remix.errorMessage!.isNotEmpty) {
              _setError(remix.errorMessage);
            }

            notifyListeners();
          },
          onError: (error) {
            _setError('Failed to sync data: $error');
          },
        );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> generateImages() async {
    if (_currentRemix == null) return;

    try {
      _isGenerating = true;
      _errorMessage = null;
      notifyListeners();

      await _firebaseService.generateImages(_currentRemix!.id);
    } on FirebaseFunctionsException catch (e) {
      _isGenerating = false;
      _setError(_getGenerationErrorMessage(e));
    } catch (e) {
      _isGenerating = false;
      _setError('Unexpected error occurred. Please try again.');
    }
  }

  String _getUploadErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission')) {
      return 'Camera/gallery permission denied. Please enable permissions in settings.';
    } else if (errorStr.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else {
      return 'Failed to process image. Please try again.';
    }
  }

  String _getGenerationErrorMessage(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'failed-precondition':
        if (e.message?.contains('API_KEY') == true) {
          return 'Service configuration error. Please contact support.';
        } else {
          return 'Service not ready. Please try again in a moment.';
        }
      case 'resource-exhausted':
        if (e.message?.contains('10 seconds') == true) {
          return 'Please wait a moment before generating again.';
        } else if (e.message?.contains('15 generations') == true) {
          return 'Hourly generation limit reached. Please try again later.';
        }
        return e.message ?? 'Rate limit exceeded. Please try again later.';
      case 'invalid-argument':
        return 'Invalid image format. Please try with a different photo.';
      case 'permission-denied':
        return 'Access denied. Please restart the app and try again.';
      case 'unavailable':
        return 'AI service temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Generation took too long. Please try again with a smaller image.';
      default:
        return e.message ?? 'Generation failed. Please try again.';
    }
  }
}
