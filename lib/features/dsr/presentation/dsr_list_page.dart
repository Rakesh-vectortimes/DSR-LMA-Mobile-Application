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
import '../data/dsr_repository.dart';
import '../data/models/dsr_models.dart';

class DsrListPage extends ConsumerStatefulWidget {
  const DsrListPage({super.key});

  @override
  ConsumerState<DsrListPage> createState() => _DsrListPageState();
}

class _DsrListPageState extends ConsumerState<DsrListPage> {
  final _searchController = TextEditingController();
  final List<int> _limitOptions = const [5, 10, 25, 50];

  List<DiagnosticStudyRecord> _records = const [];
  List<OrganizationCreator> _creators = const [];
  List<ConvertedCompany> _convertedCompanies = const [];
  int _page = 1;
  int _limit = 10;
  int _pages = 1;
  int _total = 0;
  int? _status;
  String _convertedCompanyName = '';
  String _createdBy = '';
  DateTime? _periodFrom;
  DateTime? _periodTo;
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
    final request = ref.read(reportNavProvider).dsr;
    if (request == null || request.token == _appliedNavToken) return false;
    _appliedNavToken = request.token;
    _status = request.status;
    _page = 1;
    _searchController.clear();
    _convertedCompanyName = '';
    _createdBy = '';
    _periodFrom = null;
    _periodTo = null;
    _limit = 10;
    return true;
  }

  Future<void> _initialize() async {
    await Future.wait([_loadOrgFilters(), _loadRecords()]);
  }

  Future<void> _loadOrgFilters() async {
    try {
      _convertedCompanies =
          await ref.read(crmRepositoryProvider).listConvertedCompaniesResolved(
                convertedTo: CrmConversionType.dsr,
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
      final result = await ref.read(dsrRepositoryProvider).listPage(
            DsrQueryParams(
              page: _page,
              limit: _limit,
              search: _searchController.text.trim().isEmpty
                  ? _convertedCompanySearchFallback
                  : _searchController.text.trim(),
              companyId: _selectedConvertedCompanyId,
              createdBy: _createdBy.isEmpty ? null : _createdBy,
              periodFrom: _periodFrom == null
                  ? null
                  : DateFormat('yyyy-MM-dd').format(_periodFrom!),
              periodTo: _periodTo == null
                  ? null
                  : DateFormat('yyyy-MM-dd').format(_periodTo!),
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
        from: _periodFrom,
        to: _periodTo,
        limit: _limit,
      ),
      companies: _companyNames,
      creators: _creators,
      dateLabel: 'Analysis period',
      limitOptions: _limitOptions,
    );
    if (result == null || !mounted) return;
    setState(() {
      _status = result.status;
      _convertedCompanyName = result.companyName;
      _createdBy = result.createdBy;
      _periodFrom = result.from;
      _periodTo = result.to;
      _limit = result.limit;
      _page = 1;
    });
    await _loadRecords();
  }

  Future<void> _deleteRecord(DiagnosticStudyRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete study'),
        content:
            Text('Delete diagnostic study for "${record.displayCompanyName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(dsrRepositoryProvider).delete(record.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study deleted.')),
      );
      await _loadRecords();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _export(DiagnosticStudyRecord record, ExportKind kind) async {
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
        final repo = ref.read(dsrRepositoryProvider);
        return kind == ExportKind.pdf
            ? repo.exportPdf(record.id, record: record, typography: typography)
            : repo.exportWord(record.id,
                record: record, typography: typography);
      },
    );
    if (mounted) setState(() => _exportingId = null);
  }

  void _onMenu(DiagnosticStudyRecord record, String action) {
    switch (action) {
      case 'preview':
        context.go(AppRoutes.dsrPreview(record.id));
      case 'edit':
        context.go(AppRoutes.dsrEdit(record.id));
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

    return Scaffold(
      appBar: AppBar(title: const Text('DSR')),
      floatingActionButton: auth.canCreateReports
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7DDFC8),
              foregroundColor: const Color(0xFF14352C),
              onPressed: () => context.go(AppRoutes.dsrCreate),
              icon: const Icon(Icons.add),
              label: const Text('New study'),
            )
          : null,
      body: Column(
        children: [
          ReportListToolbar(
            searchController: _searchController,
            hint: 'Search studies',
            statusLabel: _statusChipLabel,
            dateLabel: formatFilterDateRange(_periodFrom, _periodTo),
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
              child: Center(child: Text('No studies found.')),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        ..._records.map((record) => _StudyCard(
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
      AuthState auth, DiagnosticStudyRecord record) {
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

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.record,
    required this.exporting,
    required this.items,
    required this.onSelected,
  });

  final DiagnosticStudyRecord record;
  final bool exporting;
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
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
              icon: Icons.date_range_outlined,
              text: record.analysisPeriod ?? '',
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
            Align(
              alignment: Alignment.centerLeft,
              child: ReportStatusPill(
                  status: record.status, label: record.displayStatus),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
