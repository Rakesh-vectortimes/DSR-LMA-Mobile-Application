import 'package:flutter/material.dart';

/// One section per page, matching the 5S audit create flow.
class FormWizardScaffold extends StatelessWidget {
  const FormWizardScaffold({
    super.key,
    required this.title,
    required this.stepIndex,
    required this.stepCount,
    required this.stepTitle,
    required this.body,
    required this.onNext,
    this.onSave,
    this.onStepBack,
    this.saveLabel = 'Save',
    this.nextLabel = 'Next',
    this.saving = false,
    this.actions = const [],
    this.header,
  });

  final String title;
  final int stepIndex;
  final int stepCount;
  final String stepTitle;
  final Widget body;
  final VoidCallback onNext;
  final VoidCallback? onSave;
  final VoidCallback? onStepBack;
  final String saveLabel;
  final String nextLabel;
  final bool saving;
  final List<Widget> actions;
  final Widget? header;

  bool get _isFirstStep => stepIndex <= 0;

  int get _total => stepCount <= 0 ? 1 : stepCount;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isFirstStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onStepBack?.call();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_isFirstStep) {
                Navigator.of(context).maybePop();
              } else {
                onStepBack?.call();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(
                'Step ${stepIndex + 1}/$_total: $stepTitle',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: actions,
        ),
        body: Column(
          children: [
            if (header != null) header!,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: body,
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 6,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      if (onSave != null) ...[
                        OutlinedButton(
                          onPressed: saving ? null : onSave,
                          child: Text(saveLabel),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: saving ? null : onNext,
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(nextLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
