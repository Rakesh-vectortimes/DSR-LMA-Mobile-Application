import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lma_config_repository.dart';
import '../../data/models/lma_config_models.dart';
import '../../domain/lma_settings.dart';
import '../lma_config_controller.dart';
import 'lma_settings_widgets.dart';

class LmaGradeSettingsTab extends ConsumerStatefulWidget {
  const LmaGradeSettingsTab({super.key});

  @override
  ConsumerState<LmaGradeSettingsTab> createState() => _LmaGradeSettingsTabState();
}

class _LmaGradeSettingsTabState extends ConsumerState<LmaGradeSettingsTab> {
  List<LmaGrade> _grades = const [];
  bool _loading = true;
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
      await ref.read(lmaConfigControllerProvider.notifier).ensureLoaded();
      final grades = await ref.read(lmaGradeRepositoryProvider).list();
      grades.sort((a, b) => (a.gradeOrder ?? 0).compareTo(b.gradeOrder ?? 0));
      if (!mounted) return;
      setState(() {
        _grades = grades;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = settingsErrorMessage(error, 'Failed to load grades');
      });
    }
  }

  Future<void> _afterMutation() async {
    await ref.read(lmaConfigControllerProvider.notifier).refreshAfterMutation();
    await _load();
  }

  Future<void> _openForm({LmaGrade? existing}) async {
    final saved = await showSettingsSheet<bool>(
      context: context,
      child: _GradeFormSheet(
        existing: existing,
        grades: _grades,
        configMax: ref.read(lmaConfigControllerProvider).maxScore,
      ),
    );
    if (saved == true) {
      await _afterMutation();
    }
  }

  Future<void> _delete(LmaGrade grade) async {
    final confirmed = await confirmSettingsDelete(
      context,
      title: 'Delete grade',
      message: 'Delete grading tier "${grade.gradingCriteria}"?',
    );
    if (!confirmed) return;
    try {
      await ref.read(lmaGradeRepositoryProvider).delete(grade.id);
      if (!mounted) return;
      showSettingsMessage(context, 'Grade deleted.');
      await _afterMutation();
    } catch (error) {
      if (!mounted) return;
      showSettingsMessage(
        context,
        settingsErrorMessage(error, 'Failed to delete grade'),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Configure overall grading tiers for lean maturity assessments.'),
              ),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Grade'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SettingsListScaffold(
            loading: _loading,
            error: _error,
            isEmpty: _grades.isEmpty,
            emptyLabel: 'No grades yet.',
            onRetry: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _grades.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final grade = _grades[index];
                return Card(
                  child: ListTile(
                    title: Text(grade.gradingCriteria),
                    subtitle: Text(
                      'Order ${grade.gradeOrder ?? '-'} · '
                      '${grade.score.isEmpty ? '${grade.minScore}-${grade.maxScore}' : grade.score} · '
                      '${grade.percentage}%',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _openForm(existing: grade),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(grade),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GradeFormSheet extends ConsumerStatefulWidget {
  const _GradeFormSheet({
    required this.grades,
    required this.configMax,
    this.existing,
  });

  final LmaGrade? existing;
  final List<LmaGrade> grades;
  final int configMax;

  @override
  ConsumerState<_GradeFormSheet> createState() => _GradeFormSheetState();
}

class _GradeFormSheetState extends ConsumerState<_GradeFormSheet> {
  late final TextEditingController _criteria;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _order;
  GradeFormErrors _errors = const GradeFormErrors();
  bool _saving = false;

  bool get _isCreate => widget.existing == null;

  int get _overall => gradeOverallMaxScore(
        configMax: widget.configMax,
        grades: widget.grades,
      );

  int get _percentage {
    final maxScore = int.tryParse(_max.text.trim());
    if (maxScore == null) return 0;
    return gradePercentageFromMax(maxScore: maxScore, overall: _overall);
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _criteria = TextEditingController(text: existing?.gradingCriteria ?? '');
    _min = TextEditingController(text: existing == null ? '' : '${existing.minScore}');
    _max = TextEditingController(text: existing == null ? '' : '${existing.maxScore}');
    _order = TextEditingController(
      text: '${existing?.gradeOrder ?? widget.grades.length + 1}',
    );
  }

  @override
  void dispose() {
    _criteria.dispose();
    _min.dispose();
    _max.dispose();
    _order.dispose();
    super.dispose();
  }

  List<LmaGrade> get _others {
    final id = widget.existing?.id;
    if (id == null) return widget.grades;
    return widget.grades.where((grade) => grade.id != id).toList();
  }

  Future<void> _save() async {
    final minScore = int.tryParse(_min.text.trim());
    final maxScore = int.tryParse(_max.text.trim());
    final order = int.tryParse(_order.text.trim());
    final percentage = _percentage;
    final errors = validateGradeForm(
      gradingCriteria: _criteria.text,
      minScore: minScore,
      maxScore: maxScore,
      gradeOrder: order,
      percentage: percentage,
      others: _others,
    );
    setState(() => _errors = errors);
    if (errors.hasError) return;

    setState(() => _saving = true);
    try {
      final payload = buildGradePayload(
        gradingCriteria: _criteria.text,
        minScore: minScore!,
        maxScore: maxScore!,
        percentage: percentage,
        gradeOrder: order!,
      );
      final repo = ref.read(lmaGradeRepositoryProvider);
      if (_isCreate) {
        await repo.create(payload);
      } else {
        await repo.update(widget.existing!.id, payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = settingsErrorMessage(error, 'Failed to save grade');
      setState(() {
        _saving = false;
        _errors = GradeFormErrors(
          gradingCriteria: applyServerFieldHint(message, 'grading_criteria').isNotEmpty
              ? applyServerFieldHint(message, 'grading_criteria')
              : _errors.gradingCriteria,
          minScore: _errors.minScore,
          maxScore: message.toLowerCase().contains('overlap') ||
                  message.toLowerCase().contains('score range already exists')
              ? message
              : _errors.maxScore,
          gradeOrder: applyServerFieldHint(message, 'grade_order').isNotEmpty
              ? applyServerFieldHint(message, 'grade_order')
              : _errors.gradeOrder,
          percentage: applyServerFieldHint(message, 'percentage').isNotEmpty
              ? applyServerFieldHint(message, 'percentage')
              : _errors.percentage,
        );
      });
      showSettingsMessage(context, message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsSheetHeader(
          title: _isCreate ? 'Add grade' : 'Edit grade',
          saving: _saving,
          onCancel: () => Navigator.of(context).pop(false),
          onSave: _save,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              TextField(
                controller: _criteria,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Grading criteria *',
                  errorText:
                      _errors.gradingCriteria.isEmpty ? null : _errors.gradingCriteria,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _min,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Min score *',
                  errorText: _errors.minScore.isEmpty ? null : _errors.minScore,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Max score *',
                  errorText: _errors.maxScore.isEmpty ? null : _errors.maxScore,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Percentage *',
                  helperText: 'Auto-calculated: max score / $_overall × 100',
                  errorText: _errors.percentage.isEmpty ? null : _errors.percentage,
                ),
                child: Text('$_percentage%'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Order *',
                  errorText: _errors.gradeOrder.isEmpty ? null : _errors.gradeOrder,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
