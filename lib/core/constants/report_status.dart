/// Shared DSR / LMA report lifecycle status.
///
/// Matches backend `ReportStatus` IntEnum stored as an integer in Mongo:
/// Draft = 1, Published = 2, Archived = 3.
abstract final class ReportStatus {
  static const int draft = 1;
  static const int published = 2;
  static const int archived = 3;

  static const List<int> values = [draft, published, archived];

  static const Map<int, String> labels = {
    draft: 'Draft',
    published: 'Published',
    archived: 'Archived',
  };

  static bool isValid(int value) =>
      value == draft || value == published || value == archived;

  /// Parse API `status` (int or legacy string). `"submitted"` maps to Published.
  static int parse(Object? value) {
    if (value is int) return isValid(value) ? value : draft;
    if (value is num) {
      final asInt = value.toInt();
      return isValid(asInt) ? asInt : draft;
    }
    final raw = (value?.toString() ?? '').trim();
    if (raw.isEmpty) return draft;
    final numeric = int.tryParse(raw);
    if (numeric != null && isValid(numeric)) return numeric;
    switch (raw.toLowerCase()) {
      case 'published':
      case 'submitted':
        return published;
      case 'archived':
        return archived;
      default:
        return draft;
    }
  }

  /// Display label. Prefer API `status_label` when present.
  static String labelOf(Object? value, {String? statusLabel}) {
    final fromApi = statusLabel?.trim() ?? '';
    if (fromApi.isNotEmpty) return fromApi;
    return labels[parse(value)] ?? labels[draft]!;
  }

  static String labelFromJson(Map<String, dynamic> json) {
    return labelOf(json['status'], statusLabel: json['status_label']?.toString());
  }

  /// Create/update payload value: always the integer enum.
  static int toApi(Object? value) => parse(value);

  /// List filter: `null` / empty / `"all"` omitted; otherwise the integer.
  static int? toApiFilter(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim().toLowerCase();
      if (trimmed.isEmpty || trimmed == 'all') return null;
    }
    return parse(value);
  }
}
