import 'package:flutter/material.dart';
import '../../data/models/remix_model.dart';

class StatusIndicator extends StatelessWidget {
  final RemixStatus status;
  final bool isGenerating;

  const StatusIndicator({
    super.key,
    required this.status,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _getStatusColor(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: _getStatusColor(context).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGenerating) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStatusColor(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getStatusColor(context),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _getStatusText(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: _getStatusColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    if (isGenerating) return Colors.orange;

    switch (status) {
      case RemixStatus.idle:
        return Colors.grey;
      case RemixStatus.generating:
        return Colors.orange;
      case RemixStatus.completed:
        return Colors.green;
      case RemixStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText() {
    if (isGenerating) return 'Generating...';

    switch (status) {
      case RemixStatus.idle:
        return 'Ready';
      case RemixStatus.generating:
        return 'Generating...';
      case RemixStatus.completed:
        return 'Complete';
      case RemixStatus.error:
        return 'Error';
    }
  }
}
