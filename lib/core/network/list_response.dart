/// Normalizes list payloads and entity ids from the web API.
class ListResponse {
  ListResponse._();

  /// Prefer `id`, then `_id`, then first matching `*_id` field as string.
  static String extractId(
    Map<String, dynamic> json, {
    List<String> preferredKeys = const [],
  }) {
    for (final key in preferredKeys) {
      final value = normalizeEntityId(json[key]);
      if (value != null && value.isNotEmpty) return value;
    }

    final id = normalizeEntityId(json['id']);
    if (id != null && id.isNotEmpty) return id;

    final underscoreId = normalizeEntityId(json['_id']);
    if (underscoreId != null && underscoreId.isNotEmpty) return underscoreId;

    for (final entry in json.entries) {
      final key = entry.key;
      if (key == 'id' || key == '_id') continue;
      if (key.endsWith('_id')) {
        final value = normalizeEntityId(entry.value);
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return '';
  }

  /// Handles bare arrays and paginated/wrapped maps.
  ///
  /// Nested keys include DSR/LMA collections: studies, diagnostic_studies,
  /// assessments, lean_maturity_assessments.
  static List<T> extractItems<T>(
    dynamic data,
    T Function(Map<String, dynamic> json) fromJson, {
    List<String> nestedKeys = const [
      'items',
      'results',
      'data',
      'studies',
      'diagnostic_studies',
      'assessments',
      'lean_maturity_assessments',
      'companies',
      'employees',
    ],
  }) {
    if (data == null) return const [];

    if (data is List) {
      return data
          .whereType<Object>()
          .map((item) {
            try {
              if (item is Map<String, dynamic>) return fromJson(item);
              if (item is Map) return fromJson(Map<String, dynamic>.from(item));
            } catch (_) {
              return null;
            }
            return null;
          })
          .whereType<T>()
          .toList();
    }

    if (data is Map) {
      final map = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data);

      for (final key in nestedKeys) {
        if (!map.containsKey(key)) continue;
        final nested = map[key];
        if (nested is List || nested is Map) {
          return extractItems(nested, fromJson, nestedKeys: nestedKeys);
        }
      }
    }

    return const [];
  }
}

String? normalizeEntityId(Object? value) {
  if (value == null) return null;

  if (value is String) {
    final objectIdMatch = RegExp(r'''ObjectId\(["']?(.+?)["']?\)''').firstMatch(value);
    final normalized = (objectIdMatch?.group(1) ?? value).trim();
    return normalized.isEmpty ? null : normalized;
  }

  if (value is num) return value.toString();

  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    return normalizeEntityId(
      map[r'$oid'] ??
          map['id'] ??
          map['_id'] ??
          map['study_id'] ??
          map['assessment_id'] ??
          map['company_id'],
    );
  }

  final asString = value.toString().trim();
  return asString.isEmpty ? null : asString;
}
