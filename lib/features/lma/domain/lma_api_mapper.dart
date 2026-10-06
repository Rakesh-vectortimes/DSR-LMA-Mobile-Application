import 'package:intl/intl.dart';

import '../../../../core/constants/report_status.dart';
import '../../../../core/network/list_response.dart';
import '../../companies/data/models/company.dart';
import '../data/models/lma_assessment_models.dart';
import '../data/models/lma_config_models.dart';
import 'lean_maturity_data.dart';

Map<String, dynamic>? sectionDetails(Object? section) {
  if (section is Map<String, dynamic>) {
    final details = section['details'];
    if (details is Map<String, dynamic>) return details;
    if (details is Map) return Map<String, dynamic>.from(details);
    return section;
  }
  if (section is Map) {
    final map = Map<String, dynamic>.from(section);
    final details = map['details'];
    if (details is Map<String, dynamic>) return details;
    if (details is Map) return Map<String, dynamic>.from(details);
    return map;
  }
  return null;
}

String lmaStatusLabel(Object? apiStatus, {String? statusLabel}) {
  return ReportStatus.labelOf(apiStatus, statusLabel: statusLabel);
}

String formatApiDate(Object? value) {
  if (value == null || value == '') {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
  if (value is DateTime) {
    return DateFormat('yyyy-MM-dd').format(value);
  }
  return value.toString().split('T').first;
}

List<LeanMaturityResponse> extractLmaResponses(Map<String, dynamic> raw) {
  final assessment = raw['assessment'];
  Map<String, dynamic>? assessmentMap;
  if (assessment is Map<String, dynamic>) {
    assessmentMap = assessment;
  } else if (assessment is Map) {
    assessmentMap = Map<String, dynamic>.from(assessment);
  }
  if (assessmentMap == null) return const [];

  final direct = assessmentMap['responses'];
  if (direct is List) {
    return _normalizeResponses(direct);
  }

  final details = sectionDetails(assessmentMap);
  final nested = details?['responses'];
  if (nested is List) {
    return _normalizeResponses(nested);
  }

  return const [];
}

List<LeanMaturityResponse> _normalizeResponses(List<dynamic> items) {
  final responses = <LeanMaturityResponse>[];
  for (final item in items) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final questionId = _asInt(map['question_id']);
    if (questionId == null) continue;
    responses.add(
      LeanMaturityResponse(
        questionId: questionId,
        category: map['category']?.toString() ?? '',
        score: _asInt(map['score']),
        question: map['question']?.toString(),
        selectedResponse:
            map['selected_response']?.toString() ?? map['response_text']?.toString(),
      ),
    );
  }
  return dedupeResponsesByQuestionId(responses);
}

List<LeanMaturityResponse> enrichLmaResponses(
  List<LeanMaturityResponse> responses,
  List<LeanMaturityQuestion> questions,
) {
  final questionsById = {
    for (final question in questions) question.id: question,
  };
  final enriched = <LeanMaturityResponse>[];

  for (final response in dedupeResponsesByQuestionId(responses)) {
    final question = questionsById[response.questionId];
    final category = question?.category.isNotEmpty == true
        ? question!.category
        : response.category;
    if (category.isEmpty) continue;

    enriched.add(
      LeanMaturityResponse(
        questionId: response.questionId,
        category: category,
        score: response.score,
        question: response.question ?? question?.text,
        selectedResponse: response.selectedResponse ??
            levelDescription(question ?? LeanMaturityQuestion(id: response.questionId, category: category, text: '', levels: const []), response.score),
      ),
    );
  }

  return enriched;
}

Map<String, dynamic> buildLmaApiPayload({
  required CompanyFormValues company,
  required List<LeanMaturityResponse> responses,
  required List<LeanMaturityQuestion> questions,
  required Object? status,
  required Object? reportDate,
}) {
  final companyName = company.companyName.trim().isEmpty
      ? 'Lean Maturity Assessment'
      : company.companyName.trim();
  final enrichedResponses = enrichLmaResponses(responses, questions);

  return {
    'company_id': company.companyId,
    'title': '$companyName Lean Maturity Assessment',
    'company_name': companyName,
    'report_date': formatApiDate(reportDate),
    'status': ReportStatus.toApi(status),
    'company_background': {
      'details': {
        'company_id': company.companyId,
        'company_name': companyName,
        'company_introduction': company.companyIntroduction,
        'location': company.location,
        'total_workforce': apiTotalWorkforce(company.totalWorkforce),
        'shift_operation': company.shiftOperation,
        'working_hours': company.workingHours,
        'working_days': company.workingDays,
        'currency': company.currency,
        'currency_symbol': company.currencySymbol,
      },
    },
    'assessment': {
      'details': {
        'responses': enrichedResponses
            .map(
              (response) => {
                'question_id': response.questionId,
                'category': response.category,
                'score': response.score,
                'question': response.question ?? '',
                'selected_response': response.selectedResponse ?? '',
              },
            )
            .toList(),
      },
    },
  };
}

LeanMaturityAssessmentRecord normalizeLmaRecord(
  Map<String, dynamic> raw, {
  LeanMaturityScores? scores,
}) {
  final companyBackground = sectionDetails(raw['company_background']);
  final responses = extractLmaResponses(raw);

  final createdByName = _normalizeDisplayUser(raw['created_by_name']);
  final preparedBy = createdByName ??
      _normalizeDisplayUser(raw['prepared_by']) ??
      _normalizeDisplayUser(raw['created_by']);
  final updatedBy = _normalizeDisplayUser(raw['updated_by_name']) ??
      _normalizeDisplayUser(raw['updated_by']) ??
      _normalizeDisplayUser(raw['updatedBy']) ??
      _normalizeDisplayUser(raw['updated_by_user']);

  return LeanMaturityAssessmentRecord(
    id: normalizeEntityId(raw['id'] ?? raw['assessment_id'] ?? raw['_id']) ?? '',
    companyId: normalizeEntityId(
      raw['company_id'] ??
          companyBackground?['company_id'] ??
          raw['fk_company_id'],
    ),
    companyName: raw['company_name']?.toString() ??
        companyBackground?['company_name']?.toString() ??
        _titleToCompanyName(raw['title']?.toString()),
    title: raw['title']?.toString(),
    reportDate: formatApiDate(raw['report_date']),
    preparedBy: preparedBy,
    createdByName: createdByName,
    updatedBy: updatedBy,
    updatedByName: updatedBy,
    createdByRole: raw['created_by_role']?.toString() ??
        raw['creator_role']?.toString() ??
        _extractRoleFromObject(raw['created_by']),
    status: ReportStatus.parse(raw['status']),
    statusLabel: ReportStatus.labelFromJson(raw),
    companyBackground: companyBackground == null
        ? null
        : LmaCompanyBackground.fromJson(companyBackground),
    responses: responses,
    scores: scores,
    createdAt: raw['created_at']?.toString() ?? raw['created_on']?.toString(),
    updatedAt: raw['updated_at']?.toString() ?? raw['updated_on']?.toString(),
    raw: raw,
  );
}

Map<String, dynamic> lmaRecordToFormPatch(LeanMaturityAssessmentRecord record) {
  final companyBackground = record.companyBackground;
  return {
    'company_id': record.companyId ?? companyBackground?.companyId,
    'company_name': record.companyName ?? companyBackground?.companyName ?? '',
    'company_introduction': companyBackground?.companyIntroduction ?? '',
    'location': companyBackground?.location ?? '',
    'total_workforce': companyBackground?.totalWorkforce,
    'shift_operation': companyBackground?.shiftOperation,
    'working_hours': companyBackground?.workingHours ?? '',
    'working_days': companyBackground?.workingDays,
    'currency': companyBackground?.currency ?? 'INR',
    'currency_symbol': companyBackground?.currencySymbol,
    'report_date': record.reportDate,
    'status': ReportStatus.parse(record.status),
    'responses': record.responses,
  };
}

String? _normalizeDisplayUser(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(trimmed)) return null;
    return trimmed;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    return _normalizeDisplayUser(
      map['name'] ?? map['full_name'] ?? map['email'] ?? map['value'],
    );
  }
  return null;
}

String? _extractRoleFromObject(Object? value) {
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    return map['role']?.toString();
  }
  return null;
}

String _titleToCompanyName(String? title) {
  final value = (title ?? '').trim();
  return value.replaceFirst(RegExp(r' Lean Maturity Assessment$', caseSensitive: false), '');
}

int? _asInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
