import 'package:equatable/equatable.dart';

import '../../../../core/network/list_response.dart';

class LmaSection extends Equatable {
  const LmaSection({
    required this.id,
    required this.sectionName,
    required this.noOfQuestions,
    required this.totalMarks,
    this.sectionOrder,
    this.status,
  });

  final String id;
  final String sectionName;
  final int noOfQuestions;
  final int totalMarks;
  final int? sectionOrder;
  final int? status;

  factory LmaSection.fromJson(Map<String, dynamic> json) {
    return LmaSection(
      id: ListResponse.extractId(json),
      sectionName: (json['section_name'] as String?)?.trim() ?? '',
      noOfQuestions: _asInt(json['no_of_questions']) ?? 0,
      totalMarks: _asInt(json['total_marks']) ?? 0,
      sectionOrder: _asInt(json['section_order']),
      status: _asInt(json['status']),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [id, sectionName, sectionOrder, status];
}

class LmaGrade extends Equatable {
  const LmaGrade({
    required this.id,
    required this.gradingCriteria,
    required this.score,
    required this.minScore,
    required this.maxScore,
    required this.percentage,
    this.gradeOrder,
    this.status,
  });

  final String id;
  final String gradingCriteria;
  final String score;
  final int minScore;
  final int maxScore;
  final int percentage;
  final int? gradeOrder;
  final int? status;

  factory LmaGrade.fromJson(Map<String, dynamic> json) {
    return LmaGrade(
      id: ListResponse.extractId(json),
      gradingCriteria: (json['grading_criteria'] as String?)?.trim() ?? '',
      score: (json['score'] as String?)?.trim() ?? '',
      minScore: LmaSection._asInt(json['min_score']) ?? 0,
      maxScore: LmaSection._asInt(json['max_score']) ?? 0,
      percentage: LmaSection._asInt(json['percentage']) ?? 0,
      gradeOrder: LmaSection._asInt(json['grade_order']),
      status: LmaSection._asInt(json['status']),
    );
  }

  @override
  List<Object?> get props =>
      [id, gradingCriteria, score, minScore, maxScore, percentage, gradeOrder, status];
}

class LmaQuestionOption extends Equatable {
  const LmaQuestionOption({
    required this.score,
    required this.description,
  });

  final int score;
  final String description;

  factory LmaQuestionOption.fromJson(Map<String, dynamic> json) {
    return LmaQuestionOption(
      score: LmaSection._asInt(json['score']) ?? 0,
      description: (json['description'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'description': description,
      };

  LmaQuestionOption copyWith({int? score, String? description}) {
    return LmaQuestionOption(
      score: score ?? this.score,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [score, description];
}

class LmaQuestionItem extends Equatable {
  const LmaQuestionItem({
    required this.questionId,
    required this.question,
    required this.options,
    this.id,
  });

  final int questionId;
  final String question;
  final List<LmaQuestionOption> options;
  final String? id;

  factory LmaQuestionItem.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];
    final options = optionsRaw is List
        ? optionsRaw
            .whereType<Map>()
            .map((item) => LmaQuestionOption.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <LmaQuestionOption>[];

    return LmaQuestionItem(
      id: normalizeEntityId(json['id'] ?? json['_id']),
      questionId: LmaSection._asInt(json['question_id']) ?? 0,
      question: (json['question'] as String?)?.trim() ?? '',
      options: options,
    );
  }

  Map<String, dynamic> toPayload() => {
        'question_id': questionId,
        'question': question,
        'options': options.map((option) => option.toJson()).toList(),
      };

  LmaQuestionItem copyWith({
    int? questionId,
    String? question,
    List<LmaQuestionOption>? options,
    String? id,
  }) {
    return LmaQuestionItem(
      questionId: questionId ?? this.questionId,
      question: question ?? this.question,
      options: options ?? this.options,
      id: id ?? this.id,
    );
  }

  @override
  List<Object?> get props => [questionId, question, options];
}

class LmaQuestionDocument extends Equatable {
  const LmaQuestionDocument({
    required this.id,
    required this.fkSectionId,
    required this.questions,
    this.status,
  });

  final String id;
  final String fkSectionId;
  final List<LmaQuestionItem> questions;
  final int? status;

  factory LmaQuestionDocument.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'];
    final questions = questionsRaw is List
        ? questionsRaw
            .whereType<Map>()
            .map((item) => LmaQuestionItem.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <LmaQuestionItem>[];

    if (questions.isEmpty &&
        json['question_id'] != null &&
        (json['question'] != null || json['question_text'] != null)) {
      questions.add(LmaQuestionItem.fromJson(json));
    }

    return LmaQuestionDocument(
      id: ListResponse.extractId(json),
      fkSectionId: normalizeEntityId(json['fk_section_id']) ?? '',
      questions: questions,
      status: LmaSection._asInt(json['status']),
    );
  }

  @override
  List<Object?> get props => [id, fkSectionId, questions, status];
}

class LeanMaturityQuestion extends Equatable {
  const LeanMaturityQuestion({
    required this.id,
    required this.category,
    required this.text,
    required this.levels,
  });

  final int id;
  final String category;
  final String text;
  final List<LmaQuestionOption> levels;

  @override
  List<Object?> get props => [id, category, text];
}

class LeanMaturityResponse extends Equatable {
  const LeanMaturityResponse({
    required this.questionId,
    required this.category,
    this.score,
    this.question,
    this.selectedResponse,
  });

  final int questionId;
  final String category;
  final int? score;
  final String? question;
  final String? selectedResponse;

  @override
  List<Object?> get props => [questionId, category, score];
}

class LeanMaturityCategoryScore extends Equatable {
  const LeanMaturityCategoryScore({
    required this.category,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.grade,
    required this.answeredCount,
    required this.totalCount,
  });

  final String category;
  final int totalScore;
  final int maxScore;
  final int percentage;
  final String grade;
  final int answeredCount;
  final int totalCount;

  @override
  List<Object?> get props => [category, totalScore, maxScore, grade];
}

class LeanMaturityScores extends Equatable {
  const LeanMaturityScores({
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.grade,
    required this.answeredCount,
    required this.totalCount,
    required this.categoryScores,
  });

  final int totalScore;
  final int maxScore;
  final int percentage;
  final String grade;
  final int answeredCount;
  final int totalCount;
  final List<LeanMaturityCategoryScore> categoryScores;

  @override
  List<Object?> get props => [totalScore, maxScore, percentage, grade];
}

class LmaGradingCriterion {
  const LmaGradingCriterion({
    required this.grade,
    required this.minScore,
    required this.maxScore,
    required this.percentage,
  });

  final String grade;
  final int minScore;
  final int maxScore;
  final int percentage;
}

class CategoryScoreMeta {
  const CategoryScoreMeta({
    required this.maxScore,
    required this.totalCount,
  });

  final int maxScore;
  final int totalCount;
}
