import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/remix_controller.dart';
import '../widgets/status_indicator.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/image_card.dart';
import '../../data/models/remix_model.dart';

class RemixScreen extends StatelessWidget {
  const RemixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RemixController(),
      child: const _RemixScreenContent(),
    );
  }
}

class _RemixScreenContent extends StatelessWidget {
  const _RemixScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<RemixController>(
          builder: (context, controller, _) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(context),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(context),
                      const SizedBox(height: 32),
                      _buildActionButtons(context, controller),
                      const SizedBox(height: 24),
                      if (controller.errorMessage != null)
                        ErrorBanner(
                          message: controller.errorMessage!,
                          onDismiss: controller.clearError,
                        ),
                      if (controller.isUploading)
                        const LoadingIndicator(
                          message: 'Uploading image...',
                          subtitle: 'Please wait while we process your photo',
                        ),
                      if (controller.isGenerating)
                        const LoadingIndicator(
                          message: 'AI is creating your scenes...',
                          subtitle: 'This may take 30-60 seconds',
                        ),
                      if (controller.currentRemix != null) ...[
                        const SizedBox(height: 16),
                        StatusIndicator(
                          status: controller.currentRemix!.status,
                          isGenerating: controller.isGenerating,
                        ),
                        const SizedBox(height: 32),
                      ],
                      _buildImagesSection(context, controller),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '✨ AI POWERED',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Photo Remix Studio',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Transform your portraits into stunning lifestyle scenes with AI magic',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, RemixController controller) {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildUploadButton(context, controller)),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: _buildGenerateButton(context, controller)),
      ],
    );
  }

  Widget _buildUploadButton(BuildContext context, RemixController controller) {
    return ElevatedButton.icon(
      onPressed: controller.isUploading
          ? null
          : () => controller.selectImageSource(context),
      icon: Icon(
        controller.hasOriginalImage
            ? Icons.refresh_rounded
            : Icons.upload_rounded,
        size: 20,
      ),
      label: Text(
        controller.hasOriginalImage ? 'New Photo' : 'Upload Photo',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildGenerateButton(
    BuildContext context,
    RemixController controller,
  ) {
    return ElevatedButton.icon(
      onPressed: controller.canGenerate ? controller.generateImages : null,
      icon: const Icon(Icons.auto_awesome_rounded, size: 20),
      label: const Text(
        'Generate Scenes',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildImagesSection(BuildContext context, RemixController controller) {
    if (!controller.hasOriginalImage) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.originalImageUrl != null) ...[
          _buildSectionTitle(context, 'Original Photo'),
          const SizedBox(height: 16),
          ImageCard(
            imageUrl: controller.originalImageUrl!,
            label: 'Original',
            heroTag: 'original_image',
            aspectRatio: 3 / 4,
          ),
          const SizedBox(height: 32),
        ],
        _buildSectionTitle(context, 'Generated Scenes'),
        const SizedBox(height: 16),
        _buildGeneratedImagesGrid(context, controller),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildGeneratedImagesGrid(
    BuildContext context,
    RemixController controller,
  ) {
    if (controller.generatedImageUrls.isEmpty) {
      if (controller.currentRemix?.status == RemixStatus.completed) {
        return _buildNoResultsState(context);
      }
      return _buildGenerationPlaceholder(context, controller);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.generatedImageUrls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (context, index) {
        final url = controller.generatedImageUrls[index];
        return ImageCard(
          imageUrl: url,
          label: 'Scene ${index + 1}',
          heroTag: 'generated_$index',
          aspectRatio: 3 / 4,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_camera_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ready to Create Magic?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a portrait photo to get started with AI-powered scene generation',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationPlaceholder(
    BuildContext context,
    RemixController controller,
  ) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap "Generate Scenes" to create AI magic',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'No scenes generated',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Something went wrong during generation. Please try again.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
