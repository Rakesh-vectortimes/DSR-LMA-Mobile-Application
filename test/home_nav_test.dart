import 'package:flutter_test/flutter_test.dart';

import 'package:dsr_lma/core/constants/report_status.dart';
import 'package:dsr_lma/features/home/presentation/report_nav.dart';
import 'package:dsr_lma/shared/widgets/report_filter_sheet.dart';

void main() {
  test('date presets use calendar today, week, and month', () {
    final now = DateTime(2026, 11, 3);

    final today = dateRangeForPreset(DatePreset.today, now);
    expect(today.start, DateTime(2026, 11, 3));
    expect(today.end, DateTime(2026, 11, 3));

    final yesterday = dateRangeForPreset(DatePreset.yesterday, now);
    expect(yesterday.start, DateTime(2026, 11, 2));
    expect(yesterday.end, DateTime(2026, 11, 2));

    final week = dateRangeForPreset(DatePreset.thisWeek, now);
    expect(week.start, DateTime(2026, 11, 2));
    expect(week.end, DateTime(2026, 11, 8));

    final month = dateRangeForPreset(DatePreset.thisMonth, now);
    expect(month.start, DateTime(2026, 11, 1));
    expect(month.end, DateTime(2026, 11, 30));
  });

  test('formatFilterDateRange describes open and closed ranges', () {
    expect(formatFilterDateRange(null, null), 'All dates');
    expect(
      formatFilterDateRange(DateTime(2026, 10, 28), DateTime(2026, 11, 3)),
      '28 Oct 2026 - 3 Nov 2026',
    );
    expect(
      formatFilterDateRange(DateTime(2026, 11, 3), DateTime(2026, 11, 3)),
      '3 Nov 2026',
    );
  });

  test('home status taps record a fresh list request', () {
    final nav = ReportNavController();

    nav.openLma(ReportStatus.draft);
    expect(nav.state.lma?.status, ReportStatus.draft);
    final first = nav.state.lma!.token;

    nav.openLma(ReportStatus.published);
    expect(nav.state.lma?.status, ReportStatus.published);
    expect(nav.state.lma!.token, isNot(first));

    nav.openDsr(null);
    expect(nav.state.dsr?.status, isNull);
    expect(nav.state.lma?.status, ReportStatus.published);
  });
}
