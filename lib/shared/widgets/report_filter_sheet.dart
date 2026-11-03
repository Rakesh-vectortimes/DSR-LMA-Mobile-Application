import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/report_status.dart';
import '../../core/theme/app_theme.dart';
import '../../features/companies/data/models/organization.dart';

enum DatePreset { today, yesterday, thisWeek, thisMonth }

class ReportFilterValues {
  const ReportFilterValues({
    this.status,
    this.companyName = '',
    this.createdBy = '',
    this.from,
    this.to,
    this.limit = 10,
  });

  final int? status;
  final String companyName;
  final String createdBy;
  final DateTime? from;
  final DateTime? to;
  final int limit;

  ReportFilterValues cleared() {
    return const ReportFilterValues();
  }
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTimeRange dateRangeForPreset(DatePreset preset, DateTime now) {
  final today = dateOnly(now);
  switch (preset) {
    case DatePreset.today:
      return DateTimeRange(start: today, end: today);
    case DatePreset.yesterday:
      final yesterday = today.subtract(const Duration(days: 1));
      return DateTimeRange(start: yesterday, end: yesterday);
    case DatePreset.thisWeek:
      final start = today.subtract(Duration(days: today.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return DateTimeRange(start: start, end: end);
    case DatePreset.thisMonth:
      final start = DateTime(today.year, today.month, 1);
      final end = DateTime(today.year, today.month + 1, 0);
      return DateTimeRange(start: start, end: end);
  }
}

String formatFilterDateRange(DateTime? from, DateTime? to) {
  if (from == null && to == null) return 'All dates';
  final format = DateFormat('d MMM yyyy');
  if (from != null && to != null) {
    if (dateOnly(from) == dateOnly(to)) return format.format(from);
    return '${format.format(from)} - ${format.format(to)}';
  }
  if (from != null) return 'From ${format.format(from)}';
  return 'Until ${format.format(to!)}';
}

Future<ReportFilterValues?> showReportFilterSheet({
  required BuildContext context,
  required ReportFilterValues initial,
  required List<String> companies,
  required List<OrganizationCreator> creators,
  required String dateLabel,
  List<int> limitOptions = const [5, 10, 25, 50],
}) {
  return showModalBottomSheet<ReportFilterValues>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: _ReportFilterSheet(
          initial: initial,
          companies: companies,
          creators: creators,
          dateLabel: dateLabel,
          limitOptions: limitOptions,
        ),
      );
    },
  );
}

class _ReportFilterSheet extends StatefulWidget {
  const _ReportFilterSheet({
    required this.initial,
    required this.companies,
    required this.creators,
    required this.dateLabel,
    required this.limitOptions,
  });

  final ReportFilterValues initial;
  final List<String> companies;
  final List<OrganizationCreator> creators;
  final String dateLabel;
  final List<int> limitOptions;

  @override
  State<_ReportFilterSheet> createState() => _ReportFilterSheetState();
}

class _ReportFilterSheetState extends State<_ReportFilterSheet> {
  late int? _status;
  late String _companyName;
  late String _createdBy;
  late DateTime? _from;
  late DateTime? _to;
  late int _limit;
  DatePreset? _preset;
  late final List<OrganizationCreator> _creators;

  @override
  void initState() {
    super.initState();
    final seen = <String>{};
    _creators = [
      for (final creator in widget.creators)
        if (creator.employeeId.isNotEmpty && seen.add(creator.employeeId))
          creator,
    ];
    _status = widget.initial.status;
    _companyName = widget.companies.contains(widget.initial.companyName)
        ? widget.initial.companyName
        : '';
    _createdBy = _creators
            .any((creator) => creator.employeeId == widget.initial.createdBy)
        ? widget.initial.createdBy
        : '';
    _from = widget.initial.from;
    _to = widget.initial.to;
    _limit = widget.limitOptions.contains(widget.initial.limit)
        ? widget.initial.limit
        : 10;
    _preset = _matchingPreset(_from, _to);
  }

  DatePreset? _matchingPreset(DateTime? from, DateTime? to) {
    if (from == null || to == null) return null;
    final now = DateTime.now();
    for (final preset in DatePreset.values) {
      final range = dateRangeForPreset(preset, now);
      if (dateOnly(from) == range.start && dateOnly(to) == range.end) {
        return preset;
      }
    }
    return null;
  }

  void _selectPreset(DatePreset preset) {
    final range = dateRangeForPreset(preset, DateTime.now());
    setState(() {
      _preset = preset;
      _from = range.start;
      _to = range.end;
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: dateOnly(_from!), end: dateOnly(_to!))
          : DateTimeRange(start: dateOnly(now), end: dateOnly(now)),
    );
    if (picked == null) return;
    setState(() {
      _from = dateOnly(picked.start);
      _to = dateOnly(picked.end);
      _preset = _matchingPreset(_from, _to);
    });
  }

  ReportFilterValues _values() {
    return ReportFilterValues(
      status: _status,
      companyName: _companyName,
      createdBy: _createdBy,
      from: _from,
      to: _to,
      limit: _limit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Text('Date range',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _presetChip(DatePreset.today, 'Today'),
                      _presetChip(DatePreset.yesterday, 'Yesterday'),
                      _presetChip(DatePreset.thisWeek, 'This Week'),
                      _presetChip(DatePreset.thisMonth, 'This Month'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.dateLabel,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickRange,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(formatFilterDateRange(_from, _to)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  key: ValueKey('status-$_status'),
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('All')),
                    ...ReportStatus.values.map(
                      (value) => DropdownMenuItem<int?>(
                        value: value,
                        child: Text(ReportStatus.labels[value]!),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('company-$_companyName'),
                  initialValue: _companyName,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Organization'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All')),
                    ...widget.companies.map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _companyName = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('creator-$_createdBy'),
                  initialValue: _createdBy,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Created by'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All')),
                    ..._creators.map(
                      (creator) => DropdownMenuItem(
                        value: creator.employeeId,
                        child: Text(
                          creator.name.isEmpty
                              ? creator.employeeId
                              : creator.name,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _createdBy = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('limit-$_limit'),
                  initialValue: _limit,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Rows per page'),
                  items: widget.limitOptions
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text('$value')))
                      .toList(),
                  onChanged: (value) => setState(() => _limit = value ?? 10),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(widget.initial.cleared()),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      side: const BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Reset filter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_values()),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(DatePreset preset, String label) {
    final selected = _preset == preset;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? const Color(0xFFD8F3E8) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: selected ? const Color(0xFFD8F3E8) : AppColors.divider),
        ),
        child: InkWell(
          onTap: () => _selectPreset(preset),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check,
                      size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
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
