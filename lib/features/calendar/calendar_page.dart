import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/date_utils.dart';
import '../../data/models/calendar.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Aylık takvim: her günün zil durumu renkle gösterilir; bir güne tıklayıp o
/// gün için farklı program ya da "zil yok" seçilir. Tatiller de buradan
/// eklenir. Değişiklikler hemen kaydedilir.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selected = dateOnly(widget.controller.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);

  AppController get c => widget.controller;

  void _select(DateTime day) => setState(() {
        _selected = dateOnly(day);
        _month = DateTime(day.year, day.month);
      });

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _addHoliday() async {
    final holiday = await showDialog<Holiday>(
      context: context,
      builder: (_) => HolidayDialog(today: _selected),
    );
    if (holiday != null) await c.saveHoliday(holiday);
  }

  Future<void> _editHoliday(Holiday existing) async {
    final holiday = await showDialog<Holiday>(
      context: context,
      builder: (_) => HolidayDialog(today: dateOnly(c.now()), initial: existing),
    );
    if (holiday != null) await c.saveHoliday(holiday, replacing: existing);
  }

  Future<void> _deleteHoliday(Holiday holiday) async {
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
    if (ok == true) await c.deleteHoliday(holiday);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final today = dateOnly(c.now());
        final grid = _MonthGrid(
          controller: c,
          month: _month,
          today: today,
          selected: _selected,
          onSelect: _select,
        );
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DayPanel(key: ValueKey(_selected), controller: c, day: _selected),
            const SizedBox(height: 24),
            _HolidayList(
              controller: c,
              today: today,
              onEdit: _editHoliday,
              onDelete: _deleteHoliday,
              onShow: (h) => _select(h.start),
            ),
          ],
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Takvim ve tatiller',
                subtitle: const Text('Bir güne tıklayıp o gün için farklı program seçin.'),
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton.outlined(
                      tooltip: 'Önceki ay',
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        '${turkishMonths[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Sonraki ay',
                      onPressed: () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _select(today),
                      child: const Text('Bugün'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _addHoliday,
                      icon: const Icon(Icons.add),
                      label: const Text('Tatil ekle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 1000) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [grid, const SizedBox(height: 24), side],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 20, child: grid),
                    const SizedBox(width: 24),
                    Expanded(flex: 11, child: side),
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

/// Bir günün takvimdeki görünümü.
enum _DayKind { school, weekend, holiday, off, special }

class _DayInfo {
  _DayInfo(this.kind, this.label);

  final _DayKind kind;
  final String label;

  static _DayInfo of(AppController c, DateTime day) {
    final override = c.overrideOn(day);
    if (override != null) {
      if (override.templateId == null) return _DayInfo(_DayKind.off, override.note ?? 'Zil yok');
      final t = c.config.templateById(override.templateId!);
      return _DayInfo(_DayKind.special, t?.name ?? 'Silinmiş şablon');
    }
    final holiday = c.holidayOn(day);
    if (holiday != null) return _DayInfo(_DayKind.holiday, holiday.name);
    final templateId = c.config.weekPlan[day.weekday];
    if (templateId == null || c.config.templateById(templateId) == null) return _DayInfo(_DayKind.weekend, '');
    return _DayInfo(_DayKind.school, '');
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.controller,
    required this.month,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final AppController controller;
  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + daysInMonth) / 7).ceil();
    const short = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final d in short)
                  Expanded(
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var r = 0; r < rows; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    for (var col = 0; col < 7; col++) ...[
                      if (col > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _DayCell(
                          controller: controller,
                          day: DateTime(month.year, month.month, 1 + r * 7 + col - offset),
                          inMonth: (1 + r * 7 + col - offset) >= 1 && (1 + r * 7 + col - offset) <= daysInMonth,
                          today: today,
                          selected: selected,
                          onSelect: onSelect,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Legend(AppColors.surface, AppColors.lineStrong, 'Okul günü'),
                _Legend(AppColors.neutralTint, AppColors.neutralTint, 'Hafta sonu'),
                _Legend(AppColors.okTint, AppColors.ok, 'Tatil / zil yok'),
                _Legend(AppColors.lunchTint, AppColors.lunch, 'Farklı program'),
                _Legend(AppColors.lesson, AppColors.lesson, 'Bugün', round: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.controller,
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final AppController controller;
  final DateTime day;
  final bool inMonth;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final info = _DayInfo.of(controller, day);
    final (bg, border, fg) = switch (info.kind) {
      _DayKind.weekend => (AppColors.neutralTint, AppColors.neutralTint, AppColors.inkMuted),
      _DayKind.holiday || _DayKind.off => (AppColors.okTint, AppColors.ok, AppColors.okText),
      _DayKind.special => (AppColors.lunchTint, AppColors.lunch, AppColors.lunchText),
      _DayKind.school => (AppColors.surface, AppColors.line, AppColors.ink),
    };
    final isToday = isSameDay(day, today);
    final isSelected = isSameDay(day, selected);
    final description = [
      '${day.day} ${turkishMonths[day.month - 1]} ${turkishWeekdays[day.weekday - 1]}',
      if (info.label.isNotEmpty) info.label,
      if (info.kind == _DayKind.weekend) 'zil yok',
    ].join(', ');

    return Opacity(
      opacity: inMonth ? 1 : 0.4,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: description,
        excludeSemantics: true,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? const BorderSide(color: AppColors.lesson, width: 3)
                : BorderSide(color: border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(day),
            child: SizedBox(
              height: 84,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: isToday ? const BoxDecoration(color: AppColors.lesson, shape: BoxShape.circle) : null,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isToday ? Colors.white : fg,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (info.label.isNotEmpty)
                      Text(
                        info.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: fg),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.fill, this.border, this.label, {this.round = false});

  final Color fill;
  final Color border;
  final String label;
  final bool round;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(round ? 7 : 4),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
        ],
      );
}

/// Seçili günün durumu ve o gün için program seçimi.
class _DayPanel extends StatefulWidget {
  const _DayPanel({super.key, required this.controller, required this.day});

  final AppController controller;
  final DateTime day;

  @override
  State<_DayPanel> createState() => _DayPanelState();
}

class _DayPanelState extends State<_DayPanel> {
  static const _default = '__haftalik__';
  static const _off = '__zil_yok__';

  late final _note = TextEditingController(text: widget.controller.overrideOn(widget.day)?.note ?? '');

  AppController get c => widget.controller;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _current() {
    final o = c.overrideOn(widget.day);
    if (o == null) return _default;
    return o.templateId ?? _off;
  }

  Future<void> _choose(String value) async {
    if (value == _default) {
      _note.clear();
      await c.setDayOverride(widget.day, null);
      return;
    }
    final note = _note.text.trim();
    await c.setDayOverride(
      widget.day,
      DateOverride(date: widget.day, templateId: value == _off ? null : value, note: note.isEmpty ? null : note),
    );
  }

  Future<void> _saveNote() async {
    final o = c.overrideOn(widget.day);
    if (o == null) return;
    final note = _note.text.trim();
    if ((o.note ?? '') == note) return;
    await c.setDayOverride(widget.day, DateOverride(date: o.date, templateId: o.templateId, note: note.isEmpty ? null : note));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not kaydedildi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final config = c.config;
    final holiday = c.holidayOn(day);
    final planId = config.weekPlan[day.weekday];
    final planTemplate = planId == null ? null : config.templateById(planId);
    final defaultLabel = holiday != null
        ? 'Tatil: ${holiday.name} (zil çalmaz)'
        : planTemplate != null
            ? 'Haftalık plana göre: ${planTemplate.name}'
            : 'Haftalık plana göre: zil çalmaz';
    final current = _current();
    final schedule = c.resolver.resolve(day);

    final options = <(String, String)>[
      (_default, defaultLabel),
      // Tatil olmayan günde haftalık plandaki şablon, ilk seçenekle aynıdır.
      for (final t in config.templates)
        if (holiday != null || t.id != planId || current == t.id) (t.id, t.name),
      (_off, 'Zil çalmasın'),
    ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lesson, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Seçili gün', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
            Text(
              '${day.day} ${turkishMonths[day.month - 1]} ${day.year}, ${turkishWeekdays[day.weekday - 1]}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              schedule.isSchoolDay ? '${schedule.bells.length} zil çalacak' : 'Zil çalmayacak',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: schedule.isSchoolDay ? AppColors.lessonText : AppColors.okText,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Bu gün ne çalsın?', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            RadioGroup<String>(
              groupValue: current,
              onChanged: (v) {
                if (v != null) _choose(v);
              },
              child: Column(
                children: [
                  for (final (value, label) in options)
                    _Option(value: value, label: label, selected: value == current, onTap: () => _choose(value)),
                ],
              ),
            ),
            if (current != _default) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: 'Not (ana ekranda görünür)',
                  hintText: 'Veli toplantısı',
                  suffixIcon: IconButton(tooltip: 'Notu kaydet', onPressed: _saveNote, icon: const Icon(Icons.check)),
                ),
                onSubmitted: (_) => _saveNote(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.value, required this.label, required this.selected, required this.onTap});

  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.lessonTint : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Radio<String>(value: value),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.lessonText : AppColors.ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HolidayList extends StatelessWidget {
  const _HolidayList({
    required this.controller,
    required this.today,
    required this.onEdit,
    required this.onDelete,
    required this.onShow,
  });

  final AppController controller;
  final DateTime today;
  final ValueChanged<Holiday> onEdit;
  final ValueChanged<Holiday> onDelete;
  final ValueChanged<Holiday> onShow;

  @override
  Widget build(BuildContext context) {
    final holidays = [...controller.config.holidays]..sort((a, b) => a.start.compareTo(b.start));
    return SectionCard(
      title: 'Tatiller',
      subtitle: 'Düzenlemek için bir satıra tıklayın',
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          if (holidays.isEmpty) const _Empty('Henüz tatil eklenmedi. MEB çalışma takvimindeki tatilleri "Tatil ekle" ile girin.'),
          for (final h in holidays)
            _HolidayRow(
              holiday: h,
              today: today,
              onEdit: () => onEdit(h),
              onDelete: () => onDelete(h),
              onShow: () => onShow(h),
            ),
        ],
      ),
    );
  }
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
  const _HolidayRow({
    required this.holiday,
    required this.today,
    required this.onEdit,
    required this.onDelete,
    required this.onShow,
  });

  final Holiday holiday;
  final DateTime today;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShow;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        days > 1 ? '${_range(h.start, h.end)} · $days gün' : _range(h.start, h.end),
                        style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                      ),
                    ],
                  ),
                ),
                if (current) const Pill('Bugün', background: AppColors.lesson, foreground: Colors.white),
                IconButton(
                  tooltip: '${h.name} takvimde göster',
                  onPressed: onShow,
                  icon: const Icon(Icons.calendar_month_outlined, color: AppColors.inkMuted),
                ),
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

  /// Yeni tatilde başlangıç olarak önerilen gün.
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
