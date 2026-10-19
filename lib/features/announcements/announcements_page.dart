import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../data/models/app_config.dart';
import '../../data/models/spoken_announcement.dart';
import '../../platform/audio_file_picker.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Sesli anonslar: ses dosyası, mikrofon kaydı ya da yazıdan okuma.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  AppController get c => widget.controller;
  /// Yalnız gerektiğinde (yazıdan okunan anons varken ya da okuma penceresi
  /// açılınca) sorulur; Windows'ta bir PowerShell çalıştırır.
  late final Future<bool?> _turkishVoice = c.speech.hasTurkishVoice();

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _play(SpokenAnnouncement a) async {
    final error = await c.playAnnouncement(a);
    if (error != null) _snack(error);
  }

  Future<void> _addFromFile() async {
    final path = await c.pickAudioFile();
    if (path == null || !mounted) return;
    final fileName = path.split(RegExp(r'[/\\]')).last;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!supportedAudioExtensions.contains(ext)) {
      _snack('Bu dosya biçimi desteklenmiyor. Şunlardan birini seçin: ${supportedAudioExtensions.join(', ')}');
      return;
    }
    final details = await showDialog<_Details>(
      context: context,
      builder: (context) => _DetailsDialog(
        title: 'Ses dosyasından anons',
        initialName: AppController.recognizeSoundName(fileName).name,
      ),
    );
    if (details == null) return;
    try {
      final a = await c.addAnnouncementFromFile(path, name: details.name, chime: details.chime);
      if (a != null) _snack('"${a.name}" eklendi.');
    } catch (e) {
      _snack('Dosya kopyalanamadı: $e');
    }
  }

  Future<void> _record() => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _RecordDialog(controller: c),
      );

  Future<void> _speech({SpokenAnnouncement? initial}) => showDialog<void>(
        context: context,
        builder: (context) => _SpeechDialog(controller: c, initial: initial, turkishVoice: _turkishVoice),
      );

  Future<void> _edit(SpokenAnnouncement a) async {
    if (!a.isAudio) return _speech(initial: a);
    final details = await showDialog<_Details>(
      context: context,
      builder: (context) => _DetailsDialog(title: 'Anonsu düzenle', initialName: a.name, initialChime: a.chime),
    );
    if (details != null) await c.updateSpokenAnnouncement(a.copyWith(name: details.name, chime: details.chime));
  }

  Future<void> _delete(SpokenAnnouncement a) async {
    final usages = c.announcementUsages(a.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${a.name}" silinsin mi?'),
        content: Text(usages.isEmpty
            ? 'Bu anons hiçbir etkinlikte kullanılmıyor.'
            : 'Şu etkinlikler bu anonsu yapıyor ve kapatılacak: ${usages.join(', ')}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) await c.deleteSpokenAnnouncement(a);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final list = c.config.spokenAnnouncements;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Anonslar',
                subtitle: const Text('Hoparlörden sesli anons: hazır kayıt, mikrofondan kayıt ya da yazıdan okuma.'),
                trailing: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _addFromFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Ses dosyasından…'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _record,
                      icon: const Icon(Icons.mic_none),
                      label: const Text('Mikrofondan kaydet'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _speech,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('Yazıdan okut'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (list.any((a) => !a.isAudio))
                FutureBuilder<bool?>(
                  future: _turkishVoice,
                  builder: (context, snapshot) => snapshot.data == false
                      ? const Padding(padding: EdgeInsets.only(bottom: 24), child: _NoTurkishVoiceNote())
                      : const SizedBox.shrink(),
                ),
              SectionCard(
                title: 'Kayıtlı anonslar',
                icon: Icons.record_voice_over_outlined,
                subtitle: 'Ana ekrandaki "Anons" düğmesinden yapılır. Belirli saatte kendiliğinden yapılması için '
                    'Özel etkinlikler sayfasında etkinlik ekleyip ses olarak anonsu seçin.',
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Henüz anons yok. Yukarıdaki düğmelerden ekleyin.',
                            style: TextStyle(color: AppColors.inkMuted)),
                      ),
                    for (final a in list)
                      _AnnouncementRow(
                        controller: c,
                        announcement: a,
                        usages: c.announcementUsages(a.id),
                        onPlay: () => _play(a),
                        onChime: (v) => c.updateSpokenAnnouncement(a.copyWith(chime: v)),
                        onEdit: () => _edit(a),
                        onDelete: () => _delete(a),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoTurkishVoiceNote extends StatelessWidget {
  const _NoTurkishVoiceNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: AppColors.recessTint, borderRadius: BorderRadius.circular(14)),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.recessText),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Bu bilgisayarda Türkçe konuşma sesi yüklü değil; yazılar yabancı bir sesle okunabilir. '
                'Windows Ayarlar → Saat ve dil → Konuşma → "Ses ekle" bölümünden Türkçe sesi yükleyin.',
                style: TextStyle(color: AppColors.recessText),
              ),
            ),
          ],
        ),
      );
}

/// Anonsun yanında oynat / duraklat-sürdür / durdur.
class AnnouncementButtons extends StatelessWidget {
  const AnnouncementButtons({super.key, required this.controller, required this.announcement, required this.onPlay});

  final AppController controller;
  final SpokenAnnouncement announcement;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final active = controller.announcementPlaying?.id == a.id;
    final paused = active && controller.announcementPaused;
    final canPause = active && !paused;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: canPause ? '${a.name} duraklat' : (paused ? '${a.name} sürdür' : '${a.name} çal'),
          onPressed: canPause
              ? controller.pauseAnnouncement
              : paused
                  ? controller.resumeAnnouncement
                  : (active ? null : onPlay),
          icon: Icon(canPause ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.lesson),
        ),
        IconButton(
          tooltip: '${a.name} durdur',
          onPressed: active ? controller.stopSound : null,
          icon: Icon(Icons.stop_rounded, color: active ? AppColors.ink : AppColors.lineStrong),
        ),
      ],
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({
    required this.controller,
    required this.announcement,
    required this.usages,
    required this.onPlay,
    required this.onChime,
    required this.onEdit,
    required this.onDelete,
  });

  final AppController controller;
  final SpokenAnnouncement announcement;
  final List<String> usages;
  final VoidCallback onPlay;
  final ValueChanged<bool> onChime;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final detail = [
      if (!a.isAudio) '"${a.text!.trim().replaceAll('\n', ' ')}"',
      if (usages.isNotEmpty) 'Etkinlik: ${usages.join(', ')}',
    ];
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          AnnouncementButtons(controller: controller, announcement: a, onPlay: onPlay),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(a.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Pill(a.source.label, background: AppColors.lessonTint, foreground: AppColors.lessonText),
                  ],
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Anonstan önce ding-dong çalsın',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ding-dong', style: TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
                Switch(value: a.chime, onChanged: onChime),
              ],
            ),
          ),
          IconButton(
            tooltip: '${a.name} düzenle',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppColors.inkMuted),
          ),
          IconButton(
            tooltip: '${a.name} sil',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Details {
  const _Details(this.name, this.chime);
  final String name;
  final bool chime;
}

/// Ad ve dikkat sesi seçimi (ses dosyası ve kayıt için).
class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({required this.title, required this.initialName, this.initialChime = true});

  final String title;
  final String initialName;
  final bool initialChime;

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late bool _chime = widget.initialChime;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Anonsa bir ad verin');
      return;
    }
    Navigator.pop(context, _Details(name, _chime));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Anonsun adı', errorText: _error),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              _ChimeTile(value: _chime, onChanged: (v) => setState(() => _chime = v)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _save,
            child: const Text('Kaydet'),
          ),
        ],
      );
}

class _ChimeTile extends StatelessWidget {
  const _ChimeTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: value,
        onChanged: (v) => onChanged(v ?? true),
        title: const Text('Anonstan önce ding-dong çalsın'),
      );
}

/// Mikrofondan kayıt: başlat → durdur → dinle → adlandır ve kaydet.
class _RecordDialog extends StatefulWidget {
  const _RecordDialog({required this.controller});

  final AppController controller;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

enum _RecState { idle, recording, done }

class _RecordDialogState extends State<_RecordDialog> {
  /// Uzun kayıtlar ziller bekletildiği için sınırlı.
  static const maxLength = Duration(minutes: 3);

  AppController get c => widget.controller;
  final _name = TextEditingController(text: 'Anons');
  _RecState _state = _RecState.idle;
  String? _path;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  bool _chime = true;
  bool _saved = false;
  String? _error;

  static const _previewId = 'kayit-onizleme';

  @override
  void dispose() {
    _ticker?.cancel();
    _name.dispose();
    if (!_saved) unawaited(_discard());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    bool allowed;
    try {
      allowed = await c.recorder.hasPermission();
    } catch (_) {
      allowed = false;
    }
    if (!allowed) {
      if (mounted) {
        setState(() => _error = 'Mikrofona erişilemedi. Mikrofonun takılı olduğundan ve Windows Ayarlar → Gizlilik ve '
            'güvenlik → Mikrofon bölümünde masaüstü uygulamalarına izin verildiğinden emin olun.');
      }
      return;
    }
    await _discard();
    final path = c.newRecordingPath();
    try {
      await c.recorder.start(path);
    } catch (e) {
      if (mounted) setState(() => _error = 'Kayıt başlatılamadı: $e');
      return;
    }
    _path = path;
    _elapsed = Duration.zero;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= maxLength) _stop();
    });
    if (mounted) setState(() => _state = _RecState.recording);
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    String? result;
    try {
      result = await c.recorder.stop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Kayıt durdurulamadı: $e');
    }
    if (result != null) _path = result;
    final ok = _path != null && File(_path!).existsSync();
    if (!mounted) return;
    setState(() {
      _state = ok ? _RecState.done : _RecState.idle;
      if (!ok) _error ??= 'Kayıt alınamadı. Mikrofonu denetleyip yeniden deneyin.';
    });
  }

  /// Kaydı bırakır; dosyası silinir.
  Future<void> _discard() async {
    if (c.previewingSoundId == _previewId) await c.stopSound();
    if (_state == _RecState.recording) {
      _ticker?.cancel();
      try {
        await c.recorder.cancel();
      } catch (_) {}
    }
    final path = _path;
    _path = null;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Anonsa bir ad verin');
      return;
    }
    if (c.previewingSoundId == _previewId) await c.stopSound();
    try {
      final a = await c.addAnnouncementFromRecording(_path!, name: name, chime: _chime);
      if (a == null) {
        setState(() => _error = c.lastError ?? 'Anons kaydedilemedi.');
        return;
      }
    } catch (e) {
      setState(() => _error = 'Anons kaydedilemedi: $e');
      return;
    }
    _saved = true;
    if (mounted) Navigator.pop(context);
  }

  String get _clock =>
      '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => _build(context, previewing: c.previewingSoundId == _previewId),
    );
  }

  Widget _build(BuildContext context, {required bool previewing}) => AlertDialog(
        title: const Text('Mikrofondan anons kaydet'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _state == _RecState.recording ? Icons.fiber_manual_record : Icons.mic_none,
                    color: _state == _RecState.recording ? AppColors.danger : AppColors.inkSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    switch (_state) {
                      _RecState.idle => 'Hazır. "Kaydı başlat"a basıp konuşun.',
                      _RecState.recording => 'Kaydediliyor $_clock (en çok 3 dakika)',
                      _RecState.done => 'Kayıt tamam ($_clock). Dinleyip kaydedebilirsiniz.',
                    },
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (_state != _RecState.recording)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: AppColors.danger),
                      onPressed: _start,
                      icon: const Icon(Icons.fiber_manual_record),
                      label: Text(_state == _RecState.done ? 'Yeniden kaydet' : 'Kaydı başlat'),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Kaydı durdur'),
                    ),
                  if (_state == _RecState.done)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: previewing
                          ? c.stopSound
                          : () => c.previewSound(BellSound(id: _previewId, name: 'Kayıt', path: _path!)),
                      icon: Icon(previewing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(previewing ? 'Durdur' : 'Dinle'),
                    ),
                ],
              ),
              if (_state == _RecState.done) ...[
                const SizedBox(height: 16),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Anonsun adı')),
                const SizedBox(height: 8),
                _ChimeTile(value: _chime, onChanged: (v) => setState(() => _chime = v)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _discard();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _state == _RecState.done ? _save : null,
            child: const Text('Kaydet'),
          ),
        ],
      );
}

/// Yazıdan okunacak anons: ad, metin, dikkat sesi; kaydetmeden dinlenebilir.
class _SpeechDialog extends StatefulWidget {
  const _SpeechDialog({required this.controller, required this.turkishVoice, this.initial});

  final AppController controller;
  final Future<bool?> turkishVoice;
  final SpokenAnnouncement? initial;

  @override
  State<_SpeechDialog> createState() => _SpeechDialogState();
}

class _SpeechDialogState extends State<_SpeechDialog> {
  AppController get c => widget.controller;
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _text = TextEditingController(text: widget.initial?.text ?? '');
  late bool _chime = widget.initial?.chime ?? true;
  String? _error;

  static const _previewId = 'okuma-onizleme';

  @override
  void dispose() {
    if (c.announcementPlaying?.id == _previewId) unawaited(c.stopSound());
    c.clearSpeechFiles(_previewId);
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Okunacak metni yazın');
      return;
    }
    setState(() => _error = null);
    final error = await c.playAnnouncement(
      SpokenAnnouncement(
          id: _previewId, name: 'Deneme', source: AnnouncementSource.speech, text: text, chime: _chime),
      log: false,
    );
    if (error != null && mounted) setState(() => _error = error);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final text = _text.text.trim();
    if (name.isEmpty || text.isEmpty) {
      setState(() => _error = name.isEmpty ? 'Anonsa bir ad verin' : 'Okunacak metni yazın');
      return;
    }
    final initial = widget.initial;
    final ok = initial == null
        ? await c.addSpeechAnnouncement(name: name, text: text, chime: _chime) != null
        : await c.updateSpokenAnnouncement(initial.copyWith(name: name, text: text, chime: _chime));
    if (!ok) {
      if (mounted) setState(() => _error = c.lastError ?? 'Anons kaydedilemedi.');
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final previewing = c.announcementPlaying?.id == _previewId;
        return AlertDialog(
          title: Text(widget.initial == null ? 'Yazıdan okunan anons' : 'Anonsu düzenle'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  autofocus: widget.initial == null,
                  decoration: const InputDecoration(labelText: 'Anonsun adı', hintText: 'ör. Öğretmenler toplantısı'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _text,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Okunacak metin',
                    hintText: 'ör. Sayın öğretmenlerimiz, toplantı saat on beşte öğretmenler odasında yapılacaktır.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Sayıları ve saatleri yazıyla yazmak ("saat on beşte") daha doğal okunur.',
                    style: TextStyle(fontSize: 13, color: AppColors.inkMuted)),
                const SizedBox(height: 8),
                _ChimeTile(value: _chime, onChanged: (v) => setState(() => _chime = v)),
                FutureBuilder<bool?>(
                  future: widget.turkishVoice,
                  builder: (context, snapshot) => snapshot.data == false
                      ? const Padding(padding: EdgeInsets.only(top: 8), child: _NoTurkishVoiceNote())
                      : const SizedBox.shrink(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: previewing ? c.stopSound : _preview,
              icon: Icon(previewing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(previewing ? 'Durdur' : 'Dinle'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _save,
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }
}
