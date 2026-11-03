import 'package:equatable/equatable.dart';

import '../../../../core/network/list_response.dart';
import '../../../lma/data/models/lma_config_models.dart';

/// Waiting for approval, Approved, Rejected. Reject is display-only.
abstract final class LmaRegistrationStatus {
  static const int waiting = 1;
  static const int approved = 2;
  static const int rejected = 3;

  static const Map<int, String> labels = {
    waiting: 'Waiting for approval',
    approved: 'Approved',
    rejected: 'Rejected',
  };

  static String labelOf(Object? value, {String? statusLabel}) {
    final fromApi = statusLabel?.trim() ?? '';
    if (fromApi.isNotEmpty) return fromApi;
    return labels[_asInt(value)] ?? 'Unknown';
  }
}

class PublicLmaFormConfig extends Equatable {
  const PublicLmaFormConfig({
    required this.questions,
    required this.categories,
  });

  final List<LeanMaturityQuestion> questions;
  final List<String> categories;

  List<LeanMaturityQuestion> questionsFor(String category) {
    return questions
        .where((question) => question.category == category)
        .toList();
  }

  @override
  List<Object?> get props => [questions, categories];
}

class LmaQrCode extends Equatable {
  const LmaQrCode({
    required this.id,
    required this.url,
    required this.image,
    required this.active,
  });

  final String id;
  final String url;
  final String image;
  final bool active;

  factory LmaQrCode.fromJson(Map<String, dynamic> json) {
    final activeRaw = json['active'] ?? json['is_active'] ?? json['is_current'];
    return LmaQrCode(
      id: ListResponse.extractId(json),
      url: (json['url'] ?? json['qr_url'] ?? '').toString().trim(),
      image: (json['image'] ?? json['image_url'] ?? '').toString().trim(),
      active: activeRaw == true ||
          activeRaw == 1 ||
          activeRaw == 'true' ||
          activeRaw == '1',
    );
  }

  @override
  List<Object?> get props => [id, url, image, active];
}

class LmaQrSettings extends Equatable {
  const LmaQrSettings({this.current, this.items = const []});

  final LmaQrCode? current;
  final List<LmaQrCode> items;

  factory LmaQrSettings.fromJson(dynamic data) {
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    final currentRaw = map['current'];
    final itemsRaw = map['items'] ?? map['history'] ?? map['results'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((item) => LmaQrCode.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <LmaQrCode>[];
    LmaQrCode? current;
    if (currentRaw is Map) {
      current = LmaQrCode.fromJson(Map<String, dynamic>.from(currentRaw));
    } else {
      for (final item in items) {
        if (item.active) {
          current = item;
          break;
        }
      }
    }
    return LmaQrSettings(current: current, items: items);
  }

  @override
  List<Object?> get props => [current, items];
}

class LmaRegistrationSummary extends Equatable {
  const LmaRegistrationSummary({
    required this.id,
    required this.companyName,
    required this.clientName,
    required this.clientEmail,
    required this.status,
    required this.statusLabel,
    this.createdOn,
    this.assessmentId,
    this.companyId,
  });

  final String id;
  final String companyName;
  final String clientName;
  final String clientEmail;
  final int status;
  final String statusLabel;
  final String? createdOn;
  final String? assessmentId;
  final String? companyId;

  bool get canApprove => status == LmaRegistrationStatus.waiting;

  factory LmaRegistrationSummary.fromJson(Map<String, dynamic> json) {
    final status = _asInt(json['status']) ?? LmaRegistrationStatus.waiting;
    return LmaRegistrationSummary(
      id: ListResponse.extractId(json,
          preferredKeys: const ['registration_id']),
      companyName: (json['company_name'] ?? '').toString().trim(),
      clientName: (json['client_name'] ?? json['name'] ?? '').toString().trim(),
      clientEmail:
          (json['client_email'] ?? json['email'] ?? '').toString().trim(),
      status: status,
      statusLabel: LmaRegistrationStatus.labelOf(
        status,
        statusLabel: json['status_label']?.toString(),
      ),
      createdOn: (json['created_on'] ?? json['created_at'])?.toString(),
      assessmentId: normalizeEntityId(json['assessment_id']),
      companyId: normalizeEntityId(json['company_id']),
    );
  }

  @override
  List<Object?> get props =>
      [id, companyName, clientEmail, status, statusLabel];
}

class LmaRegistrationAnswer extends Equatable {
  const LmaRegistrationAnswer({
    required this.questionId,
    required this.score,
    this.question = '',
    this.selectedResponse = '',
  });

  final int questionId;
  final int score;
  final String question;
  final String selectedResponse;

  factory LmaRegistrationAnswer.fromJson(Map<String, dynamic> json) {
    return LmaRegistrationAnswer(
      questionId: _asInt(json['question_id']) ?? 0,
      score: _asInt(json['score']) ?? 0,
      question:
          (json['question'] ?? json['question_text'] ?? '').toString().trim(),
      selectedResponse: (json['selected_response'] ?? json['description'] ?? '')
          .toString()
          .trim(),
    );
  }

  @override
  List<Object?> get props => [questionId, score, question, selectedResponse];
}

class LmaRegistrationDetail extends Equatable {
  const LmaRegistrationDetail({
    required this.summary,
    this.title = '',
    this.reportDate = '',
    this.companyIntroduction = '',
    this.location = '',
    this.totalWorkforce,
    this.shiftOperation = '',
    this.workingHours = '',
    this.workingDays = '',
    this.answers = const [],
  });

  final LmaRegistrationSummary summary;
  final String title;
  final String reportDate;
  final String companyIntroduction;
  final String location;
  final int? totalWorkforce;
  final String shiftOperation;
  final String workingHours;
  final String workingDays;
  final List<LmaRegistrationAnswer> answers;

  factory LmaRegistrationDetail.fromJson(Map<String, dynamic> json) {
    final background = _nestedDetails(json['company_background']) ??
        _asStringMap(json['company_background']) ??
        const <String, dynamic>{};
    final assessment =
        _nestedDetails(json['assessment']) ?? const <String, dynamic>{};
    final responsesRaw = assessment['responses'] ?? json['responses'];
    final answers = responsesRaw is List
        ? responsesRaw
            .whereType<Map>()
            .map((item) =>
                LmaRegistrationAnswer.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.questionId > 0)
            .toList()
        : <LmaRegistrationAnswer>[];

    return LmaRegistrationDetail(
      summary: LmaRegistrationSummary.fromJson({
        ...json,
        'company_name':
            _firstText(json['company_name'], background['company_name']),
        'client_name': _firstText(
            json['client_name'], background['client_name'], json['name']),
        'client_email': _firstText(
          json['client_email'],
          background['client_email'],
          json['email'],
        ),
      }),
      title: (json['title'] ?? '').toString().trim(),
      reportDate:
          (json['report_date'] ?? background['report_date'] ?? '').toString(),
      companyIntroduction: (background['company_introduction'] ??
              json['company_introduction'] ??
              '')
          .toString(),
      location: (background['location'] ?? json['location'] ?? '').toString(),
      totalWorkforce:
          _asInt(background['total_workforce'] ?? json['total_workforce']),
      shiftOperation: (background['shift_operation'] ?? '').toString(),
      workingHours: (background['working_hours'] ?? '').toString(),
      workingDays: (background['working_days'] ?? '').toString(),
      answers: answers,
    );
  }

  @override
  List<Object?> get props => [summary, title, answers];
}

class LmaRegistrationSubmitResult extends Equatable {
  const LmaRegistrationSubmitResult({
    required this.id,
    required this.emailSent,
    this.emailError,
    this.message = '',
  });

  final String id;
  final bool emailSent;
  final String? emailError;
  final String message;

  factory LmaRegistrationSubmitResult.fromEnvelope({
    required String message,
    required dynamic data,
  }) {
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    final sent = map['email_sent'];
    return LmaRegistrationSubmitResult(
      id: ListResponse.extractId(map, preferredKeys: const ['registration_id']),
      emailSent: sent == true || sent == 1 || sent == 'true',
      emailError: map['email_error']?.toString(),
      message: message,
    );
  }

  @override
  List<Object?> get props => [id, emailSent, emailError, message];
}

Map<String, dynamic>? _nestedDetails(dynamic value) {
  final map = _asStringMap(value);
  if (map == null) return null;
  final details = map['details'];
  if (details is Map) return Map<String, dynamic>.from(details);
  return map;
}

Map<String, dynamic>? _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _firstText(Object? first, Object? second, [Object? third]) {
  for (final value in [first, second, third]) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
