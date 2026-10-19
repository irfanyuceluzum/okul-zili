import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../data/models/app_config.dart';
import '../../data/models/bell_event.dart';
import '../../platform/audio_file_picker.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Okulun kendi ses dosyalarını yükleme ve zil türlerine ses atama.
class SoundsPage extends StatelessWidget {
  const SoundsPage({super.key, required this.controller});

  final AppController controller;

  /// Atama listesinde gösterilen zil türleri ve açıklamaları.
  static const _types = [
    (BellType.assembly, 'Sabah toplanma'),
    (BellType.teacher, 'Dersten birkaç dakika önce'),
    (BellType.lessonStart, 'Ders başlarken'),
    (BellType.lessonEnd, 'Ders biterken'),
    (BellType.dayEnd, 'Son ders bitince'),
    (BellType.special, 'Kendi sesi seçilmemiş etkinlikler'),
    (BellType.manual, '"Şimdi zil çal" düğmesi'),
    (BellType.emergency, '"Acil durum alarmı" düğmesi'),
  ];

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _preview(BuildContext context, BellSound sound) async {
    final note = await controller.previewSound(sound);
    if (note != null && context.mounted) _snack(context, note);
  }

  Future<void> _add(BuildContext context) async {
    final path = await controller.pickAudioFile();
    if (path == null || !context.mounted) return;
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    if (!supportedAudioExtensions.contains(ext)) {
      _snack(context, 'Bu dosya biçimi desteklenmiyor. Şunlardan birini seçin: ${supportedAudioExtensions.join(', ')}');
      return;
    }
    try {
      final sound = await controller.importSound(path);
      if (context.mounted) _snack(context, '"${sound.name}" eklendi. Dinleyip bir zil türüne atayabilirsiniz.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Dosya kopyalanamadı: $e');
    }
  }

  /// Klasördeki sesleri tek seferde yükler ve ne yapıldığını anlatır.
  Future<void> _importPack(BuildContext context) async {
    final path = await controller.pickSoundFolder();
    if (path == null || !context.mounted) return;
    final result = await controller.importSoundPack(path);
    if (!context.mounted) return;
    final event = controller.config.specialEvents.where((e) => e.id == '10-kasim').firstOrNull;
    final lines = <String>[
      if (result.error != null) result.error!,
      if (result.added.isNotEmpty) 'Eklenen: ${result.added.join(', ')}.',
      if (result.kept.isNotEmpty) 'Zaten yüklüydü: ${result.kept.join(', ')}.',
      if (result.failed.isNotEmpty) 'Kopyalanamadı: ${result.failed.join(', ')}.',
      if (result.error == null && result.ceremonies.isNotEmpty)
        'Ana ekrandaki Tören düğmesinden çalınabilir: ${result.ceremonies.map((c) => c.label).join(', ')}.',
      if (result.remembranceEventUpdated)
        '10 Kasım saygı duruşu etkinliği siren yerine "${Ceremony.remembrance.label}" kaydını çalacak.'
            '${event != null && !event.enabled ? ' Etkinlik şu an kapalı; Özel etkinlikler sayfasından açabilirsiniz.' : ''}',
      if (result.error == null) 'Hangi zilde hangi zil sesinin çalacağını bu sayfadaki listeden seçin.',
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.error == null ? 'Ses paketi yüklendi' : 'Ses paketi yüklenemedi'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, BellSound sound) async {
    final text = TextEditingController(text: sound.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sesin adını değiştir'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: text,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Ad'),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name != null && name.trim().isNotEmpty) await controller.renameSound(sound, name.trim());
  }

  Future<void> _delete(BuildContext context, BellSound sound) async {
    final config = controller.config;
    final usages = controller.soundUsages(sound.id);
    // Acil durum dışındaki zillerde kullanılıyorsa yerine çalacak ses seçilir.
    final usedByBells = config.soundForType.entries.any((e) => e.value == sound.id && e.key != BellType.emergency);
    final others = config.sounds.where((s) => s.id != sound.id).toList();
    String? replacement = others.any((s) => s.id == AppController.fallbackBell.id)
        ? AppController.fallbackBell.id
        : others.firstOrNull?.id;
    const muted = TextStyle(fontSize: 13, color: AppColors.inkSecondary);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('"${sound.name}" silinsin mi?'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usages.isEmpty ? 'Bu ses hiçbir yerde kullanılmıyor.' : 'Şu yerlerde kullanılıyor: ${usages.join(', ')}.'),
                if (usedByBells && others.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Bu zillerde yerine çalacak ses:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: SoftDropdown<String>(
                          isExpanded: true,
                          value: replacement,
                          onChanged: (v) => setState(() => replacement = v),
                          items: [for (final o in others) DropdownMenuItem(value: o.id, child: Text(o.name))],
                        ),
                      ),
                    ],
                  ),
                ],
                if (usedByBells && others.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Başka ses kalmadığı için zillerde uygulamanın içindeki klasik zil çalar.'),
                ],
                if (config.soundForType[BellType.emergency] == sound.id) ...[
                  const SizedBox(height: 8),
                  const Text('Acil durum alarmında siren çalar.', style: muted),
                ],
                if (sound.isAsset) ...[
                  const SizedBox(height: 12),
                  const Text('Hazır ses yalnız listeden kaldırılır; "Hazır sesleri geri getir" ile yeniden ekleyebilirsiniz.',
                      style: muted),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await controller.deleteSound(sound, replacementId: usedByBells ? replacement : null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.config;
        final assignments = SectionCard(
          title: 'Hangi zilde hangi ses çalsın?',
          icon: Icons.tune_rounded,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              for (final (type, hint) in _types) _AssignmentRow(controller: controller, type: type, hint: hint, onPreview: (s) => _preview(context, s)),
            ],
          ),
        );
        final ceremonies = SectionCard(
          title: 'Tören kayıtları',
          icon: Icons.flag_outlined,
          subtitle: 'Ana ekrandaki Tören düğmesi bu kayıtları bir kez çalar. Kayıtlar uygulamayla gelmez; '
              '"Ses paketi yükle…" ile yükleyin.',
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              for (final (kind, hint) in const [
                (Ceremony.anthem, 'Bayrak töreni'),
                (Ceremony.remembrance, '10 Kasım ve anma törenleri'),
              ])
                _CeremonyRow(controller: controller, kind: kind, hint: hint, onPreview: (s) => _preview(context, s)),
            ],
          ),
        );
        final settingsColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [assignments, const SizedBox(height: 24), ceremonies],
        );
        final missing = controller.missingBuiltInSounds;
        final files = SectionCard(
          title: 'Ses dosyaları',
          icon: Icons.library_music_outlined,
          trailing: missing.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: controller.restoreBuiltInSounds,
                  icon: const Icon(Icons.restore),
                  label: const Text('Hazır sesleri geri getir'),
                ),
          subtitle: 'Desteklenen biçimler: ${supportedAudioExtensions.join(', ')}. '
              'Dosya uygulamanın klasörüne kopyalanır; asıl dosyayı silseniz de zil çalar.',
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              for (final sound in config.sounds)
                _SoundRow(
                  controller: controller,
                  sound: sound,
                  usages: controller.soundUsages(sound.id),
                  onPreview: () => _preview(context, sound),
                  onRename: sound.isAsset ? null : () => _rename(context, sound),
                  onDelete: () => _delete(context, sound),
                ),
            ],
          ),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Zil sesleri',
                subtitle: const Text('Okulunuzun kendi zil sesini yükleyin ve her zil türüne ses atayın.'),
                trailing: Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: controller.stopSound,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Sesi durdur'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _importPack(context),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Ses paketi yükle…'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _add(context),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Ses dosyası ekle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < 1000) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [settingsColumn, const SizedBox(height: 24), files],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: settingsColumn),
                    const SizedBox(width: 24),
                    Expanded(child: files),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.controller, required this.type, required this.hint, required this.onPreview});

  final AppController controller;
  final BellType type;
  final String hint;
  final ValueChanged<BellSound> onPreview;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    final assigned = config.soundForType[type];
    final current = config.soundById(assigned ?? '') ?? (type == BellType.emergency ? config.soundById('alarm') : null);
    // Atanan ses listeden silinmişse uygulamanın içindeki yedek çalar.
    final builtIn = type == BellType.emergency ? AppController.fallbackAlarm : AppController.fallbackBell;
    final plays = current ?? builtIn;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
              ],
            ),
          ),
          SoftDropdown<String>(
            value: current?.id,
            hint: Text('${builtIn.name} (yerleşik)'),
            onChanged: (id) {
              if (id != null) controller.setSoundForType(type, id);
            },
            items: [
              for (final s in config.sounds) DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
          ),
          PlaybackButtons(controller: controller, sound: plays, label: type.label, onPlay: () => onPreview(plays)),
        ],
      ),
    );
  }
}

class _CeremonyRow extends StatelessWidget {
  const _CeremonyRow({required this.controller, required this.kind, required this.hint, required this.onPreview});

  final AppController controller;
  final Ceremony kind;
  final String hint;
  final ValueChanged<BellSound> onPreview;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    final current = config.ceremonySound(kind);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kind.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
              ],
            ),
          ),
          SoftDropdown<String?>(
            value: current?.id,
            onChanged: (id) => controller.setCeremonySound(kind, id),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Seçilmedi')),
              for (final s in config.sounds.where((s) => !s.isAsset))
                DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
            ],
          ),
          if (current != null) PlaybackButtons(controller: controller, sound: current, label: kind.label, onPlay: () => onPreview(current)),
        ],
      ),
    );
  }
}

/// Sesin yanında oynat / duraklat-sürdür / durdur düğmeleri. [label] ipucu
/// metinlerinde kullanılır (ör. "Giriş zili dinle").
class PlaybackButtons extends StatelessWidget {
  const PlaybackButtons({super.key, required this.controller, required this.sound, required this.label, required this.onPlay});

  final AppController controller;
  final BellSound sound;
  final String label;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final active = controller.previewingSoundId == sound.id;
    final playing = active && !controller.previewPaused;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: playing ? '$label duraklat' : (active ? '$label sürdür' : '$label dinle'),
          onPressed: playing ? controller.pausePreview : (active ? controller.resumePreview : onPlay),
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.lesson),
        ),
        IconButton(
          tooltip: '$label durdur',
          onPressed: active ? controller.stopSound : null,
          icon: Icon(Icons.stop_rounded, color: active ? AppColors.ink : AppColors.lineStrong),
        ),
      ],
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.controller,
    required this.sound,
    required this.usages,
    required this.onPreview,
    required this.onRename,
    required this.onDelete,
  });

  final AppController controller;
  final BellSound sound;
  final List<String> usages;
  final VoidCallback onPreview;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          PlaybackButtons(controller: controller, sound: sound, label: sound.name, onPlay: onPreview),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(sound.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    sound.isAsset
                        ? const Pill('Hazır', background: AppColors.neutralTint, foreground: AppColors.inkSecondary)
                        : const Pill('Yüklenen', background: AppColors.lessonTint, foreground: AppColors.lessonText),
                  ],
                ),
                Text(
                  usages.isEmpty ? 'Kullanılmıyor' : usages.join(' · '),
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                ),
              ],
            ),
          ),
          if (onRename != null)
            IconButton(
              tooltip: '${sound.name} adını değiştir',
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined, color: AppColors.inkMuted),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: '${sound.name} sil',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.inkMuted),
            ),
        ],
      ),
    );
  }
}
