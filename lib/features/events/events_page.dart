import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/clock_time.dart';
import '../../core/date_utils.dart';
import '../../data/models/app_config.dart';
import '../../data/models/calendar.dart';
import '../../ui/theme.dart';
import '../../ui/time_field.dart';
import '../../ui/widgets.dart';

/// İstiklal Marşı, anma törenleri, anonslar: ders zillerinden bağımsız,
/// belirli gün ve saatte çalan sesler.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key, required this.controller});

  final AppController controller;

  static String describe(SpecialEvent e) {
    final when = switch (e.recurrence) {
      Recurrence.weekly => 'Her ${(e.weekdays.toList()..sort()).map((d) => turkishWeekdays[d - 1]).join(', ')}',
      Recurrence.yearly => 'Her yıl ${e.day} ${turkishMonths[(e.month ?? 1) - 1]}',
      Recurrence.once => e.date == null ? 'Tek sefer' : '${e.date!.day} ${turkishMonths[e.date!.month - 1]} ${e.date!.year}',
    };
    return '$when, saat ${e.time}';
  }

  /// Hazır etkinlikler; saatler okulun programından tahmin edilir, kişi
  /// pencerede düzeltebilir.
  List<(String, SpecialEvent)> _presets() {
    final config = controller.config;
    final monday = config.templateById(config.weekPlan[DateTime.monday] ?? '');
    final friday = config.templateById(config.weekPlan[DateTime.friday] ?? '');
    final mondayStart = monday?.assemblyTime ?? monday?.lessons.firstOrNull?.start.tryAddMinutes(-10);
    final fridayEnd = friday?.lessons.lastOrNull?.end;
    String id() => 'e${DateTime.now().microsecondsSinceEpoch}';
    return [
      (
        'İstiklal Marşı · Pazartesi sabah',
        SpecialEvent(
          id: id(),
          name: 'İstiklal Marşı (Pazartesi)',
          time: mondayStart?.tryAddMinutes(2) ?? const ClockTime(8, 32),
          recurrence: Recurrence.weekly,
          weekdays: {DateTime.monday},
        ),
      ),
      (
        'İstiklal Marşı · Cuma çıkış',
        SpecialEvent(
          id: id(),
          name: 'İstiklal Marşı (Cuma)',
          time: fridayEnd?.tryAddMinutes(1) ?? const ClockTime(14, 16),
          recurrence: Recurrence.weekly,
          weekdays: {DateTime.friday},
        ),
      ),
      (
        '10 Kasım saygı duruşu',
        config.specialEvents.where((e) => e.id == '10-kasim').firstOrNull ??
            SpecialEvent(
              id: '10-kasim',
              name: '10 Kasım saygı duruşu',
              time: const ClockTime(9, 5),
              recurrence: Recurrence.yearly,
              month: 11,
              day: 10,
              soundId: 'alarm',
              loopSeconds: 60,
            ),
      ),
    ];
  }

  Future<void> _open(BuildContext context, {SpecialEvent? initial, bool isNew = false}) async {
    final event = await showDialog<SpecialEvent>(
      context: context,
      builder: (_) => EventDialog(
        config: controller.config,
        today: dateOnly(controller.now()),
        initial: initial,
        isNew: isNew,
      ),
    );
    if (event != null) await controller.saveEvent(event);
  }

  Future<void> _delete(BuildContext context, SpecialEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${e.name}" silinsin mi?'),
        content: const Text('Geçici olarak durdurmak için silmek yerine anahtarı kapatabilirsiniz.'),
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
    if (ok == true) await controller.deleteEvent(e.id);
  }

  Future<void> _test(BuildContext context, SpecialEvent e) async {
    final note = await controller.testEvent(e);
    if (note != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.config;
        final events = [...config.specialEvents]..sort((a, b) => a.time.compareTo(b.time));
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Özel etkinlikler',
                subtitle: const Text('İstiklal Marşı, anma törenleri ve anonslar. Yalnızca zil programı olan günlerde çalar.'),
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
                      onPressed: () => _open(context, isNew: true),
                      icon: const Icon(Icons.add),
                      label: const Text('Etkinlik ekle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionCard(
                title: 'Hazır etkinlikler',
                subtitle: 'Tıklayınca saat ve günleri doldurulmuş olarak açılır; kaydetmeden önce kontrol edin.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, preset) in _presets())
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(label),
                        onPressed: () => _open(context, initial: preset, isNew: !config.specialEvents.any((e) => e.id == preset.id)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionCard(
                title: 'Etkinlikler',
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    if (events.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Henüz etkinlik yok. Yukarıdaki hazır etkinliklerden başlayabilirsiniz.',
                            style: TextStyle(color: AppColors.inkMuted)),
                      ),
                    for (final e in events)
                      _EventRow(
                        event: e,
                        soundName: e.soundId != null && config.soundById(e.soundId!) != null
                            ? config.soundById(e.soundId!)!.name
                            : '${config.soundFor(e.toBellEvent())?.name ?? 'Klasik zil'} (varsayılan)',
                        onToggle: (on) => controller.setEventEnabled(e.id, on),
                        onTest: () => _test(context, e),
                        onEdit: () => _open(context, initial: e),
                        onDelete: () => _delete(context, e),
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

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.soundName,
    required this.onToggle,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  final SpecialEvent event;
  final String soundName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          Switch(value: e.enabled, onChanged: onToggle),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Opacity(
                opacity: e.enabled ? 1 : 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${EventsPage.describe(e)} · $soundName'
                      '${e.loopSeconds == null ? '' : ' · ${e.loopSeconds} sn'}',
                      style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!e.enabled) const Pill('Kapalı', background: AppColors.neutralTint, foreground: AppColors.inkSecondary),
          TextButton.icon(onPressed: onTest, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Dene')),
          IconButton(tooltip: '${e.name} düzenle', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: AppColors.inkMuted)),
          IconButton(tooltip: '${e.name} sil', onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

/// Etkinlik ekleme/düzenleme penceresi; kaydedilince [SpecialEvent] döner.
class EventDialog extends StatefulWidget {
  const EventDialog({super.key, required this.config, required this.today, this.initial, this.isNew = false});

  final AppConfig config;
  final DateTime today;
  final SpecialEvent? initial;

  /// Hazır etkinlikten açıldıysa da yenidir (başlık "Etkinlik ekle" olur).
  final bool isNew;

  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  late final SpecialEvent? i = widget.initial;
  late final _name = TextEditingController(text: i?.name ?? '');
  late ClockTime _time = i?.time ?? const ClockTime(9, 0);
  late Recurrence _recurrence = i?.recurrence ?? Recurrence.weekly;
  late Set<int> _weekdays = {...?i?.weekdays};
  late int _month = i?.month ?? widget.today.month;
  late int _day = i?.day ?? widget.today.day;
  late DateTime _date = i?.date ?? widget.today;
  late String? _soundId = i?.soundId;
  late int? _loopSeconds = i?.loopSeconds;
  late final bool _enabled = i?.enabled ?? true;
  String? _error;

  static const _loopOptions = [15, 30, 60, 90, 120];
  static const _short = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _clashesWithBell =>
      widget.config.templates.any((t) => t.generateBells().any((b) => b.time == _time));

  void _save() {
    final name = _name.text.trim();
    String? error;
    if (name.isEmpty) {
      error = 'Etkinliğe bir ad verin';
    } else if (_recurrence == Recurrence.weekly && _weekdays.isEmpty) {
      error = 'En az bir gün seçin';
    } else if (_recurrence == Recurrence.yearly && DateTime(2024, _month, _day).month != _month) {
      error = '${turkishMonths[_month - 1]} ayında $_day. gün yok';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      SpecialEvent(
        id: i?.id ?? 'e${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        time: _time,
        recurrence: _recurrence,
        weekdays: _recurrence == Recurrence.weekly ? _weekdays : const {},
        month: _recurrence == Recurrence.yearly ? _month : null,
        day: _recurrence == Recurrence.yearly ? _day : null,
        date: _recurrence == Recurrence.once ? _date : null,
        soundId: _soundId,
        loopSeconds: _loopSeconds,
        enabled: _enabled,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(widget.today.year - 1),
      lastDate: DateTime(widget.today.year + 3, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final sounds = widget.config.sounds;
    final soundValue = sounds.any((s) => s.id == _soundId) ? _soundId : null;
    const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary);
    return AlertDialog(
      title: Text(widget.isNew || i == null ? 'Etkinlik ekle' : 'Etkinliği düzenle'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: i == null,
                decoration: const InputDecoration(labelText: 'Etkinliğin adı', hintText: 'İstiklal Marşı'),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saat', style: label),
                      const SizedBox(height: 6),
                      TimeField(value: _time, semanticLabel: 'Etkinlik saati', onChanged: (v) => setState(() => _time = v)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SegmentedButton<Recurrence>(
                      segments: const [
                        ButtonSegment(value: Recurrence.weekly, label: Text('Her hafta')),
                        ButtonSegment(value: Recurrence.yearly, label: Text('Her yıl')),
                        ButtonSegment(value: Recurrence.once, label: Text('Tek sefer')),
                      ],
                      selected: {_recurrence},
                      onSelectionChanged: (s) => setState(() {
                        _recurrence = s.first;
                        _error = null;
                      }),
                    ),
                  ),
                ],
              ),
              if (_clashesWithBell) ...[
                const SizedBox(height: 8),
                const Text(
                  'Bu saatte bir ders zili de çalıyor; etkinlik sesi zilin hemen ardından başlar ve onu keser.',
                  style: TextStyle(fontSize: 13, color: AppColors.lunchText),
                ),
              ],
              const SizedBox(height: 16),
              switch (_recurrence) {
                Recurrence.weekly => Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(_short[d - 1]),
                          selected: _weekdays.contains(d),
                          onSelected: (on) => setState(() {
                            _weekdays = on ? {..._weekdays, d} : (_weekdays.toSet()..remove(d));
                            _error = null;
                          }),
                        ),
                    ],
                  ),
                Recurrence.yearly => Row(
                    children: [
                      DropdownButton<int>(
                        value: _day,
                        onChanged: (v) => setState(() => _day = v ?? _day),
                        items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _month,
                        onChanged: (v) => setState(() => _month = v ?? _month),
                        items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(turkishMonths[m - 1]))],
                      ),
                    ],
                  ),
                Recurrence.once => Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(formatTurkishDate(_date)),
                    ),
                  ),
              },
              const SizedBox(height: 20),
              const Text('Ses', style: label),
              DropdownButton<String?>(
                isExpanded: true,
                value: soundValue,
                onChanged: (v) => setState(() => _soundId = v),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Varsayılan etkinlik sesi')),
                  for (final s in sounds) DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
              ),
              const Text(
                'İstiklal Marşı gibi kayıtları önce "Zil sesleri" sayfasından ekleyin.',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              const Text('Çalma', style: label),
              DropdownButton<int?>(
                isExpanded: true,
                value: _loopOptions.contains(_loopSeconds) ? _loopSeconds : null,
                onChanged: (v) => setState(() => _loopSeconds = v),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Bir kez çal')),
                  for (final s in _loopOptions) DropdownMenuItem(value: s, child: Text('$s saniye boyunca tekrarla')),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
