import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/lma_config_repository.dart';
import '../data/models/lma_config_models.dart';
import '../domain/lean_maturity_data.dart';
import '../domain/lean_maturity_scoring.dart';
import '../domain/lma_question_mapper.dart';

enum LmaConfigStatus { idle, loading, loaded, error }

class LmaConfigState extends Equatable {
  const LmaConfigState({
    this.status = LmaConfigStatus.idle,
    this.sections = const [],
    this.grades = const [],
    this.questionDocuments = const [],
    this.questions = const [],
    this.gradingCriteria = const [],
    this.categories = const [],
    this.categoryMeta = const {},
    this.maxScore = 0,
    this.errorMessage,
  });

  final LmaConfigStatus status;
  final List<LmaSection> sections;
  final List<LmaGrade> grades;
  final List<LmaQuestionDocument> questionDocuments;
  final List<LeanMaturityQuestion> questions;
  final List<LmaGradingCriterion> gradingCriteria;
  final List<String> categories;
  final Map<String, CategoryScoreMeta> categoryMeta;
  final int maxScore;
  final String? errorMessage;

  bool get canCreateAssessment => status == LmaConfigStatus.loaded && questions.isNotEmpty;

  List<LeanMaturityQuestion> questionsForCategory(String category) {
    return questions.where((question) => question.category == category).toList();
  }

  LmaConfigState copyWith({
    LmaConfigStatus? status,
    List<LmaSection>? sections,
    List<LmaGrade>? grades,
    List<LmaQuestionDocument>? questionDocuments,
    List<LeanMaturityQuestion>? questions,
    List<LmaGradingCriterion>? gradingCriteria,
    List<String>? categories,
    Map<String, CategoryScoreMeta>? categoryMeta,
    int? maxScore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LmaConfigState(
      status: status ?? this.status,
      sections: sections ?? this.sections,
      grades: grades ?? this.grades,
      questionDocuments: questionDocuments ?? this.questionDocuments,
      questions: questions ?? this.questions,
      gradingCriteria: gradingCriteria ?? this.gradingCriteria,
      categories: categories ?? this.categories,
      categoryMeta: categoryMeta ?? this.categoryMeta,
      maxScore: maxScore ?? this.maxScore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  LeanMaturityScores calculateScores(List<LeanMaturityResponse>? responses) {
    return calculateLeanMaturityScores(
      responses: responses,
      questions: questions,
      gradingCriteria: gradingCriteria,
      fullMax: maxScore,
      categoryMeta: categoryMeta,
    );
  }

  @override
  List<Object?> get props => [
        status,
        sections,
        grades,
        questionDocuments,
        questions,
        gradingCriteria,
        categories,
        categoryMeta,
        maxScore,
        errorMessage,
      ];
}

class LmaConfigController extends StateNotifier<LmaConfigState> {
  LmaConfigController(this._ref) : super(const LmaConfigState());

  final Ref _ref;
  Future<bool>? _loadFuture;

  Future<bool> ensureLoaded({bool force = false}) {
    if (state.status == LmaConfigStatus.loaded && !force) {
      return Future.value(true);
    }
    if (_loadFuture != null && !force) {
      return _loadFuture!;
    }

    state = state.copyWith(status: LmaConfigStatus.loading, clearError: true);

    _loadFuture = _load().whenComplete(() {
      _loadFuture = null;
    });
    return _loadFuture!;
  }

  Future<bool> _load() async {
    try {
      final repo = _ref.read(lmaConfigRepositoryProvider);
      final bundle = await repo.loadAll();
      final questions = mapLmaQuestions(
        sections: bundle.sections,
        questionDocuments: bundle.questionDocuments,
      );
      final gradingCriteria = mapGradingCriteria(bundle.grades);
      final categoryMeta = buildCategoryMeta(
        sections: bundle.sections,
        questions: questions,
      );
      final categories = orderedCategories(
        sections: bundle.sections,
        questions: questions,
      );
      final maxScore = resolveOverallMaxScore(
        sections: bundle.sections,
        questions: questions,
      );

      if (questions.isEmpty) {
        state = LmaConfigState(
          status: LmaConfigStatus.error,
          sections: bundle.sections,
          grades: bundle.grades,
          questionDocuments: bundle.questionDocuments,
          gradingCriteria: gradingCriteria,
          categories: categories,
          categoryMeta: categoryMeta,
          maxScore: maxScore,
          errorMessage: 'No LMA questions configured. Contact your administrator.',
        );
        return false;
      }

      state = LmaConfigState(
        status: LmaConfigStatus.loaded,
        sections: bundle.sections,
        grades: bundle.grades,
        questionDocuments: bundle.questionDocuments,
        questions: questions,
        gradingCriteria: gradingCriteria,
        categories: categories,
        categoryMeta: categoryMeta,
        maxScore: maxScore,
      );
      return true;
    } on ApiException catch (e) {
      state = LmaConfigState(
        status: LmaConfigStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (_) {
      state = const LmaConfigState(
        status: LmaConfigStatus.error,
        errorMessage: 'Failed to load LMA configuration.',
      );
      return false;
    }
  }

  void invalidate() {
    _loadFuture = null;
    state = const LmaConfigState();
  }

  Future<bool> refreshAfterMutation() {
    invalidate();
    return ensureLoaded(force: true);
  }

  List<LeanMaturityQuestion> questionsForCategory(String category) {
    return questionsByCategory(state.questions, category);
  }
}

final lmaConfigControllerProvider =
    StateNotifierProvider<LmaConfigController, LmaConfigState>((ref) {
  return LmaConfigController(ref);
});
