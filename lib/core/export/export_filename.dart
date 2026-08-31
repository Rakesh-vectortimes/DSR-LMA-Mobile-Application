import 'dart:typed_data';

enum ExportKind { pdf, word }

extension ExportKindX on ExportKind {
  String get extension => this == ExportKind.pdf ? 'pdf' : 'docx';

  String get mimeType => this == ExportKind.pdf
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
}

class ExportFile {
  const ExportFile({
    required this.bytes,
    required this.filename,
    required this.kind,
  });

  final Uint8List bytes;
  final String filename;
  final ExportKind kind;
}

/// Parses Content-Disposition: filename*=UTF-8''… then filename="…" then filename=….
String? filenameFromContentDisposition(String? header) {
  if (header == null || header.trim().isEmpty) return null;

  final utf8Match = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false).firstMatch(header);
  if (utf8Match != null) {
    final raw = utf8Match.group(1)!.replaceAll('"', '').replaceAll("'", '');
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }

  final quotedMatch = RegExp(r'filename="([^"]+)"', caseSensitive: false).firstMatch(header);
  if (quotedMatch != null) {
    return quotedMatch.group(1);
  }

  final plainMatch = RegExp(r'filename=([^;]+)', caseSensitive: false).firstMatch(header);
  return plainMatch?.group(1)?.trim().replaceAll('"', '').replaceAll("'", '');
}

String resolveExportFilename({
  required String? contentDisposition,
  required String fallback,
  required String lastResort,
}) {
  final fromHeader = filenameFromContentDisposition(contentDisposition);
  if (fromHeader != null && fromHeader.trim().isNotEmpty) {
    return sanitizeExportFilename(fromHeader.trim());
  }
  if (fallback.trim().isNotEmpty) {
    return sanitizeExportFilename(fallback.trim());
  }
  return sanitizeExportFilename(lastResort);
}

String sanitizeExportFilename(String filename) {
  return filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

/// "august 17" — month long lowercase, day without padding.
String formatExportDate(Object? value) {
  final date = parseExportDate(value);
  if (date == null) return '';
  const months = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

DateTime? parseExportDate(Object? value) {
  if (value == null || value == '') return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) {
    return DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  return DateTime.tryParse(text);
}

String buildLmaExportFilename({
  required String? companyName,
  required String? title,
  required String? reportDate,
  required ExportKind kind,
}) {
  final name = (companyName ?? title ?? 'Lean Maturity Assessment')
      .replaceFirst(RegExp(r' Lean Maturity Assessment$', caseSensitive: false), '')
      .trim();
  final dateLabel = formatExportDate(reportDate);
  final datePart = dateLabel.isEmpty ? '' : ' ($dateLabel)';
  return '$name lean maturity assessment report$datePart.${kind.extension}';
}

String buildDsrExportFilename({
  required String? companyName,
  required String? title,
  required String? periodFrom,
  required String? periodTo,
  required ExportKind kind,
}) {
  var name = (companyName ?? title ?? 'Diagnostic Study').trim();
  name = name.replaceFirst(RegExp(r' Diagnostic Study$', caseSensitive: false), '').trim();
  final fromLabel = formatExportDate(periodFrom);
  final toLabel = formatExportDate(periodTo);
  final datePart = fromLabel.isNotEmpty && toLabel.isNotEmpty
      ? '($fromLabel - $toLabel)'
      : fromLabel.isNotEmpty || toLabel.isNotEmpty
          ? '(${fromLabel.isNotEmpty ? fromLabel : toLabel})'
          : '';
  return '$name diagnostic study report$datePart.${kind.extension}';
}
