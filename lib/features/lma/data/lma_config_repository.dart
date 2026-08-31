import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_get_helper.dart';
import '../../../core/network/dio_client.dart';
import 'models/lma_config_models.dart';

class LmaSectionRepository with ApiGetHelper {
  LmaSectionRepository(this.dio);

  @override
  final Dio dio;

  Future<List<LmaSection>> list({String? search}) {
    return getList(
      '/sections',
      queryParameters: {'search': search},
      fromJson: LmaSection.fromJson,
      nestedKeys: const ['items', 'results', 'data', 'sections'],
      fallbackMessage: 'Failed to load LMA sections',
    );
  }

  Future<LmaSection> getById(String id) {
    return getObject(
      '/sections/$id',
      fromJson: LmaSection.fromJson,
      fallbackMessage: 'Failed to load section',
    );
  }

  Future<LmaSection> create(Map<String, dynamic> payload) {
    return postObject(
      '/sections',
      data: payload,
      fromJson: LmaSection.fromJson,
      fallbackMessage: 'Failed to create section',
    );
  }

  Future<LmaSection> update(String id, Map<String, dynamic> payload) {
    return putObject(
      '/sections/$id',
      data: payload,
      fromJson: LmaSection.fromJson,
      fallbackMessage: 'Failed to update section',
    );
  }

  Future<void> delete(String id) {
    return deleteObject(
      '/sections/$id',
      fallbackMessage: 'Failed to delete section',
    );
  }
}

class LmaGradeRepository with ApiGetHelper {
  LmaGradeRepository(this.dio);

  @override
  final Dio dio;

  Future<List<LmaGrade>> list({String? search}) {
    return getList(
      '/grades',
      queryParameters: {'search': search},
      fromJson: LmaGrade.fromJson,
      nestedKeys: const ['items', 'results', 'data', 'grades'],
      fallbackMessage: 'Failed to load LMA grades',
    );
  }

  Future<LmaGrade> getById(String id) {
    return getObject(
      '/grades/$id',
      fromJson: LmaGrade.fromJson,
      fallbackMessage: 'Failed to load grade',
    );
  }

  Future<LmaGrade> create(Map<String, dynamic> payload) {
    return postObject(
      '/grades',
      data: payload,
      fromJson: LmaGrade.fromJson,
      fallbackMessage: 'Failed to create grade',
    );
  }

  Future<LmaGrade> update(String id, Map<String, dynamic> payload) {
    return putObject(
      '/grades/$id',
      data: payload,
      fromJson: LmaGrade.fromJson,
      fallbackMessage: 'Failed to update grade',
    );
  }

  Future<void> delete(String id) {
    return deleteObject(
      '/grades/$id',
      fallbackMessage: 'Failed to delete grade',
    );
  }
}

class LmaQuestionRepository with ApiGetHelper {
  LmaQuestionRepository(this.dio);

  @override
  final Dio dio;

  Future<List<LmaQuestionDocument>> list({String? fkSectionId}) {
    return getList(
      '/lma-questions',
      queryParameters: {'fk_section_id': fkSectionId},
      fromJson: LmaQuestionDocument.fromJson,
      nestedKeys: const ['items', 'results', 'data', 'documents'],
      fallbackMessage: 'Failed to load LMA questions',
    );
  }

  Future<LmaQuestionDocument> getById(String id) {
    return getObject(
      '/lma-questions/$id',
      fromJson: LmaQuestionDocument.fromJson,
      fallbackMessage: 'Failed to load question set',
    );
  }

  Future<LmaQuestionDocument> create(Map<String, dynamic> payload) {
    return postObject(
      '/lma-questions',
      data: payload,
      fromJson: LmaQuestionDocument.fromJson,
      fallbackMessage: 'Failed to create questions',
    );
  }

  Future<LmaQuestionDocument> update(String id, Map<String, dynamic> payload) {
    return putObject(
      '/lma-questions/$id',
      data: payload,
      fromJson: LmaQuestionDocument.fromJson,
      fallbackMessage: 'Failed to update questions',
    );
  }

  Future<void> delete(String id) {
    return deleteObject(
      '/lma-questions/$id',
      fallbackMessage: 'Failed to delete questions',
    );
  }
}

class LmaConfigRepository {
  LmaConfigRepository({
    required LmaSectionRepository sections,
    required LmaGradeRepository grades,
    required LmaQuestionRepository questions,
  })  : _sections = sections,
        _grades = grades,
        _questions = questions;

  final LmaSectionRepository _sections;
  final LmaGradeRepository _grades;
  final LmaQuestionRepository _questions;

  Future<({
    List<LmaSection> sections,
    List<LmaGrade> grades,
    List<LmaQuestionDocument> questionDocuments,
  })> loadAll() async {
    final results = await Future.wait([
      _sections.list(),
      _grades.list(),
      _questions.list(),
    ]);

    final sections = List<LmaSection>.from(results[0] as List<LmaSection>)
      ..sort((a, b) => (a.sectionOrder ?? 0).compareTo(b.sectionOrder ?? 0));
    final grades = List<LmaGrade>.from(results[1] as List<LmaGrade>)
      ..sort((a, b) => (a.gradeOrder ?? 0).compareTo(b.gradeOrder ?? 0));
    final questionDocuments =
        List<LmaQuestionDocument>.from(results[2] as List<LmaQuestionDocument>);

    return (
      sections: sections,
      grades: grades,
      questionDocuments: questionDocuments,
    );
  }
}

final lmaSectionRepositoryProvider = Provider<LmaSectionRepository>((ref) {
  return LmaSectionRepository(ref.watch(dioProvider));
});

final lmaGradeRepositoryProvider = Provider<LmaGradeRepository>((ref) {
  return LmaGradeRepository(ref.watch(dioProvider));
});

final lmaQuestionRepositoryProvider = Provider<LmaQuestionRepository>((ref) {
  return LmaQuestionRepository(ref.watch(dioProvider));
});

final lmaConfigRepositoryProvider = Provider<LmaConfigRepository>((ref) {
  return LmaConfigRepository(
    sections: ref.watch(lmaSectionRepositoryProvider),
    grades: ref.watch(lmaGradeRepositoryProvider),
    questions: ref.watch(lmaQuestionRepositoryProvider),
  );
});
