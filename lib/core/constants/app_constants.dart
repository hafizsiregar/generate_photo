class AppConstants {
  // App Info
  static const String appName = 'AI Photo Remix';
  static const String appDescription =
      'Transform your portraits into stunning lifestyle scenes';

  // Limits
  static const int maxImageSizeMB = 20;
  static const int maxImageSizeBytes = maxImageSizeMB * 1024 * 1024;
  static const int maxImageWidth = 2048;
  static const int maxImageHeight = 2048;
  static const int imageQuality = 85;

  // Generation
  static const int expectedGenerationTimeSeconds = 45;
  static const int maxGenerationTimeSeconds = 300;

  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 16.0;
  static const double smallBorderRadius = 8.0;

  // Animation
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
}
