import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/date_utils.dart';
import '../../data/models/notices.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Pano modunda gösterilen duyurular ve günün nöbetçileri.
class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key, required this.controller});

  final AppController controller;

  static String describeEnd(DateTime? end) =>
      end == null ? 'Süresiz' : 'Bitiş: ${end.day} ${turkishMonths[end.month - 1]}';

  Future<void> _open(BuildContext context, {Announcement? initial}) async {
    final result = await showDialog<Announcement>(
      context: context,
      builder: (_) => AnnouncementDialog(today: dateOnly(controller.now()), initial: initial),
    );
    if (result != null) await controller.saveAnnouncement(result);
  }

  Future<void> _delete(BuildContext context, Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duyuru silinsin mi?'),
        content: Text(a.text, maxLines: 4, overflow: TextOverflow.ellipsis),
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
    if (ok == true) await controller.deleteAnnouncement(a.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final announcements = controller.config.announcements;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(
                title: 'Duyuru ve nöbet',
                subtitle: Text('Pano modunda gösterilecek duyurular ve günün nöbetçi öğretmenleri.'),
              ),
              const SizedBox(height: 24),
              SectionCard(
                title: 'Duyurular',
                icon: Icons.campaign_outlined,
                subtitle: 'Pano modunda ekranın altında kayar.',
                trailing: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => _open(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Duyuru ekle'),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    if (announcements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Henüz duyuru yok.', style: TextStyle(color: AppColors.inkMuted)),
                      ),
                    for (final a in announcements)
                      _AnnouncementRow(
                        announcement: a,
                        onToggle: (on) => controller.saveAnnouncement(a.copyWith(enabled: on)),
                        onEdit: () => _open(context, initial: a),
                        onDelete: () => _delete(context, a),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _DutyCard(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({
    required this.announcement,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Announcement announcement;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          Switch(value: a.enabled, onChanged: onToggle),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Opacity(
                  opacity: a.enabled ? 1 : 0.55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(NoticesPage.describeEnd(a.endDate), style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!a.enabled) const Pill('Kapalı', background: AppColors.neutralTint, foreground: AppColors.inkSecondary),
          IconButton(tooltip: 'Duyuruyu düzenle', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: AppColors.inkMuted)),
          IconButton(tooltip: 'Duyuruyu sil', onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

/// Duyuru ekleme/düzenleme penceresi; kaydedilince [Announcement] döner.
class AnnouncementDialog extends StatefulWidget {
  const AnnouncementDialog({super.key, required this.today, this.initial});

  final DateTime today;
  final Announcement? initial;

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  late final _text = TextEditingController(text: widget.initial?.text ?? '');
  late DateTime? _end = widget.initial?.endDate;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Duyuru metnini yazın');
      return;
    }
    final i = widget.initial;
    Navigator.pop(
      context,
      Announcement(
        id: i?.id ?? 'a${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        endDate: _end,
        enabled: i?.enabled ?? true,
      ),
    );
  }

  Future<void> _pickDate() async {
    final first = _end != null && _end!.isBefore(widget.today) ? _end! : widget.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? widget.today,
      firstDate: first,
      lastDate: DateTime(widget.today.year + 3, 12, 31),
    );
    if (picked != null) setState(() => _end = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Duyuru ekle' : 'Duyuruyu düzenle'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _text,
                autofocus: widget.initial == null,
                maxLength: 200,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(labelText: 'Duyuru metni', hintText: 'Cuma günü veli toplantısı var'),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_end == null ? 'Bitiş tarihi seç' : NoticesPage.describeEnd(_end)),
                  ),
                  if (_end != null)
                    TextButton(onPressed: () => setState(() => _end = null), child: const Text('Süresiz yap')),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Bitiş tarihi isteğe bağlıdır; o gün dahil gösterilir.',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
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

class _DutyRow {
  _DutyRow(this.weekday, String place, String teacher)
      : place = TextEditingController(text: place),
        teacher = TextEditingController(text: teacher),
        placeFocus = FocusNode(),
        teacherFocus = FocusNode();

  final int weekday;
  final TextEditingController place;
  final TextEditingController teacher;
  final FocusNode placeFocus;
  final FocusNode teacherFocus;

  void dispose() {
    place.dispose();
    teacher.dispose();
    placeFocus.dispose();
    teacherFocus.dispose();
  }
}

/// Haftanın günlerine göre "yer — öğretmen" satırları; yazı alanından
/// çıkınca ya da Enter'a basınca kaydedilir.
class _DutyCard extends StatefulWidget {
  const _DutyCard({required this.controller});

  final AppController controller;

  @override
  State<_DutyCard> createState() => _DutyCardState();
}

class _DutyCardState extends State<_DutyCard> {
  final _rows = <_DutyRow>[];
  final _removed = <_DutyRow>[];
  late bool _weekend;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    final roster = widget.controller.config.dutyRoster;
    for (final d in roster) {
      _rows.add(_make(d.weekday, d.place, d.teacher));
    }
    _weekend = roster.any((d) => d.weekday > 5);
  }

  _DutyRow _make(int weekday, String place, String teacher) {
    final row = _DutyRow(weekday, place, teacher);
    void onFocus() {
      if (!_disposing && !row.placeFocus.hasFocus && !row.teacherFocus.hasFocus) _commit();
    }

    row.placeFocus.addListener(onFocus);
    row.teacherFocus.addListener(onFocus);
    return row;
  }

  @override
  void dispose() {
    // Sayfadan çıkılıyor: bekleyen yazıyı kaydet. Ağaç kilitliyken arayüz
    // yenilenemez; kayıt kare bitince yapılır.
    _disposing = true;
    final roster = _roster();
    final c = widget.controller;
    if (!_same(roster, c.config.dutyRoster)) Future.microtask(() => c.setDutyRoster(roster));
    for (final r in [..._rows, ..._removed]) {
      r.dispose();
    }
    super.dispose();
  }

  List<DutyEntry> _roster() => [
        for (var d = 1; d <= 7; d++)
          for (final r in _rows.where((r) => r.weekday == d))
            if (r.place.text.trim().isNotEmpty || r.teacher.text.trim().isNotEmpty)
              DutyEntry(weekday: d, place: r.place.text.trim(), teacher: r.teacher.text.trim()),
      ];

  static bool _same(List<DutyEntry> a, List<DutyEntry> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) i]
          .every((i) => a[i].weekday == b[i].weekday && a[i].place == b[i].place && a[i].teacher == b[i].teacher);

  /// Boş satırlar kaydedilmez; değişiklik yoksa dosyaya yazılmaz.
  void _commit() {
    final roster = _roster();
    if (!_same(roster, widget.controller.config.dutyRoster)) widget.controller.setDutyRoster(roster);
  }

  void _add(int weekday) {
    final row = _make(weekday, '', '');
    setState(() => _rows.add(row));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && row.placeFocus.canRequestFocus) row.placeFocus.requestFocus();
    });
  }

  void _remove(_DutyRow row) {
    setState(() {
      _rows.remove(row);
      _removed.add(row);
    });
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final days = _weekend ? 7 : 5;
    return SectionCard(
      title: 'Nöbetçi öğretmenler',
      icon: Icons.badge_outlined,
      subtitle: 'Pano modunda o günün nöbetçileri gösterilir.',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Hafta sonu', style: TextStyle(color: AppColors.inkSecondary)),
          const SizedBox(width: 8),
          Switch(
            value: _weekend,
            onChanged: (on) {
              // Hafta sonu satırı varken gizlenirse silinmiş gibi görünürdü.
              if (!on && _rows.any((r) => r.weekday > 5)) return;
              setState(() => _weekend = on);
            },
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var d = 1; d <= days; d++) _day(d),
        ],
      ),
    );
  }

  Widget _day(int weekday) {
    final name = turkishWeekdays[weekday - 1];
    final rows = _rows.where((r) => r.weekday == weekday).toList();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
              TextButton.icon(
                onPressed: () => _add(weekday),
                icon: const Icon(Icons.add, size: 18),
                label: Text('$name için satır ekle'),
              ),
            ],
          ),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: r.place,
                      focusNode: r.placeFocus,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: 'Yer', hintText: 'Bahçe', semanticCounterText: '$name yer'),
                      onSubmitted: (_) {
                        _commit();
                        r.teacherFocus.requestFocus();
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('—', style: TextStyle(color: AppColors.inkMuted)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: r.teacher,
                      focusNode: r.teacherFocus,
                      decoration: const InputDecoration(labelText: 'Öğretmen', hintText: 'Ayşe Yılmaz'),
                      onSubmitted: (_) => _commit(),
                    ),
                  ),
                  IconButton(
                    tooltip: '$name nöbet satırını sil',
                    onPressed: () => _remove(r),
                    icon: const Icon(Icons.delete_outline, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
