import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../data/lma_registration_repository.dart';
import '../data/models/lma_registration_models.dart';

class LmaRegistrationListPage extends ConsumerStatefulWidget {
  const LmaRegistrationListPage({super.key});

  @override
  ConsumerState<LmaRegistrationListPage> createState() =>
      _LmaRegistrationListPageState();
}

class _LmaRegistrationListPageState
    extends ConsumerState<LmaRegistrationListPage> {
  static const _filters = <int?, String>{
    LmaRegistrationStatus.waiting: 'Waiting',
    null: 'All',
    LmaRegistrationStatus.approved: 'Approved',
  };

  int? _status = LmaRegistrationStatus.waiting;
  List<LmaRegistrationSummary> _items = const [];
  bool _loading = true;
  String? _error;
  String? _approvingId;

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
      final items = await ref
          .read(lmaRegistrationRepositoryProvider)
          .list(status: _status);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _approve(LmaRegistrationSummary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve registration'),
        content: Text(
          'Approve ${item.companyName.isEmpty ? 'this registration' : item.companyName}? '
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

    setState(() => _approvingId = item.id);
    try {
      await ref.read(lmaRegistrationRepositoryProvider).approve(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Approved. The company was saved and converted to LMA.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _approvingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LMA registrations')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final entry in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _status == entry.key,
                      onSelected: (_) {
                        setState(() => _status = entry.key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
              child:
                  FilledButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [Center(child: Text('No registrations.'))],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final approving = _approvingId == item.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await context.push(AppRoutes.lmaRegistration(item.id));
              if (mounted) _load();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.companyName.isEmpty
                              ? 'Untitled company'
                              : item.companyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _RegistrationStatusPill(
                            status: item.status, label: item.statusLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (item.clientName.isNotEmpty) Text(item.clientName),
                  if (item.clientEmail.isNotEmpty) Text(item.clientEmail),
                  if ((item.createdOn ?? '').isNotEmpty)
                    Text(_formatCreated(item.createdOn!),
                        style: Theme.of(context).textTheme.bodyMedium),
                  if (item.canApprove) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: approving ? null : () => _approve(item),
                        child: approving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Approve'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCreated(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('d MMM yyyy, h:mm a').format(parsed.toLocal());
  }
}

class _RegistrationStatusPill extends StatelessWidget {
  const _RegistrationStatusPill({required this.status, required this.label});

  final int status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = status == LmaRegistrationStatus.approved
        ? const Color(0xFF1F8F55)
        : status == LmaRegistrationStatus.rejected
            ? const Color(0xFF8D6E63)
            : const Color(0xFFE39B2B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
