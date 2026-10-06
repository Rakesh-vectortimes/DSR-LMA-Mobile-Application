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
import '../data/dsr_repository.dart';
import '../data/models/dsr_models.dart';
import '../domain/dsr_defaults.dart';

class DsrPreviewPage extends ConsumerStatefulWidget {
  const DsrPreviewPage({super.key, required this.studyId});

  final String studyId;

  @override
  ConsumerState<DsrPreviewPage> createState() => _DsrPreviewPageState();
}

class _DsrPreviewPageState extends ConsumerState<DsrPreviewPage> {
  DiagnosticStudyRecord? _record;
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
    try {
      final record = await ref.read(dsrRepositoryProvider).getById(widget.studyId);
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
        final repo = ref.read(dsrRepositoryProvider);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSR Preview'),
        actions: [
          if (_record != null &&
              auth.canEditRecord(
                createdByRole: _record!.createdByRole,
                createdBy: _record!.raw?['created_by'],
              ) &&
              _record!.status != ReportStatus.published)
            IconButton(
              tooltip: 'Edit',
              onPressed: () => context.go(AppRoutes.dsrEdit(_record!.id)),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : !auth.canViewReports
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
                        Expanded(child: _PreviewBody(record: _record!)),
                      ],
                    ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.record});

  final DiagnosticStudyRecord record;

  @override
  Widget build(BuildContext context) {
    final bg = record.companyBackground;

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
                    _Chip(label: 'Status', value: record.displayStatus),
                    _Chip(label: 'Analysis period', value: record.analysisPeriod ?? 'N/A'),
                    _Chip(label: 'Prepared by', value: record.preparedBy ?? 'N/A'),
                    _Chip(label: 'Updated by', value: record.updatedBy ?? 'N/A'),
                  ],
                ),
                const SizedBox(height: 12),
                _Line('Location', bg?.location),
                _Line('Introduction', bg?.companyIntroduction),
                _Line('Workforce', bg?.totalWorkforce?.toString()),
                _Line('Shifts', bg?.shiftOperation?.toString()),
                _Line('Working hours', bg?.workingHours),
                _Line('Working days', bg?.workingDays?.toString()),
              ],
            ),
          ),
        ),
        _SectionCard(
          title: 'Product volume & mix',
          child: Column(
            children: record.productVolumeMix
                .map(
                  (row) => ListTile(
                    title: Text(row.productCategory),
                    subtitle: Text(
                      'Vol: ${row.annualVolume} (${row.volumePercent}%)  Value: ${row.annualValue} (${row.valuePercent}%)',
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        _SectionCard(
          title: 'Customer base',
          child: Column(
            children: record.customerBase
                .map(
                  (row) => ListTile(
                    title: Text(row.customerName),
                    subtitle: Text('${row.annualVolume} (${row.volumePercent}%)'),
                  ),
                )
                .toList(),
          ),
        ),
        _SectionCard(
          title: 'Market focus',
          child: Column(
            children: record.marketFocus
                .map(
                  (row) => ListTile(
                    title: Text(row.marketFocus),
                    subtitle: Text('${row.volume} (${row.volumePercent}%)'),
                  ),
                )
                .toList(),
          ),
        ),
        _SectionCard(
          title: 'Quality performance',
          child: Column(
            children: record.qualityPerformance
                .map((row) => _PerformanceTile(row: row))
                .toList(),
          ),
        ),
        _SectionCard(
          title: 'Cost performance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Operating expenses: ${record.costData.operatingExpenses ?? 0}'),
              Text('Cost/pc: ${record.costData.costPerPc ?? 0}'),
              Text('Productivity/person: ${record.costData.productivityPerPerson ?? 0}'),
              const SizedBox(height: 12),
              ...record.headCountData.map(
                (row) => ListTile(
                  title: Text(row.department),
                  subtitle: Text(
                    'Helpers: ${row.helpers}, Operators: ${row.operators}, Supervisor: ${row.supervisor}',
                  ),
                ),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Delivery performance',
          child: Column(
            children: record.deliveryPerformance
                .map((row) => _PerformanceTile(row: row))
                .toList(),
          ),
        ),
        _SectionCard(
          title: 'Process excellence',
          child: _ProcessExcellencePreview(process: record.processExcellence),
        ),
      ],
    );
  }
}

class _PerformanceTile extends StatelessWidget {
  const _PerformanceTile({required this.row});
  final PerformanceRow row;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(row.description),
      subtitle: Text(
        row.isMeasured ? '${row.value} — ${row.remark}' : 'Not measured',
      ),
    );
  }
}

class _ProcessExcellencePreview extends StatelessWidget {
  const _ProcessExcellencePreview({required this.process});
  final ProcessExcellence process;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Line('Measure standard time', process.measureStandardTime),
        _Line('Measure PCD', process.measurePcd),
        _Line('Interested in automation', process.interestedAutomation),
        _Line('IE department', process.ieDepartment),
        _Line('Lean belt professionals', process.leanBeltProfessionals),
        if (process.leanBeltProfessionals == 'yes')
          _Line('Lean belt level', leanBeltLevels[process.leanBeltLevel]),
        _Line('Track operator performance', process.trackOperatorPerformance),
        _Line('Training school', process.trainingSchool),
        _Line('5S certification', process.fiveSCertification),
        if (process.fiveSCertification == 'yes')
          _Line('5S level', fiveSLevels[process.fiveSLevel]),
        _Line('Incentive system', process.incentiveSystem),
        if (process.incentiveSystem == 'yes') _Line('Incentive details', process.incentiveDetails),
        _Line('One year plan', process.oneYearPlan),
        if (process.oneYearPlan == 'yes')
          ...process.improvementProjects.map(
            (project) => ListTile(
              title: Text(project.project),
              subtitle: Text(
                '${project.currentPerformance} → ${project.goal} by ${project.completionDate}',
              ),
            ),
          ),
        _Line('Lean tools practiced', process.leanToolsPracticed),
        if (process.leanToolsPracticed == 'yes')
          _Line('Lean practice', leanPracticeMethods[process.leanPracticeDetails]),
        _Line('Pain areas', process.painAreas),
        _Line('Improvements expected', process.improvementsExpected),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});
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

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value == null || value!.isEmpty ? 'N/A' : value),
          ],
        ),
      ),
    );
  }
}
