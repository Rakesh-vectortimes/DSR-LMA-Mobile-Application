import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/export/export_filename.dart';
import '../../../core/export/export_share.dart';
import '../../../core/export/typography_controller.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../shared/widgets/company_autocomplete.dart';
import '../../../shared/widgets/report_export_buttons.dart';
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
  final _introController = TextEditingController();
  final _locationController = TextEditingController();
  final _workforceController = TextEditingController();
  final _shiftController = TextEditingController();
  final _hoursController = TextEditingController();
  final _daysController = TextEditingController();
  final _currencyController = TextEditingController(text: 'INR');

  CompanyFormValues _company = CompanyFormValues(currency: 'INR');
  DateTime _reportDate = DateTime.now();
  int _currentStep = 0;
  String _status = 'draft';
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

  @override
  void dispose() {
    _introController.dispose();
    _locationController.dispose();
    _workforceController.dispose();
    _shiftController.dispose();
    _hoursController.dispose();
    _daysController.dispose();
    _currencyController.dispose();
    super.dispose();
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
    _introController.text = _company.companyIntroduction;
    _locationController.text = _company.location;
    _workforceController.text = _company.totalWorkforce?.toString() ?? '';
    _shiftController.text = _company.shiftOperation?.toString() ?? '';
    _hoursController.text = _company.workingHours;
    _daysController.text = _company.workingDays?.toString() ?? '';
    _currencyController.text = _company.currency;
    _reportDate = _parseDate(record.reportDate) ?? DateTime.now();
    _status = mapLmaStatusToUi(record.status);

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
    _company = values;
    _introController.text = values.companyIntroduction;
    _locationController.text = values.location;
    _workforceController.text = values.totalWorkforce?.toString() ?? '';
    _shiftController.text = values.shiftOperation?.toString() ?? '';
    _hoursController.text = values.workingHours;
    _daysController.text = values.workingDays?.toString() ?? '';
    _currencyController.text = values.currency;
    setState(() {});
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
    _status = 'draft';
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
    _status = 'submitted';
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
            _status == 'submitted'
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit LMA' : 'New LMA'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : !config.canCreateAssessment
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(config.errorMessage ?? 'LMA configuration unavailable.'),
                      ),
                    )
                  : Stepper(
                      currentStep: _currentStep,
                      onStepContinue: _currentStep == config.categories.length + 1
                          ? null
                          : _nextStep,
                      onStepCancel: _cancelStep,
                      controlsBuilder: (context, details) {
                        final lastStep = _currentStep == config.categories.length + 1;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (!lastStep)
                              FilledButton(
                                onPressed: _saving ? null : details.onStepContinue,
                                child: const Text('Next'),
                              ),
                            if (_currentStep > 0)
                              OutlinedButton(
                                onPressed: _saving ? null : details.onStepCancel,
                                child: const Text('Back'),
                              ),
                            if (auth.canWriteReports)
                              OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : (_isEdit ? _updateRecord : _saveDraft),
                                child: Text(_isEdit ? 'Update' : 'Save Draft'),
                              ),
                            if (auth.canWriteReports)
                              FilledButton(
                                onPressed: _saving ? null : _submitFinal,
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Submit Final'),
                              ),
                            if (_isEdit)
                              ReportExportButtons(
                                enabled: !_saving,
                                loading: _exporting,
                                onPdf: () => _export(ExportKind.pdf),
                                onWord: () => _export(ExportKind.word),
                              ),
                          ],
                        );
                      },
                      steps: [
                        Step(
                          title: const Text('Company'),
                          isActive: _currentStep >= 0,
                          content: _buildCompanyStep(),
                        ),
                        ...config.categories.map(
                          (category) => Step(
                            title: Text(categoryStepLabel(category)),
                            isActive: _currentStep >= config.categories.indexOf(category) + 1,
                            content: _buildCategoryStep(category),
                          ),
                        ),
                        Step(
                          title: const Text('Preview'),
                          isActive: _currentStep >= config.categories.length + 1,
                          content: _buildPreview(config),
                        ),
                      ],
                    ),
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
            onChanged: (values) {
              _company = values;
              _syncCompanyFields(values);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _introController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Company introduction'),
            onChanged: (value) => _company.companyIntroduction = value,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Location'),
            onChanged: (value) => _company.location = value,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _workforceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total workforce'),
            onChanged: (value) => _company.totalWorkforce = int.tryParse(value),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _shiftController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Shift operation'),
            onChanged: (value) => _company.shiftOperation = num.tryParse(value) ?? value,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _hoursController,
            decoration: const InputDecoration(labelText: 'Working hours'),
            onChanged: (value) => _company.workingHours = value,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Working days'),
            onChanged: (value) => _company.workingDays = int.tryParse(value) ?? value,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _currencyController,
            decoration: const InputDecoration(labelText: 'Currency'),
            onChanged: (value) => _company.currency = value.isEmpty ? 'INR' : value,
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickReportDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Report date',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(DateFormat('yyyy-MM-dd').format(_reportDate)),
            ),
          ),
          const SizedBox(height: 8),
          if (_company.companyName.trim().isEmpty)
            const Text(
              'Company name is required.',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryStep(String category) {
    final config = ref.read(lmaConfigControllerProvider);
    final questions = config.questionsForCategory(category);
    final scores = config.calculateScores(_responses);
    final entry = scores.categoryScores
        .where((item) => item.category == category)
        .cast<LeanMaturityCategoryScore?>()
        .firstWhere((_) => true, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${entry?.totalScore ?? 0} / ${entry?.maxScore ?? 0}   ${entry?.grade ?? ''} (${entry?.percentage ?? 0}%)',
              ),
              Text('${entry?.answeredCount ?? 0} / ${entry?.totalCount ?? questions.length} answered'),
            ],
          ),
        ),
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
                Text('Status: ${lmaStatusLabel(mapLmaStatusToApi(_status))}'),
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
