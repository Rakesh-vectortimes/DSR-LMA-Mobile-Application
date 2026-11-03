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
import '../../../shared/widgets/report_filter_sheet.dart';
import '../../../shared/widgets/report_record_widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../companies/data/company_repository.dart';
import '../../companies/data/crm_repository.dart';
import '../../companies/data/models/converted_company.dart';
import '../../companies/data/models/organization.dart';
import '../../companies/data/organization_repository.dart';
import '../../home/presentation/report_nav.dart';
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
  String? _error;
  String? _exportingId;
  int _appliedNavToken = 0;
  int _loadGeneration = 0;

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

  List<String> get _companyNames {
    final names = <String>{};
    for (final company in _convertedCompanies) {
      if (company.companyName.trim().isNotEmpty) names.add(company.companyName);
    }
    return names.toList();
  }

  String get _statusChipLabel {
    final name =
        _status == null ? 'All' : (ReportStatus.labels[_status] ?? 'All');
    return '$name ($_total)';
  }

  @override
  void initState() {
    super.initState();
    _takeIncomingRequest();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _takeIncomingRequest() {
    final request = ref.read(reportNavProvider).lma;
    if (request == null || request.token == _appliedNavToken) return false;
    _appliedNavToken = request.token;
    _status = request.status;
    _page = 1;
    _searchController.clear();
    _convertedCompanyName = '';
    _createdBy = '';
    _fromDate = null;
    _toDate = null;
    _limit = 10;
    return true;
  }

  Future<void> _initialize() async {
    await ref.read(lmaConfigControllerProvider.notifier).ensureLoaded();
    await Future.wait([_loadOrgFilters(), _loadRecords()]);
  }

  Future<void> _loadOrgFilters() async {
    try {
      _convertedCompanies =
          await ref.read(crmRepositoryProvider).listConvertedCompaniesResolved(
                convertedTo: CrmConversionType.lma,
                companyRepository: ref.read(companyRepositoryProvider),
              );
      if (_convertedCompanyName.isNotEmpty &&
          !_convertedCompanies
              .any((company) => company.companyName == _convertedCompanyName)) {
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
      final creators =
          await ref.read(organizationRepositoryProvider).getCreators();
      if (!mounted) return;
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
    final generation = ++_loadGeneration;
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
              reportDateTo: _toDate == null
                  ? null
                  : DateFormat('yyyy-MM-dd').format(_toDate!),
              status: _status,
            ),
          );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _records = result.items;
        _page = result.page;
        _limit = result.limit;
        _pages = result.pages;
        _total = result.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openFilters() async {
    final result = await showReportFilterSheet(
      context: context,
      initial: ReportFilterValues(
        status: _status,
        companyName: _convertedCompanyName,
        createdBy: _createdBy,
        from: _fromDate,
        to: _toDate,
        limit: _limit,
      ),
      companies: _companyNames,
      creators: _creators,
      dateLabel: 'Report date',
      limitOptions: _limitOptions,
    );
    if (result == null || !mounted) return;
    setState(() {
      _status = result.status;
      _convertedCompanyName = result.companyName;
      _createdBy = result.createdBy;
      _fromDate = result.from;
      _toDate = result.to;
      _limit = result.limit;
      _page = 1;
    });
    await _loadRecords();
  }

  Future<void> _deleteRecord(LeanMaturityAssessmentRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete assessment'),
        content: Text(
            'Delete lean maturity assessment for "${record.displayCompanyName}"?'),
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

  Future<void> _export(
      LeanMaturityAssessmentRecord record, ExportKind kind) async {
    if (record.id.isEmpty) return;
    setState(() => _exportingId = '${record.id}-${kind.extension}');
    await exportAndShare(
      ref: ref,
      context: context,
      preparingMessage: kind == ExportKind.pdf
          ? 'Preparing PDF report...'
          : 'Preparing Word report...',
      download: () {
        final typography = ref.read(typographyControllerProvider);
        final repo = ref.read(lmaAssessmentRepositoryProvider);
        return kind == ExportKind.pdf
            ? repo.exportPdf(record.id, record: record, typography: typography)
            : repo.exportWord(record.id,
                record: record, typography: typography);
      },
    );
    if (mounted) setState(() => _exportingId = null);
  }

  void _onMenu(LeanMaturityAssessmentRecord record, String action) {
    switch (action) {
      case 'preview':
        context.go(AppRoutes.lmaPreview(record.id));
      case 'edit':
        context.go(AppRoutes.lmaEdit(record.id));
      case 'pdf':
        _export(record, ExportKind.pdf);
      case 'word':
        _export(record, ExportKind.word);
      case 'delete':
        _deleteRecord(record);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(reportNavProvider, (previous, next) {
      if (!_takeIncomingRequest()) return;
      _loadRecords();
    });

    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(lmaConfigControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('LMA')),
      floatingActionButton: auth.canCreateReports
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7DDFC8),
              foregroundColor: const Color(0xFF14352C),
              onPressed: config.canCreateAssessment
                  ? () => context.go(AppRoutes.lmaCreate)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('New assessment'),
            )
          : null,
      body: Column(
        children: [
          ReportListToolbar(
            searchController: _searchController,
            hint: 'Search assessments',
            statusLabel: _statusChipLabel,
            dateLabel: formatFilterDateRange(_fromDate, _toDate),
            onStatus: (value) async {
              setState(() {
                _status = value;
                _page = 1;
              });
              await _loadRecords();
            },
            onSearch: () {
              setState(() => _page = 1);
              _loadRecords();
            },
            onOpenFilters: _openFilters,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRecords,
              child: _buildBody(auth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AuthState auth) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [_ErrorCard(message: _error!, onRetry: _loadRecords)],
      );
    }
    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No assessments found.')),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        ..._records.map((record) => _AssessmentCard(
              record: record,
              exporting: _exportingId?.startsWith(record.id) == true,
              items: _menuItems(auth, record),
              onSelected: (action) => _onMenu(record, action),
            )),
        ReportPageBar(
          page: _page,
          pages: _pages,
          onPrevious: _page > 1
              ? () {
                  setState(() => _page -= 1);
                  _loadRecords();
                }
              : null,
          onNext: _page < _pages
              ? () {
                  setState(() => _page += 1);
                  _loadRecords();
                }
              : null,
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _menuItems(
    AuthState auth,
    LeanMaturityAssessmentRecord record,
  ) {
    return [
      if (auth.canViewReports)
        const PopupMenuItem(value: 'preview', child: Text('Preview')),
      if (auth.canEditRecord(
            createdByRole: record.createdByRole,
            createdBy: record.raw?['created_by'],
          ) &&
          record.status != ReportStatus.published)
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
      if (auth.canViewReports) ...[
        const PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
        const PopupMenuItem(value: 'word', child: Text('Export Word')),
      ],
      if (auth.canDeleteRecord(
        createdByRole: record.createdByRole,
        createdBy: record.raw?['created_by'],
      ))
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
    ];
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.record,
    required this.exporting,
    required this.items,
    required this.onSelected,
  });

  final LeanMaturityAssessmentRecord record;
  final bool exporting;
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scores = record.scores;
    final showScore = scores != null && scores.maxScore > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    record.displayCompanyName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (exporting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (items.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: onSelected,
                    itemBuilder: (context) => items,
                  ),
              ],
            ),
            ReportMetaRow(
              icon: Icons.place_outlined,
              text: record.companyBackground?.location ?? '',
            ),
            ReportMetaRow(
              icon: Icons.person_outline,
              text: record.preparedBy ?? '',
            ),
            ReportMetaRow(
              icon: Icons.edit_outlined,
              text: labeledPerson(
                  'Updated by', record.updatedByName ?? record.updatedBy),
            ),
            ReportMetaRow(
              icon: Icons.calendar_today_outlined,
              text: record.reportDate ?? '',
            ),
            ReportMetaRow(
              icon: Icons.access_time,
              text: formatUpdatedAt(record.updatedAt),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: ReportStatusPill(
                      status: record.status, label: record.displayStatus),
                ),
                if (showScore) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Score: ${scores.percentage}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ],
        ),
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
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
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
