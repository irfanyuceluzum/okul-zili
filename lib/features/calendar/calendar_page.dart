import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/date_utils.dart';
import '../../data/models/calendar.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Tatilleri, özel günleri ve etkinlikleri listeler; tatiller eklenip
/// düzenlenebilir. Aylık takvim görünümü sonraki adımda.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.controller});

  final AppController controller;

  Future<void> _addHoliday(BuildContext context) async {
    final holiday = await showDialog<Holiday>(
      context: context,
      builder: (_) => HolidayDialog(today: dateOnly(controller.now())),
    );
    if (holiday != null) await controller.saveHoliday(holiday);
  }

  Future<void> _editHoliday(BuildContext context, Holiday existing) async {
    final holiday = await showDialog<Holiday>(
      context: context,
      builder: (_) => HolidayDialog(today: dateOnly(controller.now()), initial: existing),
    );
    if (holiday != null) await controller.saveHoliday(holiday, replacing: existing);
  }

  Future<void> _deleteHoliday(BuildContext context, Holiday holiday) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tatil silinsin mi?'),
        content: Text('"${holiday.name}" silinirse o günlerde zil normal programa göre çalar.'),
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
    if (ok == true) await controller.deleteHoliday(holiday);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.config;
        final today = dateOnly(controller.now());
        final holidays = [...config.holidays]..sort((a, b) => a.start.compareTo(b.start));
        final overrides = [...config.overrides]..sort((a, b) => a.date.compareTo(b.date));
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Takvim ve tatiller',
                subtitle: const Text('Tatillerde ve "zil yok" seçilen günlerde zil çalmaz.'),
                trailing: FilledButton.icon(
                  onPressed: () => _addHoliday(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Tatil ekle'),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: AppColors.recessTint, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.recessText, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ara tatiller, yarıyıl tatili ve dinî bayramları MEB çalışma takvimine göre '
                        '"Tatil ekle" ile girin. Birden çok günlük tatiller için başlangıç ve bitiş günü seçin.',
                        style: TextStyle(color: AppColors.recessText, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SectionCard(
                      title: 'Tatiller',
                      subtitle: 'Düzenlemek için bir satıra tıklayın',
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        children: [
                          if (holidays.isEmpty) const _Empty('Henüz tatil eklenmedi'),
                          for (final h in holidays)
                            _HolidayRow(
                              holiday: h,
                              today: today,
                              onEdit: () => _editHoliday(context, h),
                              onDelete: () => _deleteHoliday(context, h),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionCard(
                          title: 'Özel günler',
                          subtitle: 'Farklı program ya da zil çalmayan günler',
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                          child: Column(
                            children: [
                              if (overrides.isEmpty) const _Empty('Özel gün yok'),
                              for (final o in overrides)
                                _row(
                                  _date(o.date),
                                  o.note ?? '',
                                  o.templateId == null
                                      ? const Pill('Zil yok', background: AppColors.okTint, foreground: AppColors.okText)
                                      : Pill(config.templateById(o.templateId!)?.name ?? o.templateId!,
                                          background: AppColors.lunchTint, foreground: AppColors.lunchText),
                                  past: o.date.isBefore(today),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SectionCard(
                          title: 'Etkinlikler',
                          subtitle: 'İstiklal Marşı, anma törenleri, anonslar',
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                          child: Column(
                            children: [
                              if (config.specialEvents.isEmpty) const _Empty('Etkinlik yok'),
                              for (final e in config.specialEvents)
                                _row(
                                  _recurrence(e),
                                  '${e.name} · ${e.time}',
                                  e.enabled
                                      ? const Pill('Açık', background: AppColors.okTint, foreground: AppColors.okText)
                                      : const Pill('Kapalı', background: AppColors.neutralTint, foreground: AppColors.inkSecondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _row(String date, String text, Widget trailing, {bool past = false}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Opacity(
        opacity: past ? 0.5 : 1,
        child: Row(
          children: [
            SizedBox(width: 150, child: Text(date, style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(child: Text(text)),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  static String _recurrence(SpecialEvent e) => switch (e.recurrence) {
        Recurrence.once => e.date == null ? 'Tek sefer' : _date(e.date!),
        Recurrence.yearly => 'Her yıl ${e.day} ${turkishMonths[(e.month ?? 1) - 1]}',
        Recurrence.weekly => 'Her ${(e.weekdays.toList()..sort()).map((d) => turkishWeekdays[d - 1]).join(', ')}',
      };
}

String _date(DateTime d) => '${d.day} ${turkishMonths[d.month - 1]} ${d.year}';

String _range(DateTime start, DateTime end) {
  if (start == end) return _date(start);
  if (start.year == end.year && start.month == end.month) {
    return '${start.day}–${end.day} ${turkishMonths[end.month - 1]} ${end.year}';
  }
  return '${_date(start)} – ${_date(end)}';
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({required this.holiday, required this.today, required this.onEdit, required this.onDelete});

  final Holiday holiday;
  final DateTime today;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final h = holiday;
    final current = h.contains(today);
    final past = h.end.isBefore(today);
    final days = h.end.difference(h.start).inDays + 1;
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: InkWell(
        onTap: onEdit,
        child: Opacity(
          opacity: past ? 0.5 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                SizedBox(
                  width: 190,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_range(h.start, h.end), style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (days > 1) Text('$days gün', style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
                    ],
                  ),
                ),
                Expanded(child: Text(h.name)),
                const SizedBox(width: 8),
                current
                    ? const Pill('Bugün', background: AppColors.lesson, foreground: Colors.white)
                    : const Pill('Tatil', background: AppColors.okTint, foreground: AppColors.okText),
                IconButton(
                  tooltip: '${h.name} tatilini sil',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text, style: const TextStyle(color: AppColors.inkMuted)),
      );
}

/// Tatil ekleme/düzenleme penceresi; kaydedilince [Holiday] döner.
class HolidayDialog extends StatefulWidget {
  const HolidayDialog({super.key, required this.today, this.initial});

  final DateTime today;
  final Holiday? initial;

  @override
  State<HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<HolidayDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late DateTime _start = widget.initial?.start ?? widget.today;
  late DateTime _end = widget.initial?.end ?? widget.today;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(widget.today.year - 1),
      lastDate: DateTime(widget.today.year + 3, 12, 31),
      helpText: start ? 'Tatilin ilk günü' : 'Tatilin son günü',
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
        if (_end.isBefore(_start)) _start = _end;
      }
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Tatilin adını yazın');
      return;
    }
    Navigator.pop(context, Holiday(name: name, start: _start, end: _end));
  }

  @override
  Widget build(BuildContext context) {
    final days = _end.difference(_start).inDays + 1;
    return AlertDialog(
      title: Text(widget.initial == null ? 'Tatil ekle' : 'Tatili düzenle'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Tatilin adı', hintText: 'Ara tatil', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _DateField(label: 'İlk gün', date: _start, onTap: () => _pick(start: true))),
                const SizedBox(width: 12),
                Expanded(child: _DateField(label: 'Son gün', date: _end, onTap: () => _pick(start: false))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              days == 1 ? 'Tek gün: bu gün zil çalmaz.' : '$days gün boyunca zil çalmaz.',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
            ),
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
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), alignment: Alignment.centerLeft),
            onPressed: onTap,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text('${_date(date)}\n${turkishWeekdays[date.weekday - 1]}',
                style: const TextStyle(height: 1.2)),
          ),
        ],
      );
}
