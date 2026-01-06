import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../constants/app_constants.dart';

class ImageUtils {
  static Future<XFile?> pickImage({required ImageSource source}) async {
    final picker = ImagePicker();
    return await picker.pickImage(
      source: source,
      maxWidth: AppConstants.maxImageWidth.toDouble(),
      maxHeight: AppConstants.maxImageHeight.toDouble(),
      imageQuality: AppConstants.imageQuality,
    );
  }

  static Future<bool> validateImageSize(String imagePath) async {
    final file = File(imagePath);
    final fileSize = await file.length();
    return fileSize <= AppConstants.maxImageSizeBytes;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
