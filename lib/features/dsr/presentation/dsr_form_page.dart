import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/export/export_filename.dart';
import '../../../core/export/export_share.dart';
import '../../../core/export/typography_controller.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/company_autocomplete.dart';
import '../../../shared/widgets/report_export_buttons.dart';
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
  final _introController = TextEditingController();
  final _locationController = TextEditingController();
  final _workforceController = TextEditingController();
  final _shiftController = TextEditingController();
  final _hoursController = TextEditingController();
  final _daysController = TextEditingController();
  late DsrFormState _form;
  CompanyFormValues _company = CompanyFormValues(currency: 'INR');
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

  @override
  void dispose() {
    _introController.dispose();
    _locationController.dispose();
    _workforceController.dispose();
    _shiftController.dispose();
    _hoursController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _applyCompanyFieldControllers(CompanyFormValues values) {
    _introController.text = values.companyIntroduction;
    _locationController.text = values.location;
    _workforceController.text = values.totalWorkforce?.toString() ?? '';
    _shiftController.text = values.shiftOperation?.toString() ?? '';
    _hoursController.text = values.workingHours;
    _daysController.text = values.workingDays?.toString() ?? '';
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
        _applyCompanyFieldControllers(_company);
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
      _applyCompanyFieldControllers(_company);
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _syncCompanyFromPicker(CompanyFormValues values) {
    _company = values;
    _applyCompanyFieldControllers(values);
    _form.companyBackground = formValuesToCompanyBackground(
      values: values,
      existing: _form.companyBackground,
      preparedBy: _form.companyBackground.preparedBy,
    );
    setState(() => _form.recalculateAll());
  }

  Future<void> _saveDraft() async {
    _form.status = 'draft';
    _form.companyBackground = _form.companyBackground.copyWith(analysisPeriodTo: null);
    await _save();
  }

  Future<void> _updateRecord() async => _save();

  Future<void> _submitFinal() async {
    if (!_validateCompany(showErrors: true)) return;
    _form.status = 'submitted';
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
          reportDate: _form.companyBackground.analysisPeriodFrom,
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
            _form.status == 'submitted'
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit DSR' : 'New DSR')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Stepper(
                  currentStep: _currentStep,
                  onStepContinue: _currentStep == _stepTitles.length - 1 ? null : _nextStep,
                  onStepCancel: _backStep,
                  controlsBuilder: (context, details) {
                    final last = _currentStep == _stepTitles.length - 1;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (!last)
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
                            onPressed: _saving ? null : (_isEdit ? _updateRecord : _saveDraft),
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
                  steps: List.generate(_stepTitles.length, (index) {
                    return Step(
                      title: Text(_stepTitles[index]),
                      isActive: _currentStep >= index,
                      content: _buildStep(index),
                    );
                  }),
                ),
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
            onChanged: _syncCompanyFromPicker,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _introController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Company introduction'),
            onChanged: (value) {
              _company.companyIntroduction = value;
              _form.companyBackground =
                  _form.companyBackground.copyWith(companyIntroduction: value);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Location'),
            onChanged: (value) {
              _company.location = value;
              _form.companyBackground = _form.companyBackground.copyWith(location: value);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _workforceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total workforce'),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              _company.totalWorkforce = parsed;
              _form.companyBackground =
                  _form.companyBackground.copyWith(totalWorkforce: parsed);
              _form.recalculateAll();
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _shiftController,
            decoration: const InputDecoration(labelText: 'Shift operation'),
            onChanged: (value) {
              _company.shiftOperation = num.tryParse(value) ?? value;
              _form.companyBackground =
                  _form.companyBackground.copyWith(shiftOperation: _company.shiftOperation);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _hoursController,
            decoration: const InputDecoration(labelText: 'Working hours'),
            onChanged: (value) {
              _company.workingHours = value;
              _form.companyBackground =
                  _form.companyBackground.copyWith(workingHours: value);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Working days'),
            onChanged: (value) {
              final parsed = int.tryParse(value) ?? value;
              _company.workingDays = parsed;
              _form.companyBackground =
                  _form.companyBackground.copyWith(workingDays: parsed);
              _form.recalculateAll();
            },
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
        ...[
          'measure_standard_time',
          'measure_pcd',
          'interested_automation',
          'ie_department',
          'lean_belt_professionals',
          'track_operator_performance',
          'training_school',
          'five_s_certification',
          'incentive_system',
          'one_year_plan',
          'lean_tools_practiced',
        ].map((field) => _YesNoField(
              label: field.replaceAll('_', ' '),
              value: _yesNoValue(pe, field),
              onChanged: (value) => setState(() {
                _form.processExcellence = _updateProcessExcellence(pe, field, value);
              }),
            )),
        if (pe.leanBeltProfessionals == 'yes') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: pe.leanBeltLevel,
            decoration: const InputDecoration(labelText: 'Lean belt level'),
            items: leanBeltLevels.entries
                .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: (value) => setState(() {
              _form.processExcellence = pe.copyWith(leanBeltLevel: value);
            }),
          ),
        ],
        if (pe.fiveSCertification == 'yes') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: pe.fiveSLevel,
            decoration: const InputDecoration(labelText: '5S level'),
            items: fiveSLevels.entries
                .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: (value) => setState(() {
              _form.processExcellence = pe.copyWith(fiveSLevel: value);
            }),
          ),
        ],
        if (pe.incentiveSystem == 'yes') ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: pe.incentiveDetails,
            decoration: const InputDecoration(labelText: 'Incentive details'),
            onChanged: (value) => setState(() {
              _form.processExcellence = pe.copyWith(incentiveDetails: value);
            }),
          ),
        ],
        if (pe.oneYearPlan == 'yes') ...[
          const SizedBox(height: 12),
          Text('Improvement projects', style: Theme.of(context).textTheme.titleLarge),
          ...List.generate(pe.improvementProjects.length, (index) {
            final project = pe.improvementProjects[index];
            return _ImprovementProjectCard(
              project: project,
              onChanged: (next) {
                final projects = [...pe.improvementProjects];
                projects[index] = next;
                setState(() {
                  _form.processExcellence = pe.copyWith(improvementProjects: projects);
                });
              },
              onRemove: () {
                final projects = [...pe.improvementProjects]..removeAt(index);
                setState(() {
                  _form.processExcellence = pe.copyWith(improvementProjects: projects);
                });
              },
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() {
              _form.processExcellence = pe.copyWith(
                improvementProjects: [...pe.improvementProjects, const ImprovementProject()],
              );
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add project'),
          ),
        ],
        if (pe.leanToolsPracticed == 'yes') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: pe.leanPracticeDetails,
            decoration: const InputDecoration(labelText: 'Lean practice details'),
            items: leanPracticeMethods.entries
                .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: (value) => setState(() {
              _form.processExcellence = pe.copyWith(leanPracticeDetails: value);
            }),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          initialValue: pe.painAreas,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Pain areas'),
          onChanged: (value) => setState(() {
            _form.processExcellence = pe.copyWith(painAreas: value);
          }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: pe.improvementsExpected,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Improvements expected'),
          onChanged: (value) => setState(() {
            _form.processExcellence = pe.copyWith(improvementsExpected: value);
          }),
        ),
      ],
    );
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
                Text('Status: ${dsrStatusLabel(_form.status == 'submitted' ? 'published' : _form.status)}'),
                Text('Analysis period from: ${bg.analysisPeriodFrom ?? 'N/A'}'),
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

class _ImprovementProjectCard extends StatelessWidget {
  const _ImprovementProjectCard({
    required this.project,
    required this.onChanged,
    required this.onRemove,
  });

  final ImprovementProject project;
  final ValueChanged<ImprovementProject> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              initialValue: project.project,
              decoration: const InputDecoration(labelText: 'Project'),
              onChanged: (value) => onChanged(project.copyWith(project: value)),
            ),
            TextFormField(
              initialValue: project.currentPerformance,
              decoration: const InputDecoration(labelText: 'Current performance'),
              onChanged: (value) => onChanged(project.copyWith(currentPerformance: value)),
            ),
            TextFormField(
              initialValue: project.goal,
              decoration: const InputDecoration(labelText: 'Goal'),
              onChanged: (value) => onChanged(project.copyWith(goal: value)),
            ),
            TextFormField(
              initialValue: project.completionDate,
              decoration: const InputDecoration(labelText: 'Completion date'),
              onChanged: (value) => onChanged(project.copyWith(completionDate: value)),
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'yes', label: Text('Yes')),
              ButtonSegment(value: 'no', label: Text('No')),
            ],
            selected: {value.isEmpty ? 'no' : value},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
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
