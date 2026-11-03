import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/lma_registration_repository.dart';
import '../data/models/lma_registration_models.dart';
import '../domain/lma_registration_rules.dart';

/// Shows the QR the server already generated. Saving a URL asks the server for a new PNG.
class LmaQrSettingsPage extends ConsumerStatefulWidget {
  const LmaQrSettingsPage({super.key});

  @override
  ConsumerState<LmaQrSettingsPage> createState() => _LmaQrSettingsPageState();
}

class _LmaQrSettingsPageState extends ConsumerState<LmaQrSettingsPage> {
  final _urlController = TextEditingController();
  LmaQrSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings =
          await ref.read(lmaRegistrationRepositoryProvider).qrSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _urlController.text = settings.current?.url ?? '';
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

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (!isLmaRegistrationQrUrl(url)) {
      _message(
          'The URL must start with http:// or https:// and end with /register or /Lma-register.');
      return;
    }
    setState(() => _saving = true);
    try {
      final settings =
          await ref.read(lmaRegistrationRepositoryProvider).saveQrUrl(url);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _urlController.text = settings.current?.url ?? url;
      });
      _message('QR code saved. Older codes are now inactive.');
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final current = _settings?.current;
    final bytes = decodeQrImage(current?.image);
    final history = (_settings?.items ?? const <LmaQrCode>[])
        .where((item) => item.id.isEmpty || item.id != current?.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Settings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Scanning the code only opens the public registration page. The server stores the image.',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (bytes != null)
                          Image.memory(bytes,
                              width: 220, height: 220, fit: BoxFit.contain)
                        else
                          const SizedBox(
                            height: 180,
                            child: Center(child: Text('No QR code saved yet.')),
                          ),
                        if ((current?.url ?? '').isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            current!.url,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Registration page URL',
                    hintText: 'https://your-domain/Lma-register',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save QR'),
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Earlier codes',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...history.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.qr_code_2),
                      title: Text(
                        item.url.isEmpty ? 'Saved code' : item.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(item.active ? 'Active' : 'Inactive'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
