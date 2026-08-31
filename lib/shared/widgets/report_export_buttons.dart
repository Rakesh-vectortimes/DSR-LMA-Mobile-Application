import 'package:flutter/material.dart';

class ReportExportButtons extends StatelessWidget {
  const ReportExportButtons({
    super.key,
    required this.onPdf,
    required this.onWord,
    this.enabled = true,
    this.loading = false,
  });

  final VoidCallback onPdf;
  final VoidCallback onWord;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: canTap ? onPdf : null,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
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
