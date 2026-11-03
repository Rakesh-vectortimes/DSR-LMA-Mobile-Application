import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/export/export_share.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/form_wizard_scaffold.dart';
import '../../lma/domain/lean_maturity_data.dart';
import '../data/lma_registration_repository.dart';
import '../data/models/lma_registration_models.dart';
import '../domain/lma_registration_rules.dart';

/// Public form. No login. The server saves the registration and emails the PDF.
class LmaRegisterPage extends ConsumerStatefulWidget {
  const LmaRegisterPage({super.key});

  @override
  ConsumerState<LmaRegisterPage> createState() => _LmaRegisterPageState();
}

class _LmaRegisterPageState extends ConsumerState<LmaRegisterPage> {
  final _detailsKey = GlobalKey<FormState>();
  final _clientName = TextEditingController();
  final _clientEmail = TextEditingController();
  final _companyName = TextEditingController();
  final _title = TextEditingController();
  final _introduction = TextEditingController();
  final _location = TextEditingController();
  final _workforce = TextEditingController();
  final _shift = TextEditingController();
  final _hours = TextEditingController();
  final _days = TextEditingController();

  PublicLmaFormConfig? _config;
  DateTime _reportDate = DateTime.now();
  final Map<int, int> _scores = {};
  int _step = 0;
  bool _loading = true;
  bool _busy = false;
  bool _titleEdited = false;
  String? _error;
  LmaRegistrationSubmitResult? _result;

  @override
  void initState() {
    super.initState();
    _companyName.addListener(_syncTitle);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _clientName.dispose();
    _clientEmail.dispose();
    _companyName.dispose();
    _title.dispose();
    _introduction.dispose();
    _location.dispose();
    _workforce.dispose();
    _shift.dispose();
    _hours.dispose();
    _days.dispose();
    super.dispose();
  }

  void _syncTitle() {
    if (_titleEdited) return;
    final company = _companyName.text.trim();
    final next = company.isEmpty ? '' : '$company Lean Maturity Assessment';
    if (_title.text == next) return;
    _title.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config =
          await ref.read(lmaRegistrationRepositoryProvider).loadConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
        if (config.questions.isEmpty) {
          _error = 'No assessment questions are configured yet.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> _payload() {
    return buildLmaRegistrationPayload(
      companyName: _companyName.text,
      clientName: _clientName.text,
      clientEmail: _clientEmail.text,
      title: _title.text,
      reportDate: DateFormat('yyyy-MM-dd').format(_reportDate),
      companyIntroduction: _introduction.text,
      location: _location.text,
      totalWorkforce: int.tryParse(_workforce.text.trim()),
      shiftOperation: _shift.text,
      workingHours: _hours.text,
      workingDays: _days.text,
      questions: _config?.questions ?? const [],
      scores: _scores,
    );
  }

  bool _detailsValid() => _detailsKey.currentState?.validate() ?? false;

  bool _categoryComplete(String category) {
    final questions = _config?.questionsFor(category) ?? const [];
    return questions.every((question) => _scores.containsKey(question.id));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _reportDate = picked);
  }

  void _next() {
    final config = _config;
    if (config == null) return;
    if (_step == 0) {
      if (!_detailsValid()) return;
    } else if (_step <= config.categories.length) {
      final category = config.categories[_step - 1];
      if (!_categoryComplete(category)) {
        _message('Answer every question in this section before continuing.');
        return;
      }
    }
    setState(() => _step += 1);
  }

  Future<void> _preview() async {
    if (_scores.isEmpty) {
      _message('Answer at least one question before previewing the PDF.');
      return;
    }
    setState(() => _busy = true);
    try {
      final file = await ref
          .read(lmaRegistrationRepositoryProvider)
          .previewPdf(_payload());
      await shareExportFile(file);
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final config = _config;
    if (config == null) return;
    if (!_detailsValid()) {
      setState(() => _step = 0);
      return;
    }
    if (_scores.isEmpty) {
      _message('Answer at least one question before submitting.');
      return;
    }
    final unanswered =
        config.questions.where((question) => !_scores.containsKey(question.id));
    if (unanswered.isNotEmpty) {
      _message('Answer every question before submitting.');
      return;
    }

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(lmaRegistrationRepositoryProvider).submit(_payload());
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildResult(_result!);
    if (_loading) {
      return const Scaffold(
        appBar: _Bar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _config == null || _config!.questions.isEmpty) {
      return Scaffold(
        appBar: const _Bar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'The registration form is unavailable.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final config = _config!;
    final stepCount = config.categories.length + 2;
    final last = _step >= stepCount - 1;
    final stepTitle = _step == 0
        ? 'Company'
        : _step <= config.categories.length
            ? categoryStepLabel(config.categories[_step - 1])
            : 'Review';

    return FormWizardScaffold(
      title: 'LMA registration',
      stepIndex: _step,
      stepCount: stepCount,
      stepTitle: stepTitle,
      saving: _busy,
      saveLabel: 'Preview PDF',
      nextLabel: last ? 'Submit' : 'Next',
      onSave: last ? _preview : null,
      onNext: last ? _submit : _next,
      onStepBack: _step == 0 ? null : () => setState(() => _step -= 1),
      body: _step == 0
          ? _buildDetails()
          : _step <= config.categories.length
              ? _buildCategory(config.categories[_step - 1])
              : _buildReview(config),
    );
  }

  Widget _buildDetails() {
    return Form(
      key: _detailsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _clientName,
            decoration: const InputDecoration(labelText: 'Your name'),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if ((value ?? '').trim().length < 2) {
                return 'Enter at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _clientEmail,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (!isRegistrationEmail(value ?? '')) {
                return 'Enter an email like name@company.com';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _companyName,
            decoration: const InputDecoration(labelText: 'Company name'),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if ((value ?? '').trim().length < 2) {
                return 'Enter at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Assessment title'),
            onChanged: (_) => _titleEdited = true,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Report date',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(DateFormat('d MMM yyyy').format(_reportDate)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _introduction,
            decoration: const InputDecoration(labelText: 'Company background'),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _workforce,
            decoration: const InputDecoration(labelText: 'Total workforce'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _shift,
            decoration: const InputDecoration(labelText: 'Shift operation'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _hours,
            decoration: const InputDecoration(labelText: 'Working hours'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _days,
            decoration: const InputDecoration(labelText: 'Working days'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(String category) {
    final questions = _config?.questionsFor(category) ?? const [];
    final answered =
        questions.where((question) => _scores.containsKey(question.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$answered / ${questions.length} answered',
          style: const TextStyle(
              color: AppColors.primaryDark, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...questions.map((question) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<int>(
                    groupValue: _scores[question.id],
                    onChanged: (value) {
                      if (_busy || value == null) {
                        return;
                      }
                      setState(() => _scores[question.id] = value);
                    },
                    child: Column(
                      children: [
                        for (final level in question.levels)
                          RadioListTile<int>(
                            value: level.score,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${level.score}'),
                            subtitle: level.description.isEmpty
                                ? null
                                : Text(level.description),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReview(PublicLmaFormConfig config) {
    final answered = _scores.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companyName.text.trim().isEmpty
                      ? 'Company'
                      : _companyName.text.trim(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(_clientName.text.trim()),
                Text(_clientEmail.text.trim()),
                Text(
                    'Report date: ${DateFormat('yyyy-MM-dd').format(_reportDate)}'),
                const SizedBox(height: 8),
                Text(
                    '$answered / ${config.questions.length} questions answered'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Submit saves the registration as waiting for approval. The server emails the PDF. The company is created only after a super admin approves it.',
        ),
      ],
    );
  }

  Widget _buildResult(LmaRegistrationSubmitResult result) {
    final email = _clientEmail.text.trim();
    return Scaffold(
      appBar: const _Bar(),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.mark_email_read_outlined,
              size: 56, color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Registration saved',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
              'Status: Waiting for approval. The company is not created until a super admin approves it.'),
          const SizedBox(height: 12),
          Text(lmaRegistrationEmailMessage(
            emailSent: result.emailSent,
            email: email,
            emailError: result.emailError,
          )),
          const SizedBox(height: 24),
          FilledButton(onPressed: _leave, child: const Text('Done')),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('LMA registration'));
  }
}
