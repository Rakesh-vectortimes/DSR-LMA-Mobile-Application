import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lma_config_repository.dart';
import '../../data/models/lma_config_models.dart';
import '../../domain/lma_settings.dart';
import '../lma_config_controller.dart';
import 'lma_settings_widgets.dart';

class LmaSectionSettingsTab extends ConsumerStatefulWidget {
  const LmaSectionSettingsTab({super.key});

  @override
  ConsumerState<LmaSectionSettingsTab> createState() =>
      _LmaSectionSettingsTabState();
}

class _LmaSectionSettingsTabState extends ConsumerState<LmaSectionSettingsTab> {
  List<LmaSection> _sections = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sections = await ref.read(lmaSectionRepositoryProvider).list();
      sections.sort((a, b) => (a.sectionOrder ?? 0).compareTo(b.sectionOrder ?? 0));
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = settingsErrorMessage(error, 'Failed to load sections');
      });
    }
  }

  Future<void> _afterMutation() async {
    await ref.read(lmaConfigControllerProvider.notifier).refreshAfterMutation();
    await _load();
  }

  Future<void> _openForm({LmaSection? existing}) async {
    final saved = await showSettingsSheet<bool>(
      context: context,
      child: _SectionFormSheet(
        existing: existing,
        sections: _sections,
      ),
    );
    if (saved == true) {
      await _afterMutation();
    }
  }

  Future<void> _delete(LmaSection section) async {
    final confirmed = await confirmSettingsDelete(
      context,
      title: 'Delete section',
      message: 'Delete section "${section.sectionName}"?',
    );
    if (!confirmed) return;
    try {
      await ref.read(lmaSectionRepositoryProvider).delete(section.id);
      if (!mounted) return;
      showSettingsMessage(context, 'Section deleted.');
      await _afterMutation();
    } catch (error) {
      if (!mounted) return;
      showSettingsMessage(
        context,
        settingsErrorMessage(error, 'Failed to delete section'),
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
                child: Text(
                  'Manage assessment sections for lean maturity assessments.',
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Section'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SettingsListScaffold(
            loading: _loading,
            error: _error,
            isEmpty: _sections.isEmpty,
            emptyLabel: 'No sections yet.',
            onRetry: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final section = _sections[index];
                return Card(
                  child: ListTile(
                    title: Text(section.sectionName),
                    subtitle: Text(
                      'Order ${section.sectionOrder ?? '-'} · '
                      '${section.noOfQuestions} questions · '
                      '${section.totalMarks} marks',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _openForm(existing: section),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(section),
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

class _SectionFormSheet extends ConsumerStatefulWidget {
  const _SectionFormSheet({
    required this.sections,
    this.existing,
  });

  final LmaSection? existing;
  final List<LmaSection> sections;

  @override
  ConsumerState<_SectionFormSheet> createState() => _SectionFormSheetState();
}

class _SectionFormSheetState extends ConsumerState<_SectionFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _order;
  SectionFormErrors _errors = const SectionFormErrors();
  bool _saving = false;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.sectionName ?? '');
    _order = TextEditingController(
      text: '${widget.existing?.sectionOrder ?? widget.sections.length + 1}',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  List<LmaSection> get _others {
    final id = widget.existing?.id;
    if (id == null) return widget.sections;
    return widget.sections.where((section) => section.id != id).toList();
  }

  Future<void> _save() async {
    final errors = validateSectionForm(
      sectionName: _name.text,
      sectionOrder: int.tryParse(_order.text.trim()),
      others: _others,
    );
    setState(() => _errors = errors);
    if (errors.hasError) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(lmaSectionRepositoryProvider);
      final order = int.parse(_order.text.trim());
      if (_isCreate) {
        await repo.create(
          buildSectionCreatePayload(sectionName: _name.text, sectionOrder: order),
        );
      } else {
        await repo.update(
          widget.existing!.id,
          buildSectionUpdatePayload(sectionName: _name.text, sectionOrder: order),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = settingsErrorMessage(error, 'Failed to save section');
      setState(() {
        _saving = false;
        _errors = SectionFormErrors(
          sectionName: applyServerFieldHint(message, 'section_name').isNotEmpty
              ? applyServerFieldHint(message, 'section_name')
              : _errors.sectionName,
          sectionOrder: applyServerFieldHint(message, 'section_order').isNotEmpty
              ? applyServerFieldHint(message, 'section_order')
              : _errors.sectionOrder,
        );
      });
      showSettingsMessage(context, message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsSheetHeader(
          title: _isCreate ? 'Add section' : 'Edit section',
          saving: _saving,
          onCancel: () => Navigator.of(context).pop(false),
          onSave: _save,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Section name *',
                  errorText: _errors.sectionName.isEmpty ? null : _errors.sectionName,
                ),
                onChanged: (_) {
                  if (_errors.sectionName.isNotEmpty) {
                    setState(() => _errors = const SectionFormErrors());
                  }
                },
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'No. of questions',
                  helperText: 'Auto-calculated from LMA questions',
                ),
                child: Text('${existing?.noOfQuestions ?? 0}'),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Total marks',
                  helperText: 'Sum of max option scores per question',
                ),
                child: Text('${existing?.totalMarks ?? 0}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Order *',
                  errorText: _errors.sectionOrder.isEmpty ? null : _errors.sectionOrder,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
