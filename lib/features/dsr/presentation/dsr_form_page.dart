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
import '../../../shared/widgets/company_autocomplete.dart';
import '../../../shared/widgets/form_wizard_scaffold.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../companies/data/company_repository.dart';
import '../../companies/data/models/company.dart';
import '../data/dsr_repository.dart';
import '../data/models/dsr_models.dart';
import '../domain/dsr_api_mapper.dart';
import '../domain/dsr_defaults.dart';
import '../domain/dsr_form_state.dart';

class DsrFormPage extends ConsumerStatefulWidget {
  const DsrFormPage({super.key, this.studyId});

  final String? studyId;

  @override
  ConsumerState<DsrFormPage> createState() => _DsrFormPageState();
}

class _DsrFormPageState extends ConsumerState<DsrFormPage> {
  final _detailsFormKey = GlobalKey<FormState>();
  late DsrFormState _form;
  CompanyFormValues _company = CompanyFormValues(currency: 'INR');
  DateTime _reportDate = DateTime.now();
  int _currentStep = 0;
  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;
  String? _error;

  bool get _isEdit => widget.studyId != null && widget.studyId!.isNotEmpty;

  static const _stepTitles = [
    'Company Background',
    'Product Volume & Mix',
    'Customer Base',
    'Market Focus',
    'Quality Performance',
    'Cost Performance',
    'Delivery Performance',
    'Process Excellence',
    'Preview & Submit',
  ];

  @override
  void initState() {
    super.initState();
    _form = DsrFormState.initial();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = ref.read(authControllerProvider);
    if (_isEdit) {
      try {
        final record = await ref.read(dsrRepositoryProvider).getById(widget.studyId!);
        if (!mounted) return;
        if (!auth.canEditRecord(
          createdByRole: record.createdByRole,
          createdBy: record.raw?['created_by'],
        )) {
          context.go(AppRoutes.dsrPreview(record.id));
          return;
        }
        _form.patchFromRecord(record);
        _company = companyBackgroundToFormValues(_form.companyBackground);
        _reportDate = DateTime.tryParse(_form.companyBackground.reportDate ?? '') ??
            DateTime.tryParse(_form.companyBackground.analysisPeriodFrom ?? '') ??
            DateTime.now();
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
      context.go(AppRoutes.dsr);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to create reports.')),
      );
      return;
    } else {
      _company = companyBackgroundToFormValues(_form.companyBackground);
      _reportDate = DateTime.tryParse(_form.companyBackground.reportDate ?? '') ??
          DateTime.now();
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _syncCompanyFromPicker(CompanyFormValues values) {
    _company = values;
    _form.companyBackground = formValuesToCompanyBackground(
      values: values,
      existing: _form.companyBackground,
      preparedBy: _form.companyBackground.preparedBy,
    );
    setState(() => _form.recalculateAll());
  }

  Future<void> _pickReportDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      _reportDate = selected;
      final formatted = dsrFormatDate(selected);
      _form.companyBackground = _form.companyBackground.copyWith(
        reportDate: formatted,
        analysisPeriodFrom: formatted,
      );
    });
  }

  Future<void> _saveDraft() async {
    _form.status = ReportStatus.draft;
    _form.companyBackground = _form.companyBackground.copyWith(analysisPeriodTo: null);
    await _save();
  }

  Future<void> _updateRecord() async => _save();

  Future<void> _submitFinal() async {
    if (!_validateCompany(showErrors: true)) return;
    _form.status = ReportStatus.published;
    _form.companyBackground = _form.companyBackground.copyWith(
      analysisPeriodTo: dsrFormatDate(DateTime.now()),
    );
    await _save();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validateCompany(showErrors: true)) return;

    setState(() => _saving = true);
    try {
      if ((_company.companyId == null || _company.companyId!.isEmpty) &&
          _company.companyName.trim().isNotEmpty) {
        final created = await ref.read(companyRepositoryProvider).resolveOrCreate(_company);
        _company = CompanyFormValues.fromCompany(created);
        _syncCompanyFromPicker(_company);
      }

      final auth = ref.read(authControllerProvider);
      final preparedBy = auth.user?.name ?? auth.user?.email;
      _form.companyBackground = formValuesToCompanyBackground(
        values: _company,
        existing: _form.companyBackground.copyWith(
          reportDate: dsrFormatDate(_reportDate),
          analysisPeriodFrom: dsrFormatDate(_reportDate),
          preparedBy: preparedBy,
        ),
        preparedBy: preparedBy,
      );

      final payload = buildDsrApiPayload(
        companyBackground: _form.companyBackground,
        productVolumeMix: _form.productVolumeMix,
        customerBase: _form.customerBase,
        marketFocus: _form.marketFocus,
        qualityPerformance: _form.qualityPerformance,
        headCountData: _form.headCountData,
        costData: _form.costData,
        deliveryPerformance: _form.deliveryPerformance,
        processExcellence: _form.processExcellence,
        status: _form.status,
      );

      final repo = ref.read(dsrRepositoryProvider);
      final record = _isEdit
          ? await repo.update(widget.studyId!, payload)
          : await repo.create(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _form.status == ReportStatus.published
                ? 'Study submitted successfully.'
                : _isEdit
                    ? 'Study updated successfully.'
                    : 'Draft saved successfully.',
          ),
        ),
      );
      context.go(AppRoutes.dsrPreview(record.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validateCompany({bool showErrors = false}) {
    final valid = (_detailsFormKey.currentState?.validate() ?? true) &&
        _company.companyName.trim().isNotEmpty;
    if (!valid && showErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the required company details.')),
      );
    }
    return valid;
  }

  void _nextStep() {
    if (_currentStep == 0 && !_validateCompany(showErrors: true)) return;
    setState(() => _currentStep += 1);
  }

  void _backStep() {
    if (_currentStep == 0) return;
    setState(() => _currentStep -= 1);
  }

  Future<void> _export(ExportKind kind) async {
    final id = widget.studyId;
    if (id == null || id.isEmpty) return;
    setState(() => _exporting = true);
    final record = DiagnosticStudyRecord(
      id: id,
      status: _form.status,
      companyId: _form.companyBackground.companyId,
      companyName: _form.companyBackground.companyName,
      title: '${_form.companyBackground.companyName} Diagnostic Study',
      reportDate: _form.companyBackground.reportDate,
      analysisPeriod: _form.companyBackground.analysisPeriod,
      companyBackground: _form.companyBackground,
    );
    await exportAndShare(
      ref: ref,
      context: context,
      preparingMessage:
          kind == ExportKind.pdf ? 'Preparing PDF report...' : 'Preparing Word report...',
      download: () {
        final typography = ref.read(typographyControllerProvider);
        final repo = ref.read(dsrRepositoryProvider);
        return kind == ExportKind.pdf
            ? repo.exportPdf(id, record: record, typography: typography)
            : repo.exportWord(id, record: record, typography: typography);
      },
    );
    if (mounted) setState(() => _exporting = false);
  }

  bool get _isLastStep => _currentStep >= _stepTitles.length - 1;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit DSR' : 'New DSR')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit DSR' : 'New DSR')),
        body: Center(child: Text(_error!)),
      );
    }

    return FormWizardScaffold(
      title: _isEdit ? 'Edit DSR' : 'New DSR',
      stepIndex: _currentStep,
      stepCount: _stepTitles.length,
      stepTitle: _stepTitles[_currentStep],
      body: _buildStep(_currentStep),
      saving: _saving,
      saveLabel: _isEdit ? 'Update' : 'Save',
      nextLabel: _isLastStep ? 'Submit Final' : 'Next',
      onSave: auth.canWriteReports
          ? (_isEdit ? _updateRecord : _saveDraft)
          : null,
      onNext: _isLastStep ? _submitFinal : _nextStep,
      onStepBack: _backStep,
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

  Widget _buildStep(int index) {
    switch (index) {
      case 0:
        return _buildCompanyStep();
      case 1:
        return _buildProductVolumeStep();
      case 2:
        return _buildCustomerBaseStep();
      case 3:
        return _buildMarketFocusStep();
      case 4:
        return _buildPerformanceStep(
          rows: _form.qualityPerformance,
          onChanged: (rows) => setState(() {
            _form.qualityPerformance = rows;
          }),
        );
      case 5:
        return _buildCostStep();
      case 6:
        return _buildPerformanceStep(
          rows: _form.deliveryPerformance,
          onChanged: (rows) => setState(() {
            _form.deliveryPerformance = rows;
          }),
        );
      case 7:
        return _buildProcessExcellenceStep();
      case 8:
        return _buildPreviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCompanyStep() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CompanyAutocompleteField(
            values: _company,
            convertedTo: CrmConversionType.dsr,
            onChanged: _syncCompanyFromPicker,
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

  Widget _buildProductVolumeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _form.productVolumeMix = [
                ..._form.productVolumeMix,
                const ProductVolumeRow(productCategory: ''),
              ];
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add row'),
          ),
        ),
        ...List.generate(_form.productVolumeMix.length, (index) {
          final row = _form.productVolumeMix[index];
          return _ProductVolumeCard(
            row: row,
            onChanged: (next) => setState(() {
              _form.productVolumeMix[index] = next;
              _form.recalculateAll();
            }),
            onRemove: _form.productVolumeMix.length > 1
                ? () => setState(() {
                      _form.productVolumeMix.removeAt(index);
                      _form.recalculateAll();
                    })
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildCustomerBaseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _form.customerBase = [
                ..._form.customerBase,
                const CustomerBaseRow(customerName: ''),
              ];
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add row'),
          ),
        ),
        ...List.generate(_form.customerBase.length, (index) {
          final row = _form.customerBase[index];
          return _CustomerBaseCard(
            row: row,
            onChanged: (next) => setState(() {
              _form.customerBase[index] = next;
              _form.recalculateAll();
            }),
            onRemove: _form.customerBase.length > 1
                ? () => setState(() {
                      _form.customerBase.removeAt(index);
                      _form.recalculateAll();
                    })
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildMarketFocusStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _form.marketFocus = [
                ..._form.marketFocus,
                const MarketFocusRow(marketFocus: ''),
              ];
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add row'),
          ),
        ),
        ...List.generate(_form.marketFocus.length, (index) {
          final row = _form.marketFocus[index];
          return _MarketFocusCard(
            row: row,
            onChanged: (next) => setState(() {
              _form.marketFocus[index] = next;
              _form.recalculateAll();
            }),
            onRemove: _form.marketFocus.length > 1
                ? () => setState(() {
                      _form.marketFocus.removeAt(index);
                      _form.recalculateAll();
                    })
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildPerformanceStep({
    required List<PerformanceRow> rows,
    required ValueChanged<List<PerformanceRow>> onChanged,
  }) {
    return Column(
      children: List.generate(rows.length, (index) {
        final row = rows[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(row.description, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: row.status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Measured')),
                    DropdownMenuItem(value: 2, child: Text('Not Measured')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final next = [...rows];
                    next[index] = row.copyWith(status: value);
                    onChanged(next);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: row.value,
                  enabled: row.isMeasured,
                  decoration: const InputDecoration(labelText: 'Value'),
                  onChanged: (value) {
                    final next = [...rows];
                    next[index] = row.copyWith(value: value);
                    onChanged(next);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: row.remark,
                  enabled: row.isMeasured,
                  decoration: const InputDecoration(labelText: 'Remark'),
                  onChanged: (value) {
                    final next = [...rows];
                    next[index] = row.copyWith(remark: value);
                    onChanged(next);
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCostStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Head count', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _form.headCountData = [
                ..._form.headCountData,
                const HeadCountRow(department: ''),
              ];
              _form.recalculateAll();
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add department'),
          ),
        ),
        ...List.generate(_form.headCountData.length, (index) {
          final row = _form.headCountData[index];
          return _HeadCountCard(
            row: row,
            onChanged: (next) => setState(() {
              _form.headCountData[index] = next;
              _form.recalculateAll();
            }),
            onRemove: _form.headCountData.length > 1
                ? () => setState(() {
                      _form.headCountData.removeAt(index);
                      _form.recalculateAll();
                    })
                : null,
          );
        }),
        const SizedBox(height: 16),
        Text('Cost data', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _CostField(
          label: 'Avg operator salary',
          value: _form.costData.avgOperatorSalary?.toString() ?? '',
          onChanged: (value) => setState(() {
            _form.costData = _form.costData.copyWith(avgOperatorSalary: value);
            _form.recalculateAll();
          }),
        ),
        _CostField(
          label: 'Total direct salary',
          value: _form.costData.totalDirectSalary?.toString() ?? '',
          onChanged: (value) => setState(() {
            _form.costData = _form.costData.copyWith(totalDirectSalary: value);
            _form.recalculateAll();
          }),
        ),
        _CostField(
          label: 'Total indirect salary',
          value: _form.costData.totalIndirectSalary?.toString() ?? '',
          onChanged: (value) => setState(() {
            _form.costData = _form.costData.copyWith(totalIndirectSalary: value);
            _form.recalculateAll();
          }),
        ),
        _CostField(
          label: 'Total overheads',
          value: _form.costData.totalOverheads?.toString() ?? '',
          onChanged: (value) => setState(() {
            _form.costData = _form.costData.copyWith(totalOverheads: value);
            _form.recalculateAll();
          }),
        ),
        _ReadOnlyField(label: 'Operating expenses', value: '${_form.costData.operatingExpenses ?? 0}'),
        _CostField(
          label: 'Avg monthly output',
          value: _form.costData.avgMonthlyOutput?.toString() ?? '',
          onChanged: (value) => setState(() {
            _form.costData = _form.costData.copyWith(avgMonthlyOutput: value);
            _form.recalculateAll();
          }),
        ),
        _ReadOnlyField(label: 'Cost/pc', value: '${_form.costData.costPerPc ?? 0}'),
        _CostField(
          label: 'Cost/min',
          value: _form.costData.costPerMin?.toString() ?? '',
          onChanged: (value) => setState(() {
            _form.costData = _form.costData.copyWith(costPerMin: value);
          }),
        ),
        _CostField(
          label: 'Factory efficiency',
          value: _form.costData.factoryEfficiency?.toString() ?? '',
          onChanged: (value) => setState(() {
            _form.costData = _form.costData.copyWith(factoryEfficiency: value);
          }),
        ),
        _ReadOnlyField(
          label: 'Productivity/person',
          value: '${_form.costData.productivityPerPerson ?? 0}',
        ),
      ],
    );
  }

  Widget _buildProcessExcellenceStep() {
    final pe = _form.processExcellence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...List.generate(processExcellenceQuestions.length, (index) {
          final question = processExcellenceQuestions[index];
          return _buildProcessExcellenceQuestion(
            number: index + 1,
            field: question.field,
            label: question.label,
            pe: pe,
          );
        }),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: pe.painAreas,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Pain areas'),
          onChanged: (value) => setState(() {
            _form.processExcellence =
                _form.processExcellence.copyWith(painAreas: value);
          }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: pe.improvementsExpected,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Improvement expected'),
          onChanged: (value) => setState(() {
            _form.processExcellence =
                _form.processExcellence.copyWith(improvementsExpected: value);
          }),
        ),
      ],
    );
  }

  Widget _buildProcessExcellenceQuestion({
    required int number,
    required String field,
    required String label,
    required ProcessExcellence pe,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _YesNoField(
              label: '$number. $label',
              value: _yesNoValue(pe, field),
              onChanged: (value) => setState(() {
                _form.processExcellence =
                    _updateProcessExcellence(_form.processExcellence, field, value);
              }),
            ),
            if (field == 'lean_belt_professionals' && pe.leanBeltProfessionals == 'yes')
              _processEnumDropdown(
                hint: 'Select belt level',
                value: pe.leanBeltLevel,
                options: leanBeltLevels,
                onChanged: (value) => setState(() {
                  _form.processExcellence =
                      _form.processExcellence.copyWith(leanBeltLevel: value);
                }),
              ),
            if (field == 'five_s_certification' && pe.fiveSCertification == 'yes')
              _processEnumDropdown(
                hint: 'Select 5S level',
                value: pe.fiveSLevel,
                options: fiveSLevels,
                onChanged: (value) => setState(() {
                  _form.processExcellence =
                      _form.processExcellence.copyWith(fiveSLevel: value);
                }),
              ),
            if (field == 'incentive_system' && pe.incentiveSystem == 'yes') ...[
              const SizedBox(height: 8),
              Text(
                'Brief incentive information',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: pe.incentiveDetails,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Brief incentive information',
                ),
                onChanged: (value) => setState(() {
                  _form.processExcellence =
                      _form.processExcellence.copyWith(incentiveDetails: value);
                }),
              ),
            ],
            if (field == 'one_year_plan' && pe.oneYearPlan == 'yes')
              _buildImprovementProjectsTable(pe),
            if (field == 'lean_tools_practiced' && pe.leanToolsPracticed == 'yes')
              _processEnumDropdown(
                hint: 'Select practice method',
                value: pe.leanPracticeDetails,
                options: leanPracticeMethods,
                onChanged: (value) => setState(() {
                  _form.processExcellence =
                      _form.processExcellence.copyWith(leanPracticeDetails: value);
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _processEnumDropdown({
    required String hint,
    required int? value,
    required Map<int, String> options,
    required ValueChanged<int?> onChanged,
  }) {
    final selected = options.containsKey(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<int>(
        value: selected,
        isExpanded: true,
        hint: Text(hint),
        decoration: InputDecoration(labelText: hint),
        items: options.entries
            .map(
              (entry) => DropdownMenuItem<int>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildImprovementProjectsTable(ProcessExcellence pe) {
    final projects = pe.improvementProjects;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              'Sr No  ·  Project  ·  Current Performance  ·  Goal  ·  Completion Date',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ...List.generate(projects.length, (index) {
            return _ImprovementProjectCard(
              index: index,
              project: projects[index],
              canMoveUp: index > 0,
              canMoveDown: index < projects.length - 1,
              onChanged: (next) => _replaceImprovementProject(index, next),
              onRemove: () => _removeImprovementProject(index),
              onMoveUp: () => _moveImprovementProject(index, -1),
              onMoveDown: () => _moveImprovementProject(index, 1),
              onAddAfter: () => _insertImprovementProject(index + 1),
            );
          }),
          Material(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            child: InkWell(
              onTap: () => _insertImprovementProject(projects.length),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add another improvement project',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.add),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _replaceImprovementProject(int index, ImprovementProject project) {
    final projects = [..._form.processExcellence.improvementProjects];
    if (index < 0 || index >= projects.length) return;
    projects[index] = project;
    setState(() {
      _form.processExcellence =
          _form.processExcellence.copyWith(improvementProjects: projects);
    });
  }

  void _insertImprovementProject(int index) {
    final projects = [..._form.processExcellence.improvementProjects];
    final clamped = index.clamp(0, projects.length);
    projects.insert(clamped, const ImprovementProject());
    setState(() {
      _form.processExcellence =
          _form.processExcellence.copyWith(improvementProjects: projects);
    });
  }

  void _removeImprovementProject(int index) {
    final projects = [..._form.processExcellence.improvementProjects];
    if (projects.length <= 1) {
      setState(() {
        _form.processExcellence = _form.processExcellence.copyWith(
          improvementProjects: [const ImprovementProject()],
        );
      });
      return;
    }
    projects.removeAt(index);
    setState(() {
      _form.processExcellence =
          _form.processExcellence.copyWith(improvementProjects: projects);
    });
  }

  void _moveImprovementProject(int index, int delta) {
    final projects = [..._form.processExcellence.improvementProjects];
    final next = index + delta;
    if (next < 0 || next >= projects.length) return;
    final item = projects.removeAt(index);
    projects.insert(next, item);
    setState(() {
      _form.processExcellence =
          _form.processExcellence.copyWith(improvementProjects: projects);
    });
  }

  Widget _buildPreviewStep() {
    final bg = _form.companyBackground;
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
                  bg.companyName.isEmpty ? 'Diagnostic Study' : bg.companyName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Status: ${ReportStatus.labelOf(_form.status)}'),
                Text('Report date: ${DateFormat('d MMM yyyy').format(_reportDate)}'),
                Text('Analysis period to: ${bg.analysisPeriodTo ?? 'Draft (open)'}'),
                Text('Prepared by: ${bg.preparedBy ?? 'Current user on save'}'),
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
                Text('Summary', style: Theme.of(context).textTheme.titleLarge),
                Text('Product rows: ${_form.productVolumeMix.length}'),
                Text('Customer rows: ${_form.customerBase.length}'),
                Text('Market focus rows: ${_form.marketFocus.length}'),
                Text('Quality metrics: ${_form.qualityPerformance.length}'),
                Text('Head count departments: ${_form.headCountData.length}'),
                Text('Operating expenses: ${_form.costData.operatingExpenses ?? 0}'),
                Text('Cost/pc: ${_form.costData.costPerPc ?? 0}'),
                Text('Productivity/person: ${_form.costData.productivityPerPerson ?? 0}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _yesNoValue(ProcessExcellence pe, String field) {
    switch (field) {
      case 'measure_standard_time':
        return pe.measureStandardTime;
      case 'measure_pcd':
        return pe.measurePcd;
      case 'interested_automation':
        return pe.interestedAutomation;
      case 'ie_department':
        return pe.ieDepartment;
      case 'lean_belt_professionals':
        return pe.leanBeltProfessionals;
      case 'track_operator_performance':
        return pe.trackOperatorPerformance;
      case 'training_school':
        return pe.trainingSchool;
      case 'five_s_certification':
        return pe.fiveSCertification;
      case 'incentive_system':
        return pe.incentiveSystem;
      case 'one_year_plan':
        return pe.oneYearPlan;
      case 'lean_tools_practiced':
        return pe.leanToolsPracticed;
      default:
        return '';
    }
  }

  ProcessExcellence _updateProcessExcellence(ProcessExcellence pe, String field, String value) {
    switch (field) {
      case 'measure_standard_time':
        return pe.copyWith(measureStandardTime: value);
      case 'measure_pcd':
        return pe.copyWith(measurePcd: value);
      case 'interested_automation':
        return pe.copyWith(interestedAutomation: value);
      case 'ie_department':
        return pe.copyWith(ieDepartment: value);
      case 'lean_belt_professionals':
        return pe.copyWith(leanBeltProfessionals: value);
      case 'track_operator_performance':
        return pe.copyWith(trackOperatorPerformance: value);
      case 'training_school':
        return pe.copyWith(trainingSchool: value);
      case 'five_s_certification':
        return pe.copyWith(fiveSCertification: value);
      case 'incentive_system':
        return pe.copyWith(incentiveSystem: value);
      case 'one_year_plan':
        var next = pe.copyWith(oneYearPlan: value);
        if (value == 'yes' && next.improvementProjects.isEmpty) {
          next = next.copyWith(improvementProjects: [const ImprovementProject()]);
        }
        return next;
      case 'lean_tools_practiced':
        return pe.copyWith(leanToolsPracticed: value);
      default:
        return pe;
    }
  }
}

class _ProductVolumeCard extends StatelessWidget {
  const _ProductVolumeCard({
    required this.row,
    required this.onChanged,
    this.onRemove,
  });

  final ProductVolumeRow row;
  final ValueChanged<ProductVolumeRow> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              initialValue: row.productCategory,
              decoration: const InputDecoration(labelText: 'Product category *'),
              onChanged: (value) => onChanged(row.copyWith(productCategory: value)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: row.annualVolume?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Annual volume *'),
              onChanged: (value) => onChanged(row.copyWith(annualVolume: value)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: row.annualValue?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Annual value'),
              onChanged: (value) => onChanged(row.copyWith(annualValue: value)),
            ),
            const SizedBox(height: 8),
            _ReadOnlyField(label: 'Volume %', value: '${row.volumePercent}'),
            _ReadOnlyField(label: 'Value %', value: '${row.valuePercent}'),
            if (onRemove != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomerBaseCard extends StatelessWidget {
  const _CustomerBaseCard({
    required this.row,
    required this.onChanged,
    this.onRemove,
  });

  final CustomerBaseRow row;
  final ValueChanged<CustomerBaseRow> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              initialValue: row.customerName,
              decoration: const InputDecoration(labelText: 'Customer name *'),
              onChanged: (value) => onChanged(row.copyWith(customerName: value)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: row.annualVolume?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Annual volume *'),
              onChanged: (value) => onChanged(row.copyWith(annualVolume: value)),
            ),
            const SizedBox(height: 8),
            _ReadOnlyField(label: 'Volume %', value: '${row.volumePercent}'),
            if (onRemove != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarketFocusCard extends StatelessWidget {
  const _MarketFocusCard({
    required this.row,
    required this.onChanged,
    this.onRemove,
  });

  final MarketFocusRow row;
  final ValueChanged<MarketFocusRow> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              initialValue: row.marketFocus,
              decoration: const InputDecoration(labelText: 'Market focus'),
              onChanged: (value) => onChanged(row.copyWith(marketFocus: value)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: row.volume?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Volume'),
              onChanged: (value) => onChanged(row.copyWith(volume: value)),
            ),
            const SizedBox(height: 8),
            _ReadOnlyField(label: 'Volume %', value: '${row.volumePercent}'),
            if (onRemove != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeadCountCard extends StatelessWidget {
  const _HeadCountCard({
    required this.row,
    required this.onChanged,
    this.onRemove,
  });

  final HeadCountRow row;
  final ValueChanged<HeadCountRow> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              initialValue: row.department,
              decoration: const InputDecoration(labelText: 'Department'),
              onChanged: (value) => onChanged(row.copyWith(department: value)),
            ),
            ...[
              ('helpers', row.helpers),
              ('operators', row.operators),
              ('supervisor', row.supervisor),
              ('executive', row.executive),
              ('checkers', row.checkers),
              ('manager', row.manager),
            ].map((entry) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextFormField(
                  initialValue: entry.$2?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: entry.$1),
                  onChanged: (value) {
                    final updated = switch (entry.$1) {
                      'helpers' => row.copyWith(helpers: value),
                      'operators' => row.copyWith(operators: value),
                      'supervisor' => row.copyWith(supervisor: value),
                      'executive' => row.copyWith(executive: value),
                      'checkers' => row.copyWith(checkers: value),
                      'manager' => row.copyWith(manager: value),
                      _ => row,
                    };
                    onChanged(updated);
                  },
                ),
              );
            }),
            if (onRemove != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImprovementProjectCard extends StatefulWidget {
  const _ImprovementProjectCard({
    required this.index,
    required this.project,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onAddAfter,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  final int index;
  final ImprovementProject project;
  final ValueChanged<ImprovementProject> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onAddAfter;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  State<_ImprovementProjectCard> createState() => _ImprovementProjectCardState();
}

class _ImprovementProjectCardState extends State<_ImprovementProjectCard> {
  late final TextEditingController _projectController;
  late final TextEditingController _currentController;
  late final TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    _projectController = TextEditingController(text: widget.project.project);
    _currentController =
        TextEditingController(text: widget.project.currentPerformance);
    _goalController = TextEditingController(text: widget.project.goal);
  }

  @override
  void didUpdateWidget(covariant _ImprovementProjectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.project != widget.project.project &&
        _projectController.text != widget.project.project) {
      _projectController.text = widget.project.project;
    }
    if (oldWidget.project.currentPerformance != widget.project.currentPerformance &&
        _currentController.text != widget.project.currentPerformance) {
      _currentController.text = widget.project.currentPerformance;
    }
    if (oldWidget.project.goal != widget.project.goal &&
        _goalController.text != widget.project.goal) {
      _goalController.text = widget.project.goal;
    }
  }

  @override
  void dispose() {
    _projectController.dispose();
    _currentController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final parsed = _parseCompletionDate(widget.project.completionDate);
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    widget.onChanged(
      widget.project.copyWith(
        completionDate: DateFormat('yyyy-MM-dd').format(selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = widget.project.completionDate.trim().isEmpty
        ? 'dd-mm-yyyy'
        : _formatCompletionDate(widget.project.completionDate);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${widget.index + 1}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Add row',
                onPressed: widget.onAddAfter,
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Move up',
                onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextField(
            controller: _projectController,
            decoration: const InputDecoration(labelText: 'Project'),
            onChanged: (value) =>
                widget.onChanged(widget.project.copyWith(project: value)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _currentController,
            decoration: const InputDecoration(labelText: 'Current Performance'),
            onChanged: (value) => widget.onChanged(
              widget.project.copyWith(currentPerformance: value),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _goalController,
            decoration: const InputDecoration(labelText: 'Goal'),
            onChanged: (value) =>
                widget.onChanged(widget.project.copyWith(goal: value)),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Completion Date',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(dateLabel),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _parseCompletionDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return iso;
  final parts = trimmed.split(RegExp(r'[/-]'));
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _formatCompletionDate(String value) {
  final parsed = _parseCompletionDate(value);
  if (parsed == null) return value;
  return DateFormat('dd-MM-yyyy').format(parsed);
}

class _YesNoField extends StatelessWidget {
  const _YesNoField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: true,
          segments: const [
            ButtonSegment(value: 'yes', label: Text('Yes')),
            ButtonSegment(value: 'no', label: Text('No')),
          ],
          selected: value == 'yes' || value == 'no' ? {value} : <String>{},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            onChanged(selection.first);
          },
        ),
      ],
    );
  }
}

class _CostField extends StatelessWidget {
  const _CostField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}
