import 'dart:convert';
import 'dart:typed_data';

import '../../lma/data/models/lma_config_models.dart';
import '../../lma/domain/lean_maturity_data.dart';
import '../../lma/domain/lma_question_mapper.dart';
import '../data/models/lma_registration_models.dart';

/// Public registration page URL stored inside the QR. The app does not draw the code.
bool isLmaRegistrationQrUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  final path = uri.path;
  return path.endsWith('/register') || path.endsWith('/Lma-register');
}

/// `data:image/png;base64,...` or raw base64 from `Lma_qr.image`.
Uint8List? decodeQrImage(String? image) {
  final raw = image?.trim() ?? '';
  if (raw.isEmpty) return null;
  final payload = raw.contains(',') ? raw.split(',').last : raw;
  try {
    return base64Decode(payload.replaceAll(RegExp(r'\s'), ''));
  } catch (_) {
    return null;
  }
}

bool isRegistrationEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}

String lmaRegistrationEmailMessage({
  required bool emailSent,
  required String email,
  String? emailError,
}) {
  if (emailSent) {
    return 'The server emailed the assessment PDF to $email.';
  }
  switch (emailError) {
    case 'missing_email':
      return 'The registration was saved. The server did not send the PDF because the email address was missing.';
    case 'pdf_failed':
      return 'The registration was saved. The server could not create the PDF, so the email was not sent.';
    case 'smtp_not_configured':
      return 'The registration was saved. Email is not configured on the server, so the PDF was not sent.';
    default:
      final detail = emailError?.trim() ?? '';
      if (detail.isEmpty) {
        return 'The registration was saved. The server did not send the PDF email.';
      }
      return 'The registration was saved. The server did not send the PDF email: $detail';
  }
}

/// Sections, grades, and questions from `GET /public/lma-registration/config`.
PublicLmaFormConfig parsePublicLmaConfig(dynamic data) {
  final map = _asMap(data);
  final sections = _mapsOf(map, const ['sections'])
      .map(LmaSection.fromJson)
      .toList()
    ..sort((a, b) => (a.sectionOrder ?? 0).compareTo(b.sectionOrder ?? 0));

  final documents = <LmaQuestionDocument>[];
  final flat = <LeanMaturityQuestion>[];
  final questionNodes = _mapsOf(
    map,
    const ['questions', 'question_documents', 'lma_questions', 'documents'],
  );

  for (final item in questionNodes) {
    if (item['questions'] is List || item.containsKey('fk_section_id')) {
      documents.add(LmaQuestionDocument.fromJson(_withQuestionText(item)));
      continue;
    }
    final normalized = _withQuestionText(item);
    final parsed = LmaQuestionItem.fromJson(normalized);
    if (parsed.questionId <= 0) continue;
    final category =
        (item['category'] ?? item['section_name'] ?? item['section'] ?? '')
            .toString()
            .trim();
    flat.add(
      LeanMaturityQuestion(
        id: parsed.questionId,
        category: category.isNotEmpty
            ? category
            : categoryForQuestionId(parsed.questionId),
        text: parsed.question,
        levels: parsed.options,
      ),
    );
  }

  for (final sectionMap in _mapsOf(map, const ['sections'])) {
    final nested = sectionMap['questions'];
    if (nested is! List) continue;
    final sectionName =
        (sectionMap['section_name'] ?? sectionMap['category'] ?? '')
            .toString()
            .trim();
    for (final raw in nested.whereType<Map>()) {
      final item = _withQuestionText(Map<String, dynamic>.from(raw));
      final parsed = LmaQuestionItem.fromJson(item);
      if (parsed.questionId <= 0) continue;
      flat.add(
        LeanMaturityQuestion(
          id: parsed.questionId,
          category: sectionName.isNotEmpty
              ? sectionName
              : categoryForQuestionId(parsed.questionId),
          text: parsed.question,
          levels: parsed.options,
        ),
      );
    }
  }

  final questions = documents.isNotEmpty
      ? mapLmaQuestions(sections: sections, questionDocuments: documents)
      : dedupeQuestionsById(flat);

  final categories = <String>[];
  for (final section in sections) {
    if (section.sectionName.isEmpty) continue;
    if (questions.any((question) => question.category == section.sectionName) &&
        !categories.contains(section.sectionName)) {
      categories.add(section.sectionName);
    }
  }
  for (final question in questions) {
    if (question.category.isNotEmpty &&
        !categories.contains(question.category)) {
      categories.add(question.category);
    }
  }

  return PublicLmaFormConfig(questions: questions, categories: categories);
}

Map<String, dynamic> buildLmaRegistrationPayload({
  required String companyName,
  required String clientName,
  required String clientEmail,
  required String title,
  required String reportDate,
  required String companyIntroduction,
  required String location,
  required int? totalWorkforce,
  required String shiftOperation,
  required String workingHours,
  required String workingDays,
  required List<LeanMaturityQuestion> questions,
  required Map<int, int> scores,
}) {
  final responses = <Map<String, dynamic>>[];
  for (final question in questions) {
    final score = scores[question.id];
    if (score == null) continue;
    responses.add({
      'question_id': question.id,
      'score': score,
      'selected_response': levelDescription(question, score),
    });
  }

  final details = <String, dynamic>{
    'company_name': companyName.trim(),
    'client_name': clientName.trim(),
    'client_email': clientEmail.trim(),
    'company_introduction': companyIntroduction.trim(),
    'location': location.trim(),
    'shift_operation': shiftOperation.trim(),
    'working_hours': workingHours.trim(),
    'working_days': workingDays.trim(),
  };
  if (totalWorkforce != null) details['total_workforce'] = totalWorkforce;

  final resolvedTitle = title.trim().isEmpty
      ? '${companyName.trim()} Lean Maturity Assessment'
      : title.trim();

  return {
    'company_name': companyName.trim(),
    'client_name': clientName.trim(),
    'client_email': clientEmail.trim(),
    'title': resolvedTitle,
    'report_date': reportDate,
    'company_background': {'details': details},
    'assessment': {
      'details': {'responses': responses},
    },
  };
}

Map<String, dynamic> _withQuestionText(Map<String, dynamic> json) {
  final copy = Map<String, dynamic>.from(json);
  final question = (copy['question'] ?? '').toString().trim();
  if (question.isEmpty) {
    final text =
        (copy['question_text'] ?? copy['text'] ?? '').toString().trim();
    if (text.isNotEmpty) copy['question'] = text;
  }
  if (copy['options'] == null && copy['levels'] is List) {
    copy['options'] = copy['levels'];
  }
  final nested = copy['questions'];
  if (nested is List) {
    copy['questions'] = nested
        .map((item) => item is Map
            ? _withQuestionText(Map<String, dynamic>.from(item))
            : item)
        .toList();
  }
  return copy;
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return const {};
}

List<Map<String, dynamic>> _mapsOf(
    Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
  }
  return const [];
}
