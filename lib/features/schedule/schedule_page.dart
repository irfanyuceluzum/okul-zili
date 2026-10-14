import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../core/clock_time.dart';
import '../../core/date_utils.dart';
import '../../data/models/schedule_template.dart';
import '../../data/schedule_draft.dart';
import '../../ui/theme.dart';
import '../../ui/time_field.dart';
import '../../ui/widgets.dart';

/// Ders programı düzenleyici. Değişiklikler taslakta tutulur; "Kaydet"e
/// basılana kadar ziller eski programla çalar.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<String> _saveErrors = const [];

  /// Kaydet/Vazgeç sonrası alanlar taslaktan yeniden kurulsun diye artar;
  /// aksi hâlde odaktaki saat alanı eski metni göstermeye devam ederdi.
  int _revision = 0;

  AppController get c => widget.controller;

  void _edit(void Function(ScheduleDraft draft) change) {
    change(c.editSchedule());
    c.scheduleDraftChanged();
  }

  void _updateTemplate(ScheduleTemplate t) => _edit((d) => d.replace(t));

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final errors = await c.saveScheduleDraft();
    setState(() {
      _saveErrors = errors;
      if (errors.isEmpty) _revision++;
    });
    if (errors.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program kaydedildi. Ziller yeni programa göre çalacak.')),
      );
    }
  }

  void _discard() {
    FocusManager.instance.primaryFocus?.unfocus();
    c.discardScheduleDraft();
    setState(() {
      _saveErrors = const [];
      _revision++;
    });
  }

  Future<void> _newTemplate(ScheduleDraft draft) async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => _NewTemplateDialog(templates: draft.templates, selectedId: draft.selectedId),
    );
    if (result == null) return;
    final (name, copyFrom) = result;
    final source = copyFrom == null ? null : draft.byId(copyFrom);
    final template = source?.copyWith(id: ScheduleDraft.newId(), name: name) ??
        ScheduleTemplate(id: ScheduleDraft.newId(), name: name, lessons: const []);
    _edit((d) => d.add(template));
  }

  Future<void> _deleteTemplate(ScheduleDraft draft, ScheduleTemplate t) async {
    String? blocker;
    if (draft.templates.length == 1) {
      blocker = 'En az bir şablon kalmalı.';
    } else {
      final usedOn = c.config.overrides.where((o) => o.templateId == t.id).toList();
      if (usedOn.isNotEmpty) {
        final d = usedOn.first.date;
        blocker = 'Bu şablon takvimde ${d.day} ${turkishMonths[d.month - 1]} için kullanılıyor.';
      }
    }
    final days = draft.daysUsing(t.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocker == null ? '"${t.name}" silinsin mi?' : 'Şablon silinemez'),
        content: Text(blocker ??
            (days.isEmpty
                ? 'Bu şablon hiçbir günde kullanılmıyor.'
                : '${days.map((d) => turkishWeekdays[d - 1]).join(', ')} günleri "Zil çalmasın" olacak.')),
        actions: blocker != null
            ? [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tamam'))]
            : [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sil'),
                ),
              ],
      ),
    );
    if (ok == true) _edit((d) => d.remove(t.id));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final draft = c.editSchedule();
        final selected = draft.selected;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Ders programı',
                subtitle: draft.dirty
                    ? const Text('Kaydedilmemiş değişiklikler var. Kaydedene kadar ziller eski programla çalar.',
                        style: TextStyle(color: AppColors.lunchText, fontWeight: FontWeight.w600))
                    : const Text('Ders saatlerini girin, ziller kendiliğinden oluşur.'),
                trailing: Wrap(
                  spacing: 12,
                  children: [
                    if (draft.dirty)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: _discard,
                        child: const Text('Vazgeç'),
                      ),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: draft.dirty ? _save : null,
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ),
              if (_saveErrors.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ErrorBox(title: 'Kaydedilmedi, şunları düzeltin:', errors: _saveErrors),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in draft.templates)
                    _TemplateTab(
                      name: t.name.trim().isEmpty ? 'Adsız şablon' : t.name,
                      days: draft.daysUsing(t.id),
                      selected: t.id == draft.selectedId,
                      onTap: () => _edit((d) => d.selectedId = t.id),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: AppColors.lesson,
                      side: const BorderSide(color: AppColors.lineStrong),
                    ),
                    onPressed: () => _newTemplate(draft),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni şablon'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                final editor = selected == null
                    ? const SectionCard(child: Text('Şablon seçin ya da yeni şablon ekleyin.'))
                    : _TemplateEditor(
                        key: ValueKey('${selected.id}-$_revision'),
                        template: selected,
                        onChanged: _updateTemplate,
                        onDelete: () => _deleteTemplate(draft, selected),
                      );
                final side = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selected != null) ...[
                      _QuickFill(
                        key: ValueKey('quick-${selected.id}-$_revision'),
                        template: selected,
                        onApply: (lessons, lunchAfter) {
                          _updateTemplate(selected.copyWith(lessons: lessons, lunchAfterLesson: () => lunchAfter));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saatler hesaplandı. Geçerli olması için Kaydet\'e basın.')),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    _WeekPlan(draft: draft, onChanged: (day, id) => _edit((d) => d.setDay(day, id))),
                  ],
                );
                if (constraints.maxWidth < 1000) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [editor, const SizedBox(height: 24), side],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 14, child: editor),
                    const SizedBox(width: 24),
                    Expanded(flex: 10, child: side),
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

class _TemplateTab extends StatelessWidget {
  const _TemplateTab({required this.name, required this.days, required this.selected, required this.onTap});

  final String name;
  final List<int> days;
  final bool selected;
  final VoidCallback onTap;

  static String describeDays(List<int> days) {
    if (days.isEmpty) return 'Atanmadı';
    const short = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final consecutive = days.length > 2 && days.last - days.first == days.length - 1;
    return consecutive ? '${short[days.first - 1]} – ${short[days.last - 1]}' : days.map((d) => short[d - 1]).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.lessonTint : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.lesson : AppColors.lineStrong, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? AppColors.lessonText : AppColors.ink,
                      )),
                  Text(describeDays(days),
                      style: TextStyle(fontSize: 12, color: selected ? AppColors.lessonText : AppColors.inkSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({super.key, required this.template, required this.onChanged, required this.onDelete});

  final ScheduleTemplate template;
  final ValueChanged<ScheduleTemplate> onChanged;
  final VoidCallback onDelete;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final _name = TextEditingController(text: widget.template.name);

  /// Toplanma kapatılıp açılınca eski saat geri gelsin.
  late ClockTime _lastAssembly = widget.template.assemblyTime ?? _defaultAssembly();

  ScheduleTemplate get t => widget.template;

  ClockTime _defaultAssembly() =>
      widget.template.lessons.firstOrNull?.start.tryAddMinutes(-10) ?? const ClockTime(8, 30);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setLesson(int i, {ClockTime? start, ClockTime? end}) {
    final lessons = [...t.lessons];
    lessons[i] = Lesson(start ?? lessons[i].start, end ?? lessons[i].end);
    widget.onChanged(t.copyWith(lessons: lessons));
  }

  void _removeLesson(int i) {
    final lessons = [...t.lessons]..removeAt(i);
    final lunch = t.lunchAfterLesson;
    int? newLunch = lunch;
    if (lunch != null) {
      if (i + 1 <= lunch) newLunch = lunch - 1;
      if (newLunch != null && (newLunch < 1 || newLunch >= lessons.length)) newLunch = null;
    }
    widget.onChanged(t.copyWith(lessons: lessons, lunchAfterLesson: () => newLunch));
  }

  void _addLesson() {
    final last = t.lessons.lastOrNull;
    final start = last == null ? const ClockTime(8, 40) : last.end.tryAddMinutes(10);
    final end = start?.tryAddMinutes(last?.minutes ?? 40);
    if (start == null || end == null) return;
    widget.onChanged(t.copyWith(lessons: [...t.lessons, Lesson(start, end)]));
  }

  @override
  Widget build(BuildContext context) {
    final errors = t.validate();
    final bellCount = t.generateBells().length;
    final rows = <Widget>[];
    for (var i = 0; i < t.lessons.length; i++) {
      final l = t.lessons[i];
      final n = i + 1;
      rows.add(_LessonRow(
        key: ValueKey('lesson-$i'),
        number: n,
        lesson: l,
        onStart: (v) => _setLesson(i, start: v),
        onEnd: (v) => _setLesson(i, end: v),
        onDelete: () => _removeLesson(i),
      ));
      if (i < t.lessons.length - 1) {
        rows.add(_GapRow(
          minutes: t.lessons[i + 1].start.inMinutes - l.end.inMinutes,
          lunch: t.lunchAfterLesson == n,
        ));
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Şablonun adı'),
                    onChanged: (v) => widget.onChanged(t.copyWith(name: v)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Şablonu sil',
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Checkbox(
                  value: t.assemblyTime != null,
                  onChanged: (on) => widget.onChanged(t.copyWith(assemblyTime: () => on == true ? _lastAssembly : null)),
                ),
                const Text('Toplanma zili', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (t.assemblyTime != null)
                  TimeField(
                    value: t.assemblyTime,
                    semanticLabel: 'Toplanma saati',
                    onChanged: (v) {
                      _lastAssembly = v;
                      widget.onChanged(t.copyWith(assemblyTime: () => v));
                    },
                  ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFF8F9FB),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: const DefaultTextStyle(
              style: TextStyle(fontFamily: appFontFamily, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.inkMuted),
              child: Row(
                children: [
                  SizedBox(width: 88, child: Text('DERS')),
                  SizedBox(width: 108, child: Text('BAŞLANGIÇ')),
                  SizedBox(width: 108, child: Text('BİTİŞ')),
                  Expanded(child: Text('SÜRE')),
                ],
              ),
            ),
          ),
          if (t.lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Henüz ders yok. "Ders ekle" ya da sağdaki "Hızlı doldur" ile başlayın.',
                  style: TextStyle(color: AppColors.inkSecondary)),
            ),
          ...rows,
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: AppColors.lesson),
              onPressed: _addLesson,
              icon: const Icon(Icons.add),
              label: const Text('Ders ekle'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Wrap(
              spacing: 32,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Öğretmen zili: '),
                    DropdownButton<int>(
                      value: t.teacherBellMinutesBefore.clamp(0, 10),
                      onChanged: (v) => widget.onChanged(t.copyWith(teacherBellMinutesBefore: v)),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('Kapalı')),
                        for (var m = 1; m <= 10; m++) DropdownMenuItem(value: m, child: Text('dersten $m dk önce')),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Öğle arası: '),
                    DropdownButton<int>(
                      value: (t.lunchAfterLesson != null && t.lunchAfterLesson! < t.lessons.length) ? t.lunchAfterLesson : 0,
                      onChanged: (v) => widget.onChanged(t.copyWith(lunchAfterLesson: () => v == 0 ? null : v)),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('Yok')),
                        for (var n = 1; n < t.lessons.length; n++)
                          DropdownMenuItem(value: n, child: Text('$n. dersten sonra')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            child: errors.isEmpty
                ? Row(
                    children: [
                      Expanded(child: Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Bu şablon günde '),
                        TextSpan(text: '$bellCount zil', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(text: ' çalar.'),
                      ]))),
                      const StatusChip(icon: Icons.check, label: 'Çakışma yok'),
                    ],
                  )
                : _ErrorBox(title: 'Bu şablonda sorun var:', errors: errors),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    super.key,
    required this.number,
    required this.lesson,
    required this.onStart,
    required this.onEnd,
    required this.onDelete,
  });

  final int number;
  final Lesson lesson;
  final ValueChanged<ClockTime> onStart;
  final ValueChanged<ClockTime> onEnd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final minutes = lesson.minutes;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text('$number. ders', style: const TextStyle(fontWeight: FontWeight.w700))),
          TimeField(value: lesson.start, semanticLabel: '$number. ders başlangıç', onChanged: onStart),
          const SizedBox(width: 12),
          TimeField(value: lesson.end, semanticLabel: '$number. ders bitiş', onChanged: onEnd),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              minutes > 0 ? '$minutes dk' : 'Geçersiz',
              style: TextStyle(color: minutes > 0 ? AppColors.inkSecondary : AppColors.dangerText),
            ),
          ),
          IconButton(
            tooltip: '$number. dersi sil',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.minutes, required this.lunch});

  final int minutes;
  final bool lunch;

  @override
  Widget build(BuildContext context) {
    final overlap = minutes < 0;
    final (bg, fg) = overlap
        ? (AppColors.dangerTint, AppColors.dangerText)
        : lunch
            ? (AppColors.lunchTint, AppColors.lunchText)
            : (AppColors.recessTint, AppColors.recessText);
    return Container(
      height: 34,
      color: bg,
      padding: const EdgeInsets.only(left: 112, right: 24),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg, fontSize: 14),
        child: Row(
          children: [
            Text(overlap ? 'Çakışma' : (lunch ? 'Öğle arası' : (minutes == 0 ? 'Ara yok' : 'Teneffüs')),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(overlap ? '${-minutes} dk üst üste' : '$minutes dk'),
          ],
        ),
      ),
    );
  }
}

class _QuickFill extends StatefulWidget {
  const _QuickFill({super.key, required this.template, required this.onApply});

  final ScheduleTemplate template;
  final void Function(List<Lesson> lessons, int? lunchAfter) onApply;

  @override
  State<_QuickFill> createState() => _QuickFillState();
}

class _QuickFillState extends State<_QuickFill> {
  late ClockTime _first;
  late int _count;
  late int _lessonMin;
  late int _breakMin;
  late int _lunchAfter; // 0 = yok
  late int _lunchMin;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    final ls = t.lessons;
    _first = ls.firstOrNull?.start ?? const ClockTime(8, 40);
    _count = ls.isEmpty ? 6 : ls.length;
    _lessonMin = ls.firstOrNull?.minutes ?? 40;
    _breakMin = ls.length > 1 ? (ls[1].start.inMinutes - ls[0].end.inMinutes).clamp(0, 60) : 10;
    _lunchAfter = t.lunchAfterLesson ?? 0;
    final lunch = t.lunchAfterLesson;
    _lunchMin = lunch != null && lunch < ls.length ? ls[lunch].start.inMinutes - ls[lunch - 1].end.inMinutes : 30;
  }

  void _apply() {
    try {
      final lessons = ScheduleTemplate.generateLessons(
        firstStart: _first,
        count: _count,
        lessonMinutes: _lessonMin,
        breakMinutes: _breakMin,
        lunchAfter: _lunchAfter == 0 ? null : _lunchAfter,
        lunchMinutes: _lunchMin,
      );
      setState(() => _error = null);
      widget.onApply(lessons, _lunchAfter == 0 || _lunchAfter >= _count ? null : _lunchAfter);
    } on RangeError {
      setState(() => _error = 'Dersler gece yarısını geçiyor; süreleri kısaltın.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Hızlı doldur',
      subtitle: 'Süreleri verin, tüm saatler hesaplansın. Sonra tek tek düzeltebilirsiniz.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              _Labeled(
                label: 'İlk ders başlangıcı',
                child: TimeField(value: _first, semanticLabel: 'İlk ders başlangıcı', onChanged: (v) => setState(() => _first = v)),
              ),
              _NumberField(label: 'Ders sayısı', value: _count, min: 1, max: 12, onChanged: (v) => setState(() => _count = v)),
              _NumberField(label: 'Ders süresi (dk)', value: _lessonMin, min: 10, max: 120, onChanged: (v) => setState(() => _lessonMin = v)),
              _NumberField(label: 'Teneffüs (dk)', value: _breakMin, min: 0, max: 60, onChanged: (v) => setState(() => _breakMin = v)),
              _Labeled(
                label: 'Öğle arası',
                child: DropdownButton<int>(
                  value: _lunchAfter < _count ? _lunchAfter : 0,
                  onChanged: (v) => setState(() => _lunchAfter = v ?? 0),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Yok')),
                    for (var n = 1; n < _count; n++) DropdownMenuItem(value: n, child: Text('$n. dersten sonra')),
                  ],
                ),
              ),
              if (_lunchAfter != 0 && _lunchAfter < _count)
                _NumberField(label: 'Öğle arası (dk)', value: _lunchMin, min: 0, max: 120, onChanged: (v) => setState(() => _lunchMin = v)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.dangerText)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _apply,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Saatleri hesapla'),
              ),
              const Text('Mevcut ders saatlerinin yerine geçer.', style: TextStyle(fontSize: 13, color: AppColors.inkMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

class _NumberField extends StatefulWidget {
  const _NumberField({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(text: '${widget.value}');
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label: widget.label,
      child: SizedBox(
        width: 96,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            errorText: _invalid ? '${widget.min}–${widget.max}' : null,
          ),
          onChanged: (text) {
            final v = int.tryParse(text);
            final ok = v != null && v >= widget.min && v <= widget.max;
            setState(() => _invalid = !ok);
            if (ok) widget.onChanged(v);
          },
        ),
      ),
    );
  }
}

class _WeekPlan extends StatelessWidget {
  const _WeekPlan({required this.draft, required this.onChanged});

  final ScheduleDraft draft;
  final void Function(int weekday, String? templateId) onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Haftalık plan',
      subtitle: 'Her gün hangi şablonun kullanılacağını seçin.',
      child: Column(
        children: [
          for (var d = 1; d <= 7; d++)
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
              child: Row(
                children: [
                  Expanded(child: Text(turkishWeekdays[d - 1], style: const TextStyle(fontWeight: FontWeight.w600))),
                  DropdownButton<String?>(
                    value: draft.byId(draft.weekPlan[d] ?? '') == null ? null : draft.weekPlan[d],
                    onChanged: (id) => onChanged(d, id),
                    items: [
                      for (final t in draft.templates)
                        DropdownMenuItem(value: t.id, child: Text(t.name.trim().isEmpty ? 'Adsız şablon' : t.name)),
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Zil çalmasın', style: TextStyle(color: AppColors.inkMuted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.title, required this.errors});

  final String title;
  final List<String> errors;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.dangerTint, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final e in errors) Text('• $e', style: const TextStyle(color: AppColors.dangerText)),
          ],
        ),
      );
}

class _NewTemplateDialog extends StatefulWidget {
  const _NewTemplateDialog({required this.templates, required this.selectedId});

  final List<ScheduleTemplate> templates;
  final String selectedId;

  @override
  State<_NewTemplateDialog> createState() => _NewTemplateDialogState();
}

class _NewTemplateDialogState extends State<_NewTemplateDialog> {
  final _name = TextEditingController();
  late String? _copyFrom = widget.templates.any((t) => t.id == widget.selectedId) ? widget.selectedId : null;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Şablona bir ad verin');
      return;
    }
    if (widget.templates.any((t) => t.name.trim().toLowerCase() == name.toLowerCase())) {
      setState(() => _error = 'Bu adda bir şablon zaten var');
      return;
    }
    Navigator.pop(context, (name, _copyFrom));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni şablon'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Şablonun adı', hintText: 'Kısaltılmış gün', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 20),
            const Text('Başlangıç', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
            DropdownButton<String?>(
              isExpanded: true,
              value: _copyFrom,
              onChanged: (v) => setState(() => _copyFrom = v),
              items: [
                for (final t in widget.templates) DropdownMenuItem(value: t.id, child: Text('"${t.name}" şablonunun kopyası')),
                const DropdownMenuItem(value: null, child: Text('Boş şablon')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: _create, child: const Text('Oluştur')),
      ],
    );
  }
}
