import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/report_status.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dsr/data/dsr_repository.dart';
import '../../dsr/data/models/dsr_models.dart';
import '../../lma/data/lma_assessment_repository.dart';
import '../../lma/data/models/lma_assessment_models.dart';
import '../../lma/presentation/lma_config_controller.dart';
import 'report_nav.dart';

/// Dashboard with LMA and DSR status counts. A tap opens that list filtered.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _tab = 0;
  _StatusCounts? _lmaCounts;
  _StatusCounts? _dsrCounts;
  bool _lmaLoading = true;
  bool _dsrLoading = true;
  String? _lmaError;
  String? _dsrError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadLma(), _loadDsr()]);
  }

  Future<void> _loadLma() async {
    setState(() {
      _lmaLoading = true;
      _lmaError = null;
    });
    try {
      unawaited(ref.read(lmaConfigControllerProvider.notifier).ensureLoaded());
      final repo = ref.read(lmaAssessmentRepositoryProvider);
      final results = await Future.wait([
        repo.listPage(const LmaQueryParams(page: 1, limit: 1)),
        repo.listPage(const LmaQueryParams(
            page: 1, limit: 1, status: ReportStatus.draft)),
        repo.listPage(
          const LmaQueryParams(
              page: 1, limit: 1, status: ReportStatus.published),
        ),
        repo.listPage(const LmaQueryParams(
            page: 1, limit: 1, status: ReportStatus.archived)),
      ]);
      if (!mounted) return;
      setState(() {
        _lmaCounts = _StatusCounts(
          all: results[0].total,
          draft: results[1].total,
          published: results[2].total,
          archived: results[3].total,
        );
        _lmaLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lmaLoading = false;
        _lmaError = e.toString();
      });
    }
  }

  Future<void> _loadDsr() async {
    setState(() {
      _dsrLoading = true;
      _dsrError = null;
    });
    try {
      final repo = ref.read(dsrRepositoryProvider);
      final results = await Future.wait([
        repo.listPage(const DsrQueryParams(page: 1, limit: 1)),
        repo.listPage(const DsrQueryParams(
            page: 1, limit: 1, status: ReportStatus.draft)),
        repo.listPage(
          const DsrQueryParams(
              page: 1, limit: 1, status: ReportStatus.published),
        ),
        repo.listPage(const DsrQueryParams(
            page: 1, limit: 1, status: ReportStatus.archived)),
      ]);
      if (!mounted) return;
      setState(() {
        _dsrCounts = _StatusCounts(
          all: results[0].total,
          draft: results[1].total,
          published: results[2].total,
          archived: results[3].total,
        );
        _dsrLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dsrLoading = false;
        _dsrError = e.toString();
      });
    }
  }

  void _open(int? status) {
    if (_tab == 0) {
      ref.read(reportNavProvider.notifier).openLma(status);
      context.go(AppRoutes.lma);
      return;
    }
    ref.read(reportNavProvider.notifier).openDsr(status);
    context.go(AppRoutes.dsr);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(lmaConfigControllerProvider);
    final isLma = _tab == 0;
    final loading = isLma ? _lmaLoading : _dsrLoading;
    final error = isLma ? _lmaError : _dsrError;
    final counts = isLma ? _lmaCounts : _dsrCounts;

    return Scaffold(
      backgroundColor: const Color(0xFFE7F4EF),
      appBar: AppBar(
        title: const Text('DSR & LMA'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : (isLma ? _loadLma : _loadDsr),
            icon: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ModuleTabs(
              index: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: isLma ? _loadLma : _loadDsr,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (auth.canCreateReports) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLma
                            ? (config.canCreateAssessment
                                ? () => context.go(AppRoutes.lmaCreate)
                                : null)
                            : () => context.go(AppRoutes.dsrCreate),
                        child: Text(isLma ? 'New assessment' : 'New study'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isLma ? 'Assessments' : 'Studies',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _open(null),
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a status to open the matching list.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (error != null && counts == null)
                    _ErrorPanel(
                      message: error,
                      onRetry: isLma ? _loadLma : _loadDsr,
                    )
                  else
                    _StatGrid(
                      counts: counts,
                      loading: loading && counts == null,
                      onSelected: _open,
                    ),
                  if (error != null && counts != null) ...[
                    const SizedBox(height: 12),
                    Text(error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCounts {
  const _StatusCounts({
    required this.all,
    required this.draft,
    required this.published,
    required this.archived,
  });

  final int all;
  final int draft;
  final int published;
  final int archived;
}

class _ModuleTabs extends StatelessWidget {
  const _ModuleTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab(context, 0, 'LMA', Icons.insights_outlined),
          _tab(context, 1, 'DSR', Icons.description_outlined),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int value, String label, IconData icon) {
    final selected = index == value;
    return Expanded(
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? Colors.white : AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.counts,
    required this.loading,
    required this.onSelected,
  });

  final _StatusCounts? counts;
  final bool loading;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: (1.35 / textScale).clamp(0.9, 1.35),
      children: [
        _StatTile(
          label: 'All',
          count: counts?.all,
          loading: loading,
          icon: Icons.grid_view_rounded,
          background: const Color(0xFFD6E6FF),
          foreground: const Color(0xFF2F6FE0),
          onTap: () => onSelected(null),
        ),
        _StatTile(
          label: 'Draft',
          count: counts?.draft,
          loading: loading,
          icon: Icons.schedule,
          background: const Color(0xFFFFE4C2),
          foreground: const Color(0xFFD4880F),
          onTap: () => onSelected(ReportStatus.draft),
        ),
        _StatTile(
          label: 'Published',
          count: counts?.published,
          loading: loading,
          icon: Icons.task_alt,
          background: const Color(0xFFD9F5E5),
          foreground: const Color(0xFF1E8A4C),
          onTap: () => onSelected(ReportStatus.published),
        ),
        _StatTile(
          label: 'Archived',
          count: counts?.archived,
          loading: loading,
          icon: Icons.inventory_2_outlined,
          background: const Color(0xFFF8D6DC),
          foreground: const Color(0xFFC0392B),
          onTap: () => onSelected(ReportStatus.archived),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.count,
    required this.loading,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool loading;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 22),
                const SizedBox(height: 6),
                if (loading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: foreground),
                  )
                else
                  Text(
                    '${count ?? 0}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                      height: 1.1,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style:
                      TextStyle(fontWeight: FontWeight.w700, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

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
                size: 40, color: Theme.of(context).colorScheme.error),
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
