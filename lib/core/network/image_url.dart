import '../config/app_config.dart';

/// Resolve API/public media paths for display.
String resolveMediaUrl(Object? image, {String? apiOrigin}) {
  if (image == null) return '';

  if (image is String) {
    final value = image.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:')) {
      return value;
    }
    final path = value.startsWith('/') ? value : '/$value';
    final origin = apiOrigin ?? _defaultApiOrigin();
    return '$origin$path';
  }

  if (image is Map) {
    final map = Map<String, dynamic>.from(image);
    final imageUrl = (map['image_url'] ?? map['url'])?.toString().trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return resolveMediaUrl(imageUrl, apiOrigin: apiOrigin);
    }
    final upload = (map['uploadurl'] ?? map['upload_url'])?.toString().trim();
    if (upload == null || upload.isEmpty) return '';
    return resolveMediaUrl(upload, apiOrigin: apiOrigin);
  }

  return '';
}

String _defaultApiOrigin() {
  try {
    final config = AppConfig.instance;
    final fromBase = config.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (fromBase.isNotEmpty) return fromBase;
    return config.apiV1BaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
  } catch (_) {
    return '';
  }
}
