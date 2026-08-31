import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lma_config_repository.dart';
import '../../data/models/lma_config_models.dart';
import '../../domain/lma_settings.dart';
import '../lma_config_controller.dart';
import 'lma_settings_widgets.dart';

class LmaQuestionSettingsTab extends ConsumerStatefulWidget {
  const LmaQuestionSettingsTab({super.key});

  @override
  ConsumerState<LmaQuestionSettingsTab> createState() =>
      _LmaQuestionSettingsTabState();
}

class _LmaQuestionSettingsTabState extends ConsumerState<LmaQuestionSettingsTab> {
  List<LmaSection> _sections = const [];
  List<LmaQuestionDocument> _documents = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<LmaSection> get _unusedSections {
    final used = _documents.map((doc) => doc.fkSectionId).toSet();
    return _sections.where((section) => !used.contains(section.id)).toList();
  }

  String _sectionName(String id) {
    for (final section in _sections) {
      if (section.id == id) return section.sectionName;
    }
    return id;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sectionsRepo = ref.read(lmaSectionRepositoryProvider);
      final questionsRepo = ref.read(lmaQuestionRepositoryProvider);
      final results = await Future.wait([
        sectionsRepo.list(),
        questionsRepo.list(),
      ]);
      final sections = List<LmaSection>.from(results[0] as List<LmaSection>)
        ..sort((a, b) => (a.sectionOrder ?? 0).compareTo(b.sectionOrder ?? 0));
      final documents = List<LmaQuestionDocument>.from(
        results[1] as List<LmaQuestionDocument>,
      );
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _documents = documents;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = settingsErrorMessage(error, 'Failed to load questions');
      });
    }
  }

  Future<void> _afterMutation() async {
    await ref.read(lmaConfigControllerProvider.notifier).refreshAfterMutation();
    await _load();
  }

  Future<void> _openForm({LmaQuestionDocument? existing}) async {
    if (existing == null && _unusedSections.isEmpty) {
      showSettingsMessage(
        context,
        _sections.isEmpty
            ? 'Add a section before creating questions.'
            : 'Every section already has a question set.',
        error: true,
      );
      return;
    }
    final saved = await showSettingsSheet<bool>(
      context: context,
      child: _QuestionFormSheet(
        existing: existing,
        sections: _sections,
        documents: _documents,
      ),
    );
    if (saved == true) {
      await _afterMutation();
    }
  }

  Future<void> _delete(LmaQuestionDocument document) async {
    final name = _sectionName(document.fkSectionId);
    final confirmed = await confirmSettingsDelete(
      context,
      title: 'Delete question set',
      message: 'Delete all questions for "$name"?',
    );
    if (!confirmed) return;
    try {
      await ref.read(lmaQuestionRepositoryProvider).delete(document.id);
      if (!mounted) return;
      showSettingsMessage(context, 'Question set deleted.');
      await _afterMutation();
    } catch (error) {
      if (!mounted) return;
      showSettingsMessage(
        context,
        settingsErrorMessage(error, 'Failed to delete questions'),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Manage questions and answer options for each assessment section.'),
              ),
              FilledButton.icon(
                onPressed: _unusedSections.isEmpty ? null : () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Question Set'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SettingsListScaffold(
            loading: _loading,
            error: _error,
            isEmpty: _documents.isEmpty,
            emptyLabel: _sections.isEmpty
                ? 'Add a section first, then create questions.'
                : 'No question sets yet.',
            onRetry: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final document = _documents[index];
                return Card(
                  child: ListTile(
                    title: Text(_sectionName(document.fkSectionId)),
                    subtitle: Text('${document.questions.length} questions'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _openForm(existing: document),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(document),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionFormSheet extends ConsumerStatefulWidget {
  const _QuestionFormSheet({
    required this.sections,
    required this.documents,
    this.existing,
  });

  final LmaQuestionDocument? existing;
  final List<LmaSection> sections;
  final List<LmaQuestionDocument> documents;

  @override
  ConsumerState<_QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends ConsumerState<_QuestionFormSheet> {
  late String _fkSectionId;
  late List<LmaQuestionItem> _questions;
  QuestionFormErrors _errors = const QuestionFormErrors();
  bool _saving = false;

  bool get _isCreate => widget.existing == null;

  List<LmaSection> get _availableSections {
    final used = widget.documents.map((doc) => doc.fkSectionId).toSet();
    return widget.sections
        .where((section) => !used.contains(section.id) || section.id == _fkSectionId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _fkSectionId = existing.fkSectionId;
      _questions = existing.questions
          .map(
            (question) => question.copyWith(
              options: [...question.options]..sort((a, b) => a.score.compareTo(b.score)),
            ),
          )
          .toList();
    } else {
      final available = widget.sections.where((section) {
        final used = widget.documents.map((doc) => doc.fkSectionId).toSet();
        return !used.contains(section.id);
      }).toList();
      _fkSectionId = available.isNotEmpty ? available.first.id : '';
      _questions = [emptyQuestionItem()];
    }
    _syncIds();
  }

  void _syncIds() {
    if (_fkSectionId.isEmpty) return;
    final preview = previewQuestionIds(
      sections: widget.sections,
      documents: widget.documents,
      draftSectionId: _fkSectionId,
      draftQuestionCount: _questions.length,
    );
    _questions = applyQuestionIdPreview(_questions, preview[_fkSectionId] ?? const []);
  }

  Future<void> _save() async {
    _syncIds();
    final errors = validateQuestionForm(
      fkSectionId: _fkSectionId,
      questions: _questions,
    );
    setState(() => _errors = errors);
    if (errors.hasError) return;

    setState(() => _saving = true);
    try {
      final payload = buildQuestionDocumentPayload(
        fkSectionId: _fkSectionId,
        questions: _questions,
      );
      final repo = ref.read(lmaQuestionRepositoryProvider);
      if (_isCreate) {
        await repo.create(payload);
      } else {
        await repo.update(widget.existing!.id, payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSettingsMessage(
        context,
        settingsErrorMessage(error, 'Failed to save questions'),
        error: true,
      );
    }
  }

  void _addQuestion() {
    setState(() {
      _questions = [..._questions, emptyQuestionItem()];
      _syncIds();
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions = [
        for (var i = 0; i < _questions.length; i++)
          if (i != index) _questions[i],
      ];
      _syncIds();
    });
  }

  void _addOption(int questionIndex) {
    final question = _questions[questionIndex];
    final nextScore = question.options.fold<int>(
          -1,
          (max, option) => option.score > max ? option.score : max,
        ) +
        1;
    setState(() {
      _questions[questionIndex] = question.copyWith(
        options: [...question.options, LmaQuestionOption(score: nextScore, description: '')],
      );
    });
  }

  void _removeOption(int questionIndex, int optionIndex) {
    final question = _questions[questionIndex];
    if (question.options.length <= 1) return;
    setState(() {
      _questions[questionIndex] = question.copyWith(
        options: [
          for (var i = 0; i < question.options.length; i++)
            if (i != optionIndex) question.options[i],
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.9;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          SettingsSheetHeader(
            title: _isCreate ? 'Add question set' : 'Edit question set',
            saving: _saving,
            onCancel: () => Navigator.of(context).pop(false),
            onSave: _save,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                DropdownButtonFormField<String>(
                  value: _availableSections.any((section) => section.id == _fkSectionId)
                      ? _fkSectionId
                      : null,
                  items: [
                    for (final section in _availableSections)
                      DropdownMenuItem(
                        value: section.id,
                        child: Text(section.sectionName),
                      ),
                  ],
                  onChanged: _isCreate
                      ? (value) {
                          setState(() {
                            _fkSectionId = value ?? '';
                            _questions = [emptyQuestionItem()];
                            _syncIds();
                            _errors = const QuestionFormErrors();
                          });
                        }
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Section *',
                    errorText: _errors.section.isEmpty ? null : _errors.section,
                  ),
                ),
                if (_errors.questions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errors.questions,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                for (var qi = 0; qi < _questions.length; qi++) ...[
                  _QuestionEditor(
                    key: ValueKey('question-$qi'),
                    index: qi,
                    question: _questions[qi],
                    errors: _errors,
                    onQuestionChanged: (value) {
                      setState(() {
                        _questions[qi] = _questions[qi].copyWith(question: value);
                      });
                    },
                    onRemoveQuestion: () => _removeQuestion(qi),
                    onAddOption: () => _addOption(qi),
                    onRemoveOption: (oi) => _removeOption(qi, oi),
                    onOptionScoreChanged: (oi, score) {
                      final options = [..._questions[qi].options];
                      options[oi] = options[oi].copyWith(score: score);
                      setState(() {
                        _questions[qi] = _questions[qi].copyWith(options: options);
                      });
                    },
                    onOptionDescriptionChanged: (oi, description) {
                      final options = [..._questions[qi].options];
                      options[oi] = options[oi].copyWith(description: description);
                      setState(() {
                        _questions[qi] = _questions[qi].copyWith(options: options);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                OutlinedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add question'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    super.key,
    required this.index,
    required this.question,
    required this.errors,
    required this.onQuestionChanged,
    required this.onRemoveQuestion,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onOptionScoreChanged,
    required this.onOptionDescriptionChanged,
  });

  final int index;
  final LmaQuestionItem question;
  final QuestionFormErrors errors;
  final ValueChanged<String> onQuestionChanged;
  final VoidCallback onRemoveQuestion;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final void Function(int optionIndex, int score) onOptionScoreChanged;
  final void Function(int optionIndex, String description) onOptionDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove question',
                  onPressed: onRemoveQuestion,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Question ID',
                helperText: 'Assigned automatically across all sections when you save',
              ),
              child: Text('${question.questionId}'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: question.question,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Question *',
                errorText: errors.field('q-$index-text').isEmpty
                    ? null
                    : errors.field('q-$index-text'),
              ),
              onChanged: onQuestionChanged,
            ),
            const SizedBox(height: 12),
            for (var oi = 0; oi < question.options.length; oi++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: TextFormField(
                      initialValue: '${question.options[oi].score}',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Score *',
                        errorText: errors.field('q-$index-opt-$oi-score').isEmpty
                            ? null
                            : errors.field('q-$index-opt-$oi-score'),
                      ),
                      onChanged: (value) {
                        final score = int.tryParse(value);
                        if (score != null) onOptionScoreChanged(oi, score);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: question.options[oi].description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        errorText: errors.field('q-$index-opt-$oi').isEmpty
                            ? null
                            : errors.field('q-$index-opt-$oi'),
                      ),
                      onChanged: (value) => onOptionDescriptionChanged(oi, value),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove option',
                    onPressed: question.options.length <= 1
                        ? null
                        : () => onRemoveOption(oi),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddOption,
                icon: const Icon(Icons.add),
                label: const Text('Add option'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
