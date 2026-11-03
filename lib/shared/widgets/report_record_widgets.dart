import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/report_status.dart';
import '../../core/theme/app_theme.dart';

class ReportStatusPill extends StatelessWidget {
  const ReportStatusPill({
    super.key,
    required this.status,
    required this.label,
  });

  final int status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = status == ReportStatus.published
        ? const Color(0xFF1F8F55)
        : status == ReportStatus.archived
            ? const Color(0xFF8D6E63)
            : const Color(0xFFE39B2B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class ReportMetaRow extends StatelessWidget {
  const ReportMetaRow({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final value = text.trim();
    if (value.isEmpty || value == 'N/A') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(color: AppColors.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportListToolbar extends StatelessWidget {
  const ReportListToolbar({
    super.key,
    required this.searchController,
    required this.hint,
    required this.statusLabel,
    required this.dateLabel,
    required this.onStatus,
    required this.onSearch,
    required this.onOpenFilters,
  });

  final TextEditingController searchController;
  final String hint;
  final String statusLabel;
  final String dateLabel;
  final ValueChanged<int?> onStatus;
  final VoidCallback onSearch;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              return TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            searchController.clear();
                            onSearch();
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onSubmitted: (_) => onSearch(),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: PopupMenuButton<int>(
                  tooltip: 'Status',
                  onSelected: (value) => onStatus(value < 0 ? null : value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: -1, child: Text('All')),
                    for (final value in ReportStatus.values)
                      PopupMenuItem(
                        value: value,
                        child: Text(ReportStatus.labels[value]!),
                      ),
                  ],
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F3EE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              color: AppColors.primaryDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Filters',
                onPressed: onOpenFilters,
                icon: const Icon(Icons.tune),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.divider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReportPageBar extends StatelessWidget {
  const ReportPageBar({
    super.key,
    required this.page,
    required this.pages,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Page $page of $pages',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

String labeledPerson(String label, String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty || text == 'N/A') return '';
  return '$label $text';
}

String formatUpdatedAt(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return 'Last updated: $value';
  return 'Last updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal())}';
}
