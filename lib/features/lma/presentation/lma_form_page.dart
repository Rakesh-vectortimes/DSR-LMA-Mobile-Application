import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/crm_conversion_type.dart';
import '../../../core/constants/report_status.dart';
import '../../../core/export/export_filename.dart';
import '../../../core/export/export_share.dart';
import '../../../core/export/typography_controller.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../shared/widgets/company_autocomplete.dart';
import '../../../shared/widgets/form_wizard_scaffold.dart';
import '../../companies/data/company_repository.dart';
import '../../companies/data/models/company.dart';
import '../data/lma_assessment_repository.dart';
import '../data/models/lma_assessment_models.dart';
import '../data/models/lma_config_models.dart';
import '../domain/lma_api_mapper.dart';
import '../domain/lean_maturity_data.dart';
import 'lma_config_controller.dart';
import 'lma_radar_chart.dart';

class LmaFormPage extends ConsumerStatefulWidget {
  const LmaFormPage({
    super.key,
    this.assessmentId,
  });

  final String? assessmentId;

  @override
  ConsumerState<LmaFormPage> createState() => _LmaFormPageState();
}

class _LmaFormPageState extends ConsumerState<LmaFormPage> {
  final _detailsFormKey = GlobalKey<FormState>();

  CompanyFormValues _company = CompanyFormValues(currency: 'INR');
  DateTime _reportDate = DateTime.now();
  int _currentStep = 0;
  int _status = ReportStatus.draft;
  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;
  String? _error;
  List<LeanMaturityResponse> _responses = const [];

  bool get _isEdit => widget.assessmentId != null && widget.assessmentId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final configLoaded =
        await ref.read(lmaConfigControllerProvider.notifier).ensureLoaded(force: true);
    final auth = ref.read(authControllerProvider);
    if (!configLoaded) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ref.read(lmaConfigControllerProvider).errorMessage ??
            'Failed to load assessment configuration.';
      });
      return;
    }

    final config = ref.read(lmaConfigControllerProvider);
    _responses = config.questions
        .map(
          (question) => LeanMaturityResponse(
            questionId: question.id,
            category: question.category,
            score: null,
            question: question.text,
          ),
        )
        .toList();

    if (_isEdit) {
      try {
        final record = await ref
            .read(lmaAssessmentRepositoryProvider)
            .getById(widget.assessmentId!);
        if (!mounted) return;

        if (!auth.canEditRecord(
          createdByRole: record.createdByRole,
          createdBy: record.raw?['created_by'],
        )) {
          context.go(AppRoutes.lmaPreview(record.id));
          return;
        }

        _patchFromRecord(record);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
        return;
      }
    } else if (!auth.canWriteReports) {
      if (!mounted) return;
      context.go(AppRoutes.lma);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to create reports.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  void _patchFromRecord(LeanMaturityAssessmentRecord record) {
    final bg = record.companyBackground;
    _company = CompanyFormValues(
      companyId: record.companyId,
      companyName: record.companyName ?? bg?.companyName ?? '',
      location: bg?.location ?? '',
      companyIntroduction: bg?.companyIntroduction ?? '',
      totalWorkforce: bg?.totalWorkforce,
      shiftOperation: bg?.shiftOperation,
      workingHours: bg?.workingHours ?? '',
      workingDays: bg?.workingDays,
      currency: bg?.currency ?? 'INR',
      currencySymbol: bg?.currencySymbol,
      status: 'active',
    );
    _reportDate = _parseDate(record.reportDate) ?? DateTime.now();
    _status = ReportStatus.parse(record.status);

    final existing = {
      for (final response in record.responses) response.questionId: response,
    };
    final config = ref.read(lmaConfigControllerProvider);
    _responses = config.questions
        .map((question) {
          final response = existing[question.id];
          return LeanMaturityResponse(
            questionId: question.id,
            category: question.category,
            score: response?.score,
            question: question.text,
            selectedResponse: response?.selectedResponse,
          );
        })
        .toList();
  }

  void _syncCompanyFields(CompanyFormValues values) {
    setState(() => _company = values);
  }

  Future<void> _pickReportDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() => _reportDate = selected);
    }
  }

  void _onScoreChanged(LeanMaturityQuestion question, int score) {
    final level = question.levels
        .where((item) => item.score == score)
        .cast<LmaQuestionOption?>()
        .firstWhere((_) => true, orElse: () => null);
    setState(() {
      _responses = _responses
          .map(
            (response) => response.questionId == question.id
                ? LeanMaturityResponse(
                    questionId: response.questionId,
                    category: question.category,
                    score: score,
                    question: question.text,
                    selectedResponse: level?.description,
                  )
                : response,
          )
          .toList();
    });
  }

  Future<void> _saveDraft() async {
    _status = ReportStatus.draft;
    await _save();
  }

  Future<void> _updateRecord() async {
    await _save();
  }

  Future<void> _submitFinal() async {
    if (!_validateDetails(showErrors: true)) return;
    if (!_allQuestionsAnswered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions before submitting.')),
      );
      return;
    }
    _status = ReportStatus.published;
    await _save();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validateDetails(showErrors: true)) return;

    setState(() => _saving = true);
    try {
      if ((_company.companyId == null || _company.companyId!.isEmpty) &&
          _company.companyName.trim().isNotEmpty) {
        final created =
            await ref.read(companyRepositoryProvider).resolveOrCreate(_company);
        _company = CompanyFormValues.fromCompany(created);
        _syncCompanyFields(_company);
      }

      final config = ref.read(lmaConfigControllerProvider);
      final payload = buildLmaApiPayload(
        company: _company,
        responses: _responses,
        questions: config.questions,
        status: _status,
        reportDate: _reportDate,
      );

      final repository = ref.read(lmaAssessmentRepositoryProvider);
      final record = _isEdit
          ? await repository.update(widget.assessmentId!, payload)
          : await repository.create(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _status == ReportStatus.published
                ? 'Assessment submitted successfully.'
                : _isEdit
                    ? 'Assessment updated successfully.'
                    : 'Draft saved successfully.',
          ),
        ),
      );
      context.go(AppRoutes.lmaPreview(record.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validateDetails({bool showErrors = false}) {
    final formValid = _detailsFormKey.currentState?.validate() ?? false;
    final valid = formValid && _company.companyName.trim().isNotEmpty;
    if (!valid && showErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the required company details.')),
      );
    }
    return valid;
  }

  bool _categoryAnswered(String category) {
    final config = ref.read(lmaConfigControllerProvider);
    final questions = config.questionsForCategory(category);
    for (final question in questions) {
      final response = _responses
          .where((item) => item.questionId == question.id)
          .cast<LeanMaturityResponse?>()
          .firstWhere((_) => true, orElse: () => null);
      if (!isAnsweredScore(response?.score)) {
        return false;
      }
    }
    return true;
  }

  bool _allQuestionsAnswered() {
    final config = ref.read(lmaConfigControllerProvider);
    return config.categories.every(_categoryAnswered);
  }

  void _nextStep() {
    final config = ref.read(lmaConfigControllerProvider);
    if (_currentStep == 0) {
      if (!_validateDetails(showErrors: true)) return;
    } else if (_currentStep <= config.categories.length) {
      final category = config.categories[_currentStep - 1];
      if (!_categoryAnswered(category)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please answer all questions in this category before continuing.'),
          ),
        );
        return;
      }
    }
    setState(() => _currentStep += 1);
  }

  void _cancelStep() {
    if (_currentStep == 0) return;
    setState(() => _currentStep -= 1);
  }

  Future<void> _export(ExportKind kind) async {
    final id = widget.assessmentId;
    if (id == null || id.isEmpty) return;
    setState(() => _exporting = true);
    final record = LeanMaturityAssessmentRecord(
      id: id,
      companyId: _company.companyId,
      status: _status,
      companyName: _company.companyName,
      reportDate: DateFormat('yyyy-MM-dd').format(_reportDate),
    );
    await exportAndShare(
      ref: ref,
      context: context,
      preparingMessage: kind == ExportKind.pdf ? 'Preparing PDF report...' : 'Preparing Word report...',
      download: () {
        final typography = ref.read(typographyControllerProvider);
        final repo = ref.read(lmaAssessmentRepositoryProvider);
        return kind == ExportKind.pdf
            ? repo.exportPdf(id, record: record, typography: typography)
            : repo.exportWord(id, record: record, typography: typography);
      },
    );
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(lmaConfigControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final title = _isEdit ? 'Edit LMA' : 'New LMA';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(_error!)),
      );
    }
    if (!config.canCreateAssessment) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(config.errorMessage ?? 'LMA configuration unavailable.'),
          ),
        ),
      );
    }

    final stepCount = config.categories.length + 2;
    final lastStep = _currentStep >= stepCount - 1;
    final stepTitle = _currentStep == 0
        ? 'Company'
        : _currentStep <= config.categories.length
            ? categoryStepLabel(config.categories[_currentStep - 1])
            : 'Preview';
    final stepBody = _currentStep == 0
        ? _buildCompanyStep()
        : _currentStep <= config.categories.length
            ? _buildCategoryStep(config.categories[_currentStep - 1])
            : _buildPreview(config);

    return FormWizardScaffold(
      title: title,
      stepIndex: _currentStep,
      stepCount: stepCount,
      stepTitle: stepTitle,
      body: stepBody,
      header: _currentStep > 0 && _currentStep <= config.categories.length
          ? _buildCategoryScoreHeader(config.categories[_currentStep - 1])
          : null,
      saving: _saving,
      saveLabel: _isEdit ? 'Update' : 'Save',
      nextLabel: lastStep ? 'Submit Final' : 'Next',
      onSave: auth.canWriteReports
          ? (_isEdit ? _updateRecord : _saveDraft)
          : null,
      onNext: lastStep ? _submitFinal : _nextStep,
      onStepBack: _cancelStep,
      actions: [
        if (_isEdit)
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _saving || _exporting ? null : () => _export(ExportKind.pdf),
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        if (_isEdit)
          IconButton(
            tooltip: 'Export Word',
            onPressed: _saving || _exporting ? null : () => _export(ExportKind.word),
            icon: const Icon(Icons.description_outlined),
          ),
      ],
    );
  }

  Widget _buildCompanyStep() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CompanyAutocompleteField(
            values: _company,
            convertedTo: CrmConversionType.lma,
            onChanged: _syncCompanyFields,
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickReportDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Report date',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(DateFormat('d MMM yyyy').format(_reportDate)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryScoreHeader(String category) {
    final config = ref.read(lmaConfigControllerProvider);
    final questions = config.questionsForCategory(category);
    final scores = config.calculateScores(_responses);
    final entry = scores.categoryScores
        .where((item) => item.category == category)
        .cast<LeanMaturityCategoryScore?>()
        .firstWhere((_) => true, orElse: () => null);

    final maxScore = (entry?.maxScore ?? 0) > 0
        ? entry!.maxScore
        : questions.fold(0, (sum, question) => sum + questionMaxScore(question));
    final totalScore = entry?.totalScore ?? 0;
    final percentage = entry?.percentage ??
        (maxScore > 0 ? ((totalScore / maxScore) * 100).round() : 0);
    final grade = (entry?.grade ?? '').trim();
    final answered = entry?.answeredCount ?? 0;
    final total = (entry?.totalCount ?? 0) > 0
        ? entry!.totalCount
        : questions.length;
    final scoreStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w700,
        );
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        );

    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                category,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 2,
                children: [
                  Text('$totalScore / $maxScore', style: scoreStyle),
                  Text(
                    grade.isEmpty ? '$percentage%' : '$grade ($percentage%)',
                    style: metaStyle,
                  ),
                  Text('$answered / $total answered', style: metaStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStep(String category) {
    final config = ref.read(lmaConfigControllerProvider);
    final questions = config.questionsForCategory(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...questions.map(
          (question) {
            final response = _responses
                .where((item) => item.questionId == question.id)
                .cast<LeanMaturityResponse?>()
                .firstWhere((_) => true, orElse: () => null);
            final groupValue = response?.score;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...question.levels.map(
                      (level) => RadioListTile<int>(
                        value: level.score,
                        groupValue: groupValue,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${level.score}'),
                        subtitle: level.description.isEmpty ? null : Text(level.description),
                        onChanged: (value) {
                          if (value != null) _onScoreChanged(question, value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreview(LmaConfigState config) {
    final scores = config.calculateScores(_responses);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _company.companyName.trim().isEmpty
                      ? 'Lean Maturity Assessment'
                      : _company.companyName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Report date: ${DateFormat('yyyy-MM-dd').format(_reportDate)}'),
                Text('Status: ${ReportStatus.labelOf(_status)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '${scores.totalScore} / ${scores.maxScore}   ${scores.grade} (${scores.percentage}%)',
                ),
                Text('${scores.answeredCount} / ${scores.totalCount} answered'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LmaRadarChart(categoryScores: scores.categoryScores),
          ),
        ),
      ],
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
