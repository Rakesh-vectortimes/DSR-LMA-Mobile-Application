/// Shared API response envelope: `{ success, message, data }`.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  final bool success;
  final String message;
  final T? data;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? fromJsonT,
  ) {
    final raw = json['data'];
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: raw == null || fromJsonT == null ? raw as T? : fromJsonT(raw),
    );
  }

  static ApiResponse<T> fromDioData<T>(
    dynamic data,
    T Function(Object? json)? fromJsonT,
  ) {
    if (data is Map<String, dynamic>) {
      return ApiResponse.fromJson(data, fromJsonT);
    }
    if (data is Map) {
      return ApiResponse.fromJson(Map<String, dynamic>.from(data), fromJsonT);
    }
    return ApiResponse<T>(
      success: false,
      message: 'Unexpected response format',
      data: null,
    );
  }
}

/// Domain-level API failure with a user-facing message.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.success = false});

  final String message;
  final int? statusCode;
  final bool success;

  @override
  String toString() => message;

  static String messageFromBody(dynamic data, {String fallback = 'Request failed'}) {
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      if (detail is List && detail.isNotEmpty) {
        final parts = <String>[];
        for (final item in detail) {
          if (item is Map && item['msg'] != null) {
            final loc = item['loc'];
            final field = loc is List && loc.isNotEmpty ? loc.last.toString() : null;
            final msg = item['msg'].toString();
            parts.add(field == null ? msg : '$field: $msg');
          } else if (item != null) {
            parts.add(item.toString());
          }
        }
        if (parts.isNotEmpty) return parts.join('\n');
      }
    }
    return fallback;
  }
}
