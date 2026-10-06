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
import '../../../shared/widgets/report_export_buttons.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../companies/data/company_repository.dart';
import '../../companies/data/crm_repository.dart';
import '../../companies/data/models/converted_company.dart';
import '../../companies/data/models/organization.dart';
import '../../companies/data/organization_repository.dart';
import '../data/lma_assessment_repository.dart';
import '../data/models/lma_assessment_models.dart';
import 'lma_config_controller.dart';

class LmaListPage extends ConsumerStatefulWidget {
  const LmaListPage({super.key});

  @override
  ConsumerState<LmaListPage> createState() => _LmaListPageState();
}

class _LmaListPageState extends ConsumerState<LmaListPage> {
  final _searchController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  final List<int> _limitOptions = const [5, 10, 25, 50];

  List<LeanMaturityAssessmentRecord> _records = const [];
  List<OrganizationCreator> _creators = const [];
  List<ConvertedCompany> _convertedCompanies = const [];
  int _page = 1;
  int _limit = 10;
  int _pages = 1;
  int _total = 0;
  int? _status;
  String _convertedCompanyName = '';
  String _createdBy = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _loading = true;
  bool _filtersExpanded = true;
  String? _error;
  String? _exportingId;

  String? get _selectedConvertedCompanyId {
    if (_convertedCompanyName.isEmpty) return null;
    for (final company in _convertedCompanies) {
      if (company.companyName == _convertedCompanyName &&
          company.resolvedCompanyId.isNotEmpty) {
        return company.resolvedCompanyId;
      }
    }
    return null;
  }

  String? get _convertedCompanySearchFallback {
    if (_convertedCompanyName.isEmpty || _selectedConvertedCompanyId != null) {
      return null;
    }
    return _convertedCompanyName;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await ref.read(lmaConfigControllerProvider.notifier).ensureLoaded();
    await Future.wait([_loadOrgFilters(), _loadRecords()]);
  }

  Future<void> _loadOrgFilters() async {
    try {
      _convertedCompanies = await ref.read(crmRepositoryProvider).listConvertedCompaniesResolved(
            convertedTo: CrmConversionType.lma,
            companyRepository: ref.read(companyRepositoryProvider),
          );
      if (_convertedCompanyName.isNotEmpty &&
          !_convertedCompanies.any((company) => company.companyName == _convertedCompanyName)) {
        _convertedCompanyName = '';
      }
    } catch (_) {
      _convertedCompanies = const [];
    }
    if (mounted) setState(() {});
    await _loadCreators();
  }

  Future<void> _loadCreators() async {
    try {
      final creators = await ref.read(organizationRepositoryProvider).getCreators();
      setState(() {
        _creators = creators.items;
        if (_createdBy.isNotEmpty &&
            !_creators.any((creator) => creator.employeeId == _createdBy)) {
          _createdBy = '';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _creators = const []);
    }
  }

  Future<void> _loadRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(lmaAssessmentRepositoryProvider).listPage(
            LmaQueryParams(
              page: _page,
              limit: _limit,
              search: _searchController.text.trim().isEmpty
                  ? _convertedCompanySearchFallback
                  : _searchController.text.trim(),
              companyId: _selectedConvertedCompanyId,
              createdBy: _createdBy.isEmpty ? null : _createdBy,
              reportDateFrom: _fromDate == null
                  ? null
                  : DateFormat('yyyy-MM-dd').format(_fromDate!),
              reportDateTo:
                  _toDate == null ? null : DateFormat('yyyy-MM-dd').format(_toDate!),
              status: _status,
            ),
          );
      if (!mounted) return;
      setState(() {
        _records = result.items;
        _page = result.page;
        _limit = result.limit;
        _pages = result.pages;
        _total = result.total;
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

  Future<void> _pickDate({required bool from}) async {
    final current = from ? _fromDate : _toDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (from) {
        _fromDate = selected;
        _fromController.text = DateFormat('yyyy-MM-dd').format(selected);
      } else {
        _toDate = selected;
        _toController.text = DateFormat('yyyy-MM-dd').format(selected);
      }
      _page = 1;
    });
    await _loadRecords();
  }

  Future<void> _deleteRecord(LeanMaturityAssessmentRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete assessment'),
        content: Text('Delete lean maturity assessment for "${record.displayCompanyName}"?'),
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
    if (confirmed != true) return;

    try {
      await ref.read(lmaAssessmentRepositoryProvider).delete(record.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment deleted.')),
      );
      await _loadRecords();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _export(LeanMaturityAssessmentRecord record, ExportKind kind) async {
    if (record.id.isEmpty) return;
    setState(() => _exportingId = '${record.id}-${kind.extension}');
    await exportAndShare(
      ref: ref,
      context: context,
      preparingMessage: kind == ExportKind.pdf ? 'Preparing PDF report...' : 'Preparing Word report...',
      download: () {
        final typography = ref.read(typographyControllerProvider);
        final repo = ref.read(lmaAssessmentRepositoryProvider);
        return kind == ExportKind.pdf
            ? repo.exportPdf(record.id, record: record, typography: typography)
            : repo.exportWord(record.id, record: record, typography: typography);
      },
    );
    if (mounted) setState(() => _exportingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(lmaConfigControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LMA'),
      ),
      floatingActionButton: auth.canCreateReports
          ? FloatingActionButton.extended(
              onPressed: config.canCreateAssessment
                  ? () => context.go(AppRoutes.lmaCreate)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('New assessment'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadRecords,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilters(auth),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadRecords)
            else
              _buildResults(auth),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(AuthState auth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Icon(
                      _filtersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
            ),
            if (_filtersExpanded) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) {
                  setState(() => _page = 1);
                  _loadRecords();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All')),
                  ...ReportStatus.values.map(
                    (value) => DropdownMenuItem<int?>(
                      value: value,
                      child: Text(ReportStatus.labels[value]!),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  setState(() {
                    _status = value;
                    _page = 1;
                  });
                  await _loadRecords();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _convertedCompanyName.isEmpty ? '' : _convertedCompanyName,
                decoration: const InputDecoration(labelText: 'Organization'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All')),
                  ..._convertedCompanies.map(
                    (company) => DropdownMenuItem(
                      value: company.companyName,
                      child: Text(company.companyName),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  setState(() {
                    _convertedCompanyName = value ?? '';
                    _page = 1;
                  });
                  await _loadRecords();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _createdBy.isEmpty ? '' : _createdBy,
                decoration: const InputDecoration(labelText: 'Created by'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All')),
                  ..._creators.map(
                    (creator) => DropdownMenuItem(
                      value: creator.employeeId,
                      child: Text(creator.name.isEmpty ? creator.employeeId : creator.name),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  setState(() {
                    _createdBy = value ?? '';
                    _page = 1;
                  });
                  await _loadRecords();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(from: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date from'),
                        child: Text(
                          _fromController.text.isEmpty ? 'Select' : _fromController.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(from: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date to'),
                        child: Text(
                          _toController.text.isEmpty ? 'Select' : _toController.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _limit,
                decoration: const InputDecoration(labelText: 'Rows per page'),
                items: _limitOptions
                    .map((value) => DropdownMenuItem(value: value, child: Text('$value')))
                    .toList(),
                onChanged: (value) async {
                  setState(() {
                    _limit = value ?? 10;
                    _page = 1;
                  });
                  await _loadRecords();
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _loadRecords,
                    child: const Text('Apply'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      setState(() {
                        _searchController.clear();
                        _status = null;
                        _convertedCompanyName = '';
                        _createdBy = '';
                        _fromDate = null;
                        _toDate = null;
                        _fromController.clear();
                        _toController.clear();
                        _limit = 10;
                        _page = 1;
                      });
                      await _loadCreators();
                      await _loadRecords();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AuthState auth) {
    if (_records.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No assessments found.')),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('$_total result(s)'),
        ),
        ..._records.map(
          (record) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          record.displayCompanyName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _StatusChip(
                        status: record.status,
                        label: record.displayStatus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetaLine(label: 'Prepared by', value: record.preparedBy ?? 'N/A'),
                  _MetaLine(label: 'Updated by', value: record.updatedBy ?? 'N/A'),
                  _MetaLine(label: 'Report date', value: record.reportDate ?? 'N/A'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (auth.canEditRecord(
                            createdByRole: record.createdByRole,
                            createdBy: record.raw?['created_by'],
                          ) &&
                          record.status != ReportStatus.published)
                        IconButton.outlined(
                          tooltip: 'Edit',
                          onPressed: () => context.go(AppRoutes.lmaEdit(record.id)),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      if (auth.canViewReports)
                        IconButton.outlined(
                          tooltip: 'Preview',
                          onPressed: () => context.go(AppRoutes.lmaPreview(record.id)),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                      if (auth.canViewReports)
                        ReportExportButtons(
                          iconOnly: true,
                          loading: _exportingId?.startsWith(record.id) == true,
                          onPdf: () => _export(record, ExportKind.pdf),
                          onWord: () => _export(record, ExportKind.word),
                        ),
                      if (auth.canDeleteRecord(
                        createdByRole: record.createdByRole,
                        createdBy: record.raw?['created_by'],
                      ))
                        IconButton.outlined(
                          tooltip: 'Delete',
                          onPressed: () => _deleteRecord(record),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Page $_page of $_pages'),
            Row(
              children: [
                IconButton(
                  onPressed: _page > 1
                      ? () async {
                          setState(() => _page -= 1);
                          await _loadRecords();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: _page < _pages
                      ? () async {
                          setState(() => _page += 1);
                          await _loadRecords();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final int status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = status == ReportStatus.published
        ? AppColors.success
        : status == ReportStatus.archived
            ? AppColors.warning
            : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
