import '../data/models/lma_config_models.dart';

const leanMaturityMarksPerQuestion = 5;
const lmaQuestionsPerCategory = 5;
const lmaTotalQuestions = 45;

/// Must stay aligned with backend `LMA_CATEGORIES` / `QUESTION_CATEGORY_MAP`.
const lmaCategories = [
  'Leadership & Strategy',
  'Customer Satisfaction & Delivery',
  'Quality Management',
  'Production Management',
  'Supply Chain & Inventory Management',
  'Maintenance Management',
  'Total Employee Involvement',
  'Cost Reduction Measures',
  'General',
];

const leanMaturityCategoryStepLabels = {
  'Leadership & Strategy': 'Leadership',
  'Customer Satisfaction & Delivery': 'Customer Delivery',
  'Quality Management': 'Quality',
  'Production Management': 'Production',
  'Supply Chain & Inventory Management': 'Supply Chain',
  'Maintenance Management': 'Maintenance',
  'Total Employee Involvement': 'Employee Involvement',
  'Cost Reduction Measures': 'Cost Reduction',
  'General': 'General',
};

const leanMaturityMaturityLevels = [
  (score: 0, label: 'No Voice'),
  (score: 1, label: 'Basic'),
  (score: 2, label: 'Beginner'),
  (score: 3, label: 'Intermediate'),
  (score: 4, label: 'Advanced'),
  (score: 5, label: 'Expert'),
];

String categoryForQuestionId(int questionId) {
  if (questionId < 1 || questionId > lmaTotalQuestions) {
    return '';
  }
  final index = (questionId - 1) ~/ lmaQuestionsPerCategory;
  if (index < 0 || index >= lmaCategories.length) {
    return '';
  }
  return lmaCategories[index];
}

String categoryStepLabel(String category) {
  return leanMaturityCategoryStepLabels[category] ?? category;
}

String leanMaturityQuestionKey(int questionId) => questionId.toString();

bool isAnsweredScore(Object? score) {
  return score != null && score != '';
}

List<LeanMaturityResponse> dedupeResponsesByQuestionId(
  List<LeanMaturityResponse> responses,
) {
  final byId = <int, LeanMaturityResponse>{};
  for (final response in responses) {
    byId[response.questionId] = response;
  }
  return byId.entries.map((entry) => entry.value).toList()
    ..sort((a, b) => a.questionId.compareTo(b.questionId));
}

List<LeanMaturityQuestion> dedupeQuestionsById(
  List<LeanMaturityQuestion> questions,
) {
  final byId = <int, LeanMaturityQuestion>{};
  for (final question in questions) {
    byId[question.id] = question;
  }
  return byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

int questionMaxScore(LeanMaturityQuestion question) {
  if (question.levels.isEmpty) {
    return leanMaturityMarksPerQuestion;
  }
  return question.levels.map((level) => level.score).reduce((a, b) => a > b ? a : b);
}

int questionsMaxScoreTotal(List<LeanMaturityQuestion> questions) {
  return questions.fold(0, (sum, question) => sum + questionMaxScore(question));
}

List<LeanMaturityQuestion> questionsByCategory(
  List<LeanMaturityQuestion> questions,
  String category,
) {
  return questions.where((question) => question.category == category).toList();
}

String levelDescription(LeanMaturityQuestion question, int? score) {
  if (score == null) return '';
  return question.levels
          .where((level) => level.score == score)
          .map((level) => level.description)
          .firstOrNull ??
      '';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
