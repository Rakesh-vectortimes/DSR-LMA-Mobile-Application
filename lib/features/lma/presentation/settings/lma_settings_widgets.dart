import 'package:flutter/material.dart';

import '../../../../core/network/api_response.dart';
import '../../../../core/theme/app_theme.dart';

Future<bool> confirmSettingsDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

void showSettingsMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : null,
    ),
  );
}

String settingsErrorMessage(Object error, String fallback) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  return fallback;
}

Future<T?> showSettingsSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: child,
      );
    },
  );
}

class SettingsListScaffold extends StatelessWidget {
  const SettingsListScaffold({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.emptyLabel,
    required this.onRetry,
    required this.child,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final String emptyLabel;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    return child;
  }
}

class SettingsSheetHeader extends StatelessWidget {
  const SettingsSheetHeader({
    super.key,
    required this.title,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          TextButton(onPressed: saving ? null : onCancel, child: const Text('Cancel')),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
