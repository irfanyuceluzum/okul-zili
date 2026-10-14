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
    final usages = controller.soundUsages(sound.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${sound.name}" silinsin mi?'),
        content: Text(usages.isEmpty
            ? 'Bu ses hiçbir yerde kullanılmıyor.'
            : 'Şu yerlerde kullanılıyor: ${usages.join(', ')}. Silinirse bunlarda klasik zil çalar.'),
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
    if (ok == true) await controller.deleteSound(sound);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.config;
        final assignments = SectionCard(
          title: 'Hangi zilde hangi ses çalsın?',
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              for (final (type, hint) in _types) _AssignmentRow(controller: controller, type: type, hint: hint, onPreview: (s) => _preview(context, s)),
            ],
          ),
        );
        final files = SectionCard(
          title: 'Ses dosyaları',
          subtitle: 'Desteklenen biçimler: ${supportedAudioExtensions.join(', ')}. '
              'Dosya uygulamanın klasörüne kopyalanır; asıl dosyayı silseniz de zil çalar.',
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              for (final sound in config.sounds)
                _SoundRow(
                  sound: sound,
                  usages: controller.soundUsages(sound.id),
                  onPreview: () => _preview(context, sound),
                  onRename: sound.isAsset ? null : () => _rename(context, sound),
                  onDelete: sound.isAsset ? null : () => _delete(context, sound),
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
                    children: [assignments, const SizedBox(height: 24), files],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: assignments),
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
    final current = config.soundById(assigned ?? '') ??
        (type == BellType.emergency ? config.soundById('alarm') : null) ??
        config.sounds.firstOrNull;
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
          if (current != null)
            DropdownButton<String>(
              value: current.id,
              onChanged: (id) {
                if (id != null) controller.setSoundForType(type, id);
              },
              items: [
                for (final s in config.sounds) DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
            ),
          IconButton(
            tooltip: '${type.label} sesini dinle',
            onPressed: current == null ? null : () => onPreview(current),
            icon: const Icon(Icons.play_arrow_rounded, color: AppColors.lesson),
          ),
        ],
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.sound,
    required this.usages,
    required this.onPreview,
    required this.onRename,
    required this.onDelete,
  });

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
          IconButton(
            tooltip: '${sound.name} dinle',
            onPressed: onPreview,
            icon: const Icon(Icons.play_circle_outline, color: AppColors.lesson),
          ),
          const SizedBox(width: 4),
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
