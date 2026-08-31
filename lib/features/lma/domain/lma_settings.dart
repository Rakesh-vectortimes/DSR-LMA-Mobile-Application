import '../data/models/lma_config_models.dart';

Map<String, dynamic> buildSectionCreatePayload({
  required String sectionName,
  required int sectionOrder,
}) {
  return {
    'section_name': sectionName.trim(),
    'no_of_questions': 0,
    'total_marks': 0,
    'section_order': sectionOrder,
    'status': 1,
  };
}

Map<String, dynamic> buildSectionUpdatePayload({
  required String sectionName,
  required int sectionOrder,
}) {
  return {
    'section_name': sectionName.trim(),
    'section_order': sectionOrder,
  };
}

Map<String, dynamic> buildGradePayload({
  required String gradingCriteria,
  required int minScore,
  required int maxScore,
  required int percentage,
  required int gradeOrder,
}) {
  return {
    'grading_criteria': gradingCriteria.trim(),
    'score': '$minScore-$maxScore',
    'min_score': minScore,
    'max_score': maxScore,
    'percentage': percentage,
    'grade_order': gradeOrder,
    'status': 1,
  };
}

Map<String, dynamic> buildQuestionDocumentPayload({
  required String fkSectionId,
  required List<LmaQuestionItem> questions,
}) {
  final cleaned = questions.map((question) {
    final options = [...question.options]
      ..sort((a, b) => a.score.compareTo(b.score));
    return {
      'question_id': question.questionId,
      'question': question.question.trim(),
      'options': [
        for (final option in options)
          {
            'score': option.score,
            'description': option.description.trim(),
          },
      ],
    };
  }).toList();

  return {
    'fk_section_id': fkSectionId,
    'questions': cleaned,
    'status': 1,
  };
}

class SectionFormErrors {
  const SectionFormErrors({this.sectionName = '', this.sectionOrder = ''});

  final String sectionName;
  final String sectionOrder;

  bool get hasError => sectionName.isNotEmpty || sectionOrder.isNotEmpty;
}

SectionFormErrors validateSectionForm({
  required String sectionName,
  required int? sectionOrder,
  required List<LmaSection> others,
}) {
  var nameError = '';
  var orderError = '';
  final name = sectionName.trim();

  if (name.isEmpty) {
    nameError = 'Section name is required.';
  } else if (others.any(
    (section) => section.sectionName.trim().toLowerCase() == name.toLowerCase(),
  )) {
    nameError = 'Section name already exists';
  }

  if (sectionOrder == null) {
    orderError = 'Order is required.';
  } else if (sectionOrder < 1) {
    orderError = 'Order must be at least 1.';
  } else if (others.any((section) => (section.sectionOrder ?? 0) == sectionOrder)) {
    orderError = 'Order already exists';
  }

  return SectionFormErrors(sectionName: nameError, sectionOrder: orderError);
}

class GradeFormErrors {
  const GradeFormErrors({
    this.gradingCriteria = '',
    this.minScore = '',
    this.maxScore = '',
    this.gradeOrder = '',
    this.percentage = '',
  });

  final String gradingCriteria;
  final String minScore;
  final String maxScore;
  final String gradeOrder;
  final String percentage;

  bool get hasError =>
      gradingCriteria.isNotEmpty ||
      minScore.isNotEmpty ||
      maxScore.isNotEmpty ||
      gradeOrder.isNotEmpty ||
      percentage.isNotEmpty;
}

int gradeOverallMaxScore({
  required int configMax,
  required List<LmaGrade> grades,
}) {
  if (configMax > 0) return configMax;
  final gradesMax = grades.fold<int>(
    0,
    (max, grade) => grade.maxScore > max ? grade.maxScore : max,
  );
  return gradesMax > 0 ? gradesMax : 1;
}

int gradePercentageFromMax({required int maxScore, required int overall}) {
  if (maxScore < 0 || overall <= 0) return 0;
  return ((maxScore / overall) * 100).round();
}

bool _rangesOverlap(int minA, int maxA, int minB, int maxB) {
  return minA <= maxB && minB <= maxA;
}

GradeFormErrors validateGradeForm({
  required String gradingCriteria,
  required int? minScore,
  required int? maxScore,
  required int? gradeOrder,
  required int percentage,
  required List<LmaGrade> others,
}) {
  var criteriaError = '';
  var minError = '';
  var maxError = '';
  var orderError = '';
  var percentageError = '';
  final criteria = gradingCriteria.trim();

  if (criteria.isEmpty) {
    criteriaError = 'Grading criteria is required.';
  } else if (others.any(
    (grade) => grade.gradingCriteria.trim().toLowerCase() == criteria.toLowerCase(),
  )) {
    criteriaError = 'Grading criteria already exists';
  }

  if (gradeOrder == null) {
    orderError = 'Order is required.';
  } else if (gradeOrder < 1) {
    orderError = 'Order must be at least 1.';
  } else if (others.any((grade) => (grade.gradeOrder ?? 0) == gradeOrder)) {
    orderError = 'Order already exists';
  }

  if (minScore == null) {
    minError = 'Min score is required.';
  }
  if (maxScore == null) {
    maxError = 'Max score is required.';
  } else if (minScore != null && maxScore <= minScore) {
    maxError = 'Max score must be greater than min score.';
  } else if (minScore != null) {
    final conflict = others.cast<LmaGrade?>().firstWhere(
          (grade) => _rangesOverlap(
            minScore,
            maxScore,
            grade!.minScore,
            grade.maxScore,
          ),
          orElse: () => null,
        );
    if (conflict != null) {
      final existRange =
          conflict.score.isNotEmpty ? conflict.score : '${conflict.minScore}-${conflict.maxScore}';
      final minInside = minScore >= conflict.minScore && minScore <= conflict.maxScore;
      final maxInside = maxScore >= conflict.minScore && maxScore <= conflict.maxScore;
      if (minInside) {
        minError = 'Min score overlaps with existing range $existRange';
      }
      if (maxInside) {
        maxError = 'Max score overlaps with existing range $existRange';
      }
      if (minError.isEmpty && maxError.isEmpty) {
        maxError = 'Score range overlaps with existing range $existRange';
      }
    }
  }

  if (percentage < 0 || percentage > 100) {
    percentageError = 'Percentage must be between 0 and 100.';
  } else if (others.any((grade) => grade.percentage == percentage)) {
    percentageError = 'Percentage already exists';
  }

  return GradeFormErrors(
    gradingCriteria: criteriaError,
    minScore: minError,
    maxScore: maxError,
    gradeOrder: orderError,
    percentage: percentageError,
  );
}

class QuestionFormErrors {
  const QuestionFormErrors({
    this.section = '',
    this.questions = '',
    this.fields = const {},
  });

  final String section;
  final String questions;
  final Map<String, String> fields;

  bool get hasError =>
      section.isNotEmpty || questions.isNotEmpty || fields.isNotEmpty;

  String field(String key) => fields[key] ?? '';
}

QuestionFormErrors validateQuestionForm({
  required String fkSectionId,
  required List<LmaQuestionItem> questions,
}) {
  final fields = <String, String>{};
  var sectionError = '';
  var questionsError = '';

  if (fkSectionId.trim().isEmpty) {
    sectionError = 'Section is required.';
  }
  if (questions.isEmpty) {
    questionsError = 'Add at least one question.';
  }

  for (var qi = 0; qi < questions.length; qi++) {
    final question = questions[qi];
    if (question.question.trim().isEmpty) {
      fields['q-$qi-text'] = 'Question is required.';
    }

    final seenScores = <int, int>{};
    for (var oi = 0; oi < question.options.length; oi++) {
      final option = question.options[oi];
      if (option.description.trim().isEmpty) {
        fields['q-$qi-opt-$oi'] = 'Option description is required.';
      }
      if (seenScores.containsKey(option.score)) {
        fields['q-$qi-opt-$oi-score'] =
            'Score must be unique within this question.';
        fields['q-$qi-opt-${seenScores[option.score]}-score'] =
            'Score must be unique within this question.';
      } else {
        seenScores[option.score] = oi;
      }
    }
  }

  return QuestionFormErrors(
    section: sectionError,
    questions: questionsError,
    fields: fields,
  );
}

List<LmaQuestionOption> defaultQuestionOptions() {
  return List.generate(
    6,
    (index) => LmaQuestionOption(score: index, description: ''),
  );
}

LmaQuestionItem emptyQuestionItem({int questionId = 0}) {
  return LmaQuestionItem(
    questionId: questionId,
    question: '',
    options: defaultQuestionOptions(),
  );
}

/// Sequential IDs by section_order, matching backend `_renumber_all_question_ids`.
Map<String, List<int>> previewQuestionIds({
  required List<LmaSection> sections,
  required List<LmaQuestionDocument> documents,
  required String draftSectionId,
  required int draftQuestionCount,
}) {
  final docBySection = {
    for (final document in documents) document.fkSectionId: document,
  };
  final idsBySection = <String, List<int>>{};
  var nextId = 1;
  final ordered = [...sections]
    ..sort((a, b) => (a.sectionOrder ?? 0).compareTo(b.sectionOrder ?? 0));

  for (final section in ordered) {
    final count = section.id == draftSectionId
        ? draftQuestionCount
        : (docBySection[section.id]?.questions.length ?? 0);
    idsBySection[section.id] = List.generate(count, (index) {
      final id = nextId;
      nextId += 1;
      return id;
    });
  }
  return idsBySection;
}

List<LmaQuestionItem> applyQuestionIdPreview(
  List<LmaQuestionItem> questions,
  List<int> previewIds,
) {
  return [
    for (var i = 0; i < questions.length; i++)
      questions[i].copyWith(
        questionId: i < previewIds.length ? previewIds[i] : questions[i].questionId,
      ),
  ];
}

String applyServerFieldHint(String message, String field) {
  final normalized = message.toLowerCase();
  switch (field) {
    case 'section_name':
      return normalized.contains('section name already exists')
          ? 'Section name already exists'
          : '';
    case 'section_order':
      return normalized.contains('order already exists') ? 'Order already exists' : '';
    case 'grading_criteria':
      return normalized.contains('grading criteria already exists')
          ? 'Grading criteria already exists'
          : '';
    case 'grade_order':
      return normalized.contains('order already exists') ? 'Order already exists' : '';
    case 'percentage':
      return normalized.contains('percentage already exists')
          ? 'Percentage already exists'
          : '';
    default:
      return '';
  }
}
