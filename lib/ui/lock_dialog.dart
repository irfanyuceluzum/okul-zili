import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'theme.dart';

/// Şifre sorar; doğruysa true (kurtarma kodu da kabul edilir), vazgeçilirse false.
Future<bool> askUnlock(BuildContext context, AppController controller) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _UnlockDialog(controller: controller),
  );
  return result ?? false;
}

/// Kilit yoksa ya da oturum açıksa doğrudan true; kilitliyse şifre sorar.
Future<bool> ensureUnlocked(BuildContext context, AppController controller) async {
  if (!controller.isLockEnabled || !controller.isLocked) return true;
  return askUnlock(context, controller);
}

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({required this.controller});

  final AppController controller;

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _secret = TextEditingController();
  bool _busy = false;
  bool _forgot = false;
  String? _error;

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.controller.unlock(_secret.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Şifre yanlış';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.controller.config.lock?.hint;
    return AlertDialog(
      title: const Text('Şifre gerekli'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _secret,
                autofocus: true,
                obscureText: true,
                enabled: !_busy,
                decoration: InputDecoration(labelText: 'Şifre', errorText: _error),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _forgot = !_forgot),
                child: const Text('Şifreyi unuttum'),
              ),
              if (_forgot) ...[
                if (hint != null && hint.isNotEmpty) Text('İpucu: $hint'),
                const Text(
                  'Kurtarma kodunu da buraya yazabilirsiniz.',
                  style: TextStyle(color: AppColors.inkSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kilidi aç'),
        ),
      ],
    );
  }
}

// ---- Şifre belirleme / değiştirme / kaldırma ------------------------------------

/// Şifre belirler ya da değiştirir; başarılıysa kurtarma kodunu bir kez gösterir.
Future<void> setPasswordFlow(BuildContext context, AppController controller) async {
  final code = await showDialog<String>(
    context: context,
    builder: (context) => _SetPasswordDialog(controller: controller),
  );
  if (code == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Kurtarma kodunuz'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: SelectableText(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
            const SizedBox(height: 16),
            const Text(
              'Bu kodu kâğıda yazın; şifreyi unutursanız bununla açabilirsiniz. Bir daha gösterilmeyecek.',
            ),
            if (controller.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                'Uyarı: ${controller.lastError}',
                style: const TextStyle(color: AppColors.dangerText),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Yazdım, kapat'),
        ),
      ],
    ),
  );
}

class _SetPasswordDialog extends StatefulWidget {
  const _SetPasswordDialog({required this.controller});

  final AppController controller;

  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  final _hint = TextEditingController();
  bool _busy = false;
  String? _currentError;
  String? _newError;
  String? _repeatError;

  bool get _changing => widget.controller.isLockEnabled;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    _hint.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final newError = _new.text.length < 4 ? 'Şifre en az 4 karakter olmalı' : null;
    final repeatError = newError == null && _repeat.text != _new.text ? 'Şifreler aynı değil' : null;
    if (newError != null || repeatError != null) {
      setState(() {
        _currentError = null;
        _newError = newError;
        _repeatError = repeatError;
      });
      return;
    }
    setState(() {
      _busy = true;
      _currentError = _newError = _repeatError = null;
    });
    try {
      final code = await widget.controller.setPassword(
        current: _changing ? _current.text : null,
        newPassword: _new.text,
        hint: _hint.text,
      );
      if (mounted) Navigator.pop(context, code);
    } on StateError {
      if (mounted) {
        setState(() {
          _busy = false;
          _currentError = 'Mevcut şifre ya da kurtarma kodu yanlış';
        });
      }
    } on ArgumentError {
      if (mounted) {
        setState(() {
          _busy = false;
          _newError = 'Şifre en az 4 karakter olmalı';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_changing ? 'Şifreyi değiştir' : 'Şifre belirle'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_changing) ...[
                TextField(
                  controller: _current,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: InputDecoration(labelText: 'Mevcut şifre', errorText: _currentError),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _new,
                obscureText: true,
                enabled: !_busy,
                decoration: InputDecoration(labelText: 'Yeni şifre', errorText: _newError),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repeat,
                obscureText: true,
                enabled: !_busy,
                decoration: InputDecoration(labelText: 'Yeni şifre (tekrar)', errorText: _repeatError),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hint,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'İpucu (isteğe bağlı)'),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Şifre ya da kurtarma koduyla kilidi tamamen kaldırır; kaldırıldıysa true.
Future<bool> removeLockFlow(BuildContext context, AppController controller) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _RemoveLockDialog(controller: controller),
  );
  return result ?? false;
}

class _RemoveLockDialog extends StatefulWidget {
  const _RemoveLockDialog({required this.controller});

  final AppController controller;

  @override
  State<_RemoveLockDialog> createState() => _RemoveLockDialogState();
}

class _RemoveLockDialogState extends State<_RemoveLockDialog> {
  final _secret = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.controller.removeLock(_secret.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Şifre ya da kurtarma kodu yanlış';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kilidi kaldır'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kilidi kaldırmak için şifreyi ya da kurtarma kodunu yazın.'),
            const SizedBox(height: 12),
            TextField(
              controller: _secret,
              autofocus: true,
              obscureText: true,
              enabled: !_busy,
              decoration: InputDecoration(labelText: 'Şifre ya da kurtarma kodu', errorText: _error),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kilidi kaldır'),
        ),
      ],
    );
  }
}
