import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/report_status.dart';
import '../../../core/export/export_filename.dart';
import '../../../core/export/export_share.dart';
import '../../../core/export/typography_controller.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/report_export_buttons.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/lma_assessment_repository.dart';
import '../data/models/lma_assessment_models.dart';
import '../data/models/lma_config_models.dart';
import '../domain/lean_maturity_data.dart';
import 'lma_config_controller.dart';
import 'lma_radar_chart.dart';

class LmaPreviewPage extends ConsumerStatefulWidget {
  const LmaPreviewPage({
    super.key,
    required this.assessmentId,
  });

  final String assessmentId;

  @override
  ConsumerState<LmaPreviewPage> createState() => _LmaPreviewPageState();
}

class _LmaPreviewPageState extends ConsumerState<LmaPreviewPage> {
  LeanMaturityAssessmentRecord? _record;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final configOk =
        await ref.read(lmaConfigControllerProvider.notifier).ensureLoaded(force: true);
    if (!configOk) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ref.read(lmaConfigControllerProvider).errorMessage ??
            'Failed to load LMA configuration.';
      });
      return;
    }

    try {
      final record =
          await ref.read(lmaAssessmentRepositoryProvider).getById(widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _record = record;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _export(ExportKind kind) async {
    final record = _record;
    if (record == null || record.id.isEmpty) return;
    setState(() => _exporting = true);
    await exportAndShare(
      ref: ref,
      context: context,
      preparingMessage:
          kind == ExportKind.pdf ? 'Preparing PDF report...' : 'Preparing Word report...',
      download: () {
        final typography = ref.read(typographyControllerProvider);
        final repo = ref.read(lmaAssessmentRepositoryProvider);
        return kind == ExportKind.pdf
            ? repo.exportPdf(record.id, record: record, typography: typography)
            : repo.exportWord(record.id, record: record, typography: typography);
      },
    );
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(lmaConfigControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LMA Preview'),
        actions: [
          if (_record != null && auth.canEditRecord(
            createdByRole: _record!.createdByRole,
            createdBy: _record!.raw?['created_by'],
          ) &&
              _record!.status != ReportStatus.published)
            IconButton(
              onPressed: () => context.go(AppRoutes.lmaEdit(_record!.id)),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : !_canPreview(auth)
                  ? const Center(child: Text('You do not have permission to view reports.'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ReportExportButtons(
                              loading: _exporting,
                              onPdf: () => _export(ExportKind.pdf),
                              onWord: () => _export(ExportKind.word),
                            ),
                          ),
                        ),
                        Expanded(child: _PreviewBody(record: _record!, config: config)),
                      ],
                    ),
    );
  }

  bool _canPreview(AuthState auth) => auth.canViewReports;
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.record,
    required this.config,
  });

  final LeanMaturityAssessmentRecord record;
  final LmaConfigState config;

  @override
  Widget build(BuildContext context) {
    final scores = config.calculateScores(record.responses);
    final background = record.companyBackground;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.displayCompanyName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(label: 'Status', value: record.displayStatus),
                    _InfoChip(label: 'Report Date', value: record.reportDate ?? 'N/A'),
                    _InfoChip(label: 'Prepared By', value: record.preparedBy ?? 'N/A'),
                    _InfoChip(label: 'Updated By', value: record.updatedBy ?? 'N/A'),
                  ],
                ),
                const SizedBox(height: 16),
                _FieldRow(label: 'Location', value: background?.location),
                _FieldRow(label: 'Introduction', value: background?.companyIntroduction),
                _FieldRow(
                  label: 'Total workforce',
                  value: background?.totalWorkforce?.toString(),
                ),
                _FieldRow(
                  label: 'Shift operation',
                  value: background?.shiftOperation?.toString(),
                ),
                _FieldRow(label: 'Working hours', value: background?.workingHours),
                _FieldRow(label: 'Working days', value: background?.workingDays?.toString()),
                _FieldRow(label: 'Currency', value: background?.currency),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall score', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '${scores.totalScore} / ${scores.maxScore}   ${scores.grade} (${scores.percentage}%)',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text('${scores.answeredCount} / ${scores.totalCount} answered'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Radar chart', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                LmaRadarChart(categoryScores: scores.categoryScores),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category scores', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...scores.categoryScores.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.category,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${entry.totalScore} / ${entry.maxScore}   ${entry.grade} (${entry.percentage}%)',
                          ),
                          Text('${entry.answeredCount} / ${entry.totalCount} answered'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Responses', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...config.categories.map(
                  (category) {
                    final questions = config.questionsForCategory(category);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ...questions.map((question) {
                            final response = _responseForQuestion(question.id);
                            final fallbackLabel =
                                levelDescription(question, response?.score);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(question.text),
                              subtitle: Text(
                                response?.selectedResponse ??
                                    (fallbackLabel.isNotEmpty
                                        ? fallbackLabel
                                        : 'Not answered'),
                              ),
                              trailing: Text(
                                response?.score?.toString() ?? '-',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LeanMaturityResponse? _responseForQuestion(int questionId) {
    for (final response in record.responses) {
      if (response.questionId == questionId) return response;
    }
    return null;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value == null || value!.isEmpty ? 'N/A' : value),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
