import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../data/api_key_store.dart';
import '../data/on_device_backend.dart';
import '../state/visualize_controller.dart';
import '../ui/editorial.dart';

/// Lets the user paste their OpenRouter key and pick a model. The key is
/// checked with OpenRouter (free) and stored encrypted on the phone.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _key = TextEditingController();
  final _model = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _hasSaved = false;
  String? _status;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = ref.read(apiKeyStoreProvider);
    final saved = await store.readKey();
    final model = await store.readModel();
    if (!mounted) return;
    setState(() {
      _hasSaved = saved != null;
      _model.text = model;
      if (saved != null) _status = 'A key is saved on this phone (ends in ${_tail(saved)}).';
      _statusOk = saved != null;
    });
  }

  void _setStatus(String text, {required bool ok}) {
    _status = text;
    _statusOk = ok;
  }

  String _tail(String key) => key.length <= 4 ? key : '…${key.substring(key.length - 4)}';

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = ref.read(apiKeyStoreProvider);
    final key = _key.text.trim();
    final model = _model.text.trim().isEmpty ? defaultModel : _model.text.trim();
    if (key.isEmpty && !_hasSaved) {
      setState(() => _setStatus('Paste your OpenRouter key first.', ok: false));
      return;
    }
    setState(() => _busy = true);
    if (key.isNotEmpty) {
      final check = await ref.read(keyCheckerProvider)(key);
      if (!mounted) return;
      if (check == KeyCheck.invalid) {
        setState(() {
          _busy = false;
          _setStatus('OpenRouter did not accept that key. Copy it again from openrouter.ai/keys.', ok: false);
        });
        return;
      }
      await store.writeKey(key);
      _status = check == KeyCheck.valid
          ? 'Key saved and verified with OpenRouter.'
          : 'Key saved. We could not reach OpenRouter to verify it right now.';
      _statusOk = true;
      _hasSaved = true;
      _key.clear();
    } else {
      _status = 'Model saved.';
      _statusOk = true;
    }
    await store.writeModel(model);
    ref.invalidate(hasApiKeyProvider);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove() async {
    await ref.read(apiKeyStoreProvider).deleteKey();
    ref.invalidate(hasApiKeyProvider);
    if (mounted) {
      setState(() {
        _hasSaved = false;
        _setStatus('Key removed from this phone.', ok: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          const Kicker('Your AI key'),
          const SizedBox(height: 8),
          const Text('Connect OpenRouter', style: Txt.headline),
          const SizedBox(height: 10),
          const Text(
            'Explain It Visually asks an AI model for facts and a chart plan. Paste an API key from '
            'openrouter.ai/keys. It is stored encrypted on this phone and only ever sent to OpenRouter.',
            style: Txt.dek,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _key,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: sans, fontSize: 16, letterSpacing: 0.5),
            decoration: InputDecoration(
              labelText: _hasSaved ? 'Replace key' : 'OpenRouter API key',
              hintText: 'sk-or-v1-…',
              border: const UnderlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Paste',
                    icon: const Icon(Icons.content_paste, size: 20),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) _key.text = data!.text!.trim();
                    },
                  ),
                  IconButton(
                    tooltip: _obscure ? 'Show key' : 'Hide key',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _model,
            autocorrect: false,
            style: const TextStyle(fontFamily: sans, fontSize: 15),
            decoration: const InputDecoration(
              labelText: 'Model',
              helperText: 'Any OpenRouter model with structured outputs. Default: $defaultModel',
              helperMaxLines: 2,
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (_status != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: _statusOk ? const Color(0xFFE6EFE6) : Palette.warnBg,
                border: Border(left: BorderSide(color: _statusOk ? const Color(0xFF3D7A5C) : Palette.warn, width: 3)),
              ),
              child: Text(_status!, style: const TextStyle(fontFamily: serif, fontSize: 15, color: Palette.ink)),
            ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.paper))
                    : const Text('Save'),
              ),
              if (_hasSaved) OutlinedButton(onPressed: _busy ? null : _remove, child: const Text('Remove key')),
            ],
          ),
          const SizedBox(height: 36),
          const SectionRule('How it works'),
          const SizedBox(height: 10),
          const Text(
            'Each question makes two small requests to the model: one for the facts and their sources, one to pick '
            'the chart. Usage is billed to your OpenRouter account.',
            style: TextStyle(fontFamily: serif, fontSize: 15, height: 1.5, color: Palette.ink2),
          ),
        ],
      ),
    );
  }
}
