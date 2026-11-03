import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/export/export_share.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../data/lma_registration_repository.dart';
import '../data/models/lma_registration_models.dart';

class LmaRegistrationDetailPage extends ConsumerStatefulWidget {
  const LmaRegistrationDetailPage({super.key, required this.registrationId});

  final String registrationId;

  @override
  ConsumerState<LmaRegistrationDetailPage> createState() =>
      _LmaRegistrationDetailPageState();
}

class _LmaRegistrationDetailPageState
    extends ConsumerState<LmaRegistrationDetailPage> {
  LmaRegistrationDetail? _detail;
  bool _loading = true;
  bool _busy = false;
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
      final detail = await ref
          .read(lmaRegistrationRepositoryProvider)
          .getById(widget.registrationId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _approve() async {
    final company = _detail?.summary.companyName ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve registration'),
        content: Text(
          'Approve ${company.isEmpty ? 'this registration' : company}? '
          'The server will save the company and convert it to LMA. No email is sent.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final detail = await ref
          .read(lmaRegistrationRepositoryProvider)
          .approve(widget.registrationId);
      if (!mounted) return;
      setState(() => _detail = detail);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Approved. The company was saved and converted to LMA.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _busy = true);
    try {
      final file =
          await ref.read(lmaRegistrationRepositoryProvider).registrationPdf(
                widget.registrationId,
              );
      await shareExportFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        actions: [
          IconButton(
            tooltip: 'PDF',
            onPressed: _busy || detail == null ? null : _sharePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : detail == null
                  ? const SizedBox.shrink()
                  : _buildDetail(detail),
    );
  }

  Widget _buildDetail(LmaRegistrationDetail detail) {
    final summary = detail.summary;
    final created = _formatCreated(summary.createdOn);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          summary.companyName.isEmpty
              ? 'Untitled company'
              : summary.companyName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(summary.statusLabel,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        if (summary.clientName.isNotEmpty) Text(summary.clientName),
        if (summary.clientEmail.isNotEmpty) Text(summary.clientEmail),
        if (detail.title.isNotEmpty) Text(detail.title),
        if (detail.reportDate.isNotEmpty)
          Text('Report date: ${detail.reportDate}'),
        if (created.isNotEmpty) Text(created),
        const SizedBox(height: 16),
        if (summary.canApprove)
          FilledButton(
            onPressed: _busy ? null : _approve,
            child: const Text('Approve'),
          ),
        if ((summary.assessmentId ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                context.push(AppRoutes.lmaPreview(summary.assessmentId!)),
            child: const Text('Open assessment'),
          ),
        ],
        const SizedBox(height: 20),
        Text('Company background',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _line('Introduction', detail.companyIntroduction),
        _line('Location', detail.location),
        _line('Workforce', detail.totalWorkforce?.toString() ?? ''),
        _line('Shift operation', detail.shiftOperation),
        _line('Working hours', detail.workingHours),
        _line('Working days', detail.workingDays),
        const SizedBox(height: 20),
        Text('Answers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (detail.answers.isEmpty)
          const Text('No answers were returned.')
        else
          ...detail.answers.map(
            (answer) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  answer.question.isEmpty
                      ? 'Question ${answer.questionId}'
                      : answer.question,
                ),
                subtitle: Text(
                  answer.selectedResponse.isEmpty
                      ? 'Score ${answer.score}'
                      : 'Score ${answer.score} · ${answer.selectedResponse}',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _line(String label, String value) {
    final text = value.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  String _formatCreated(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('d MMM yyyy, h:mm a').format(parsed.toLocal());
  }
}
