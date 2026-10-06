import 'package:flutter/material.dart';

class ReportExportButtons extends StatelessWidget {
  const ReportExportButtons({
    super.key,
    required this.onPdf,
    required this.onWord,
    this.enabled = true,
    this.loading = false,
    this.iconOnly = false,
  });

  final VoidCallback onPdf;
  final VoidCallback onWord;
  final bool enabled;
  final bool loading;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading;
    final pdfIcon = loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.picture_as_pdf_outlined);

    if (iconOnly) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            tooltip: 'Export PDF',
            onPressed: canTap ? onPdf : null,
            icon: pdfIcon,
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Export Word',
            onPressed: canTap ? onWord : null,
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: canTap ? onPdf : null,
          icon: pdfIcon,
          label: const Text('Export PDF'),
        ),
        OutlinedButton.icon(
          onPressed: canTap ? onWord : null,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Export Word'),
        ),
      ],
    );
  }
}
