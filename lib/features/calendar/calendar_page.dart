import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/date_utils.dart';
import '../../data/models/calendar.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Tatilleri, özel günleri ve etkinlikleri listeler. Takvim görünümü ve
/// düzenleme sonraki adımda eklenecek.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.controller});

  final AppController controller;

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
              const PageHeader(
                title: 'Takvim ve tatiller',
                subtitle: Text('Tatillerde ve "zil yok" seçilen günlerde zil çalmaz.'),
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
                        'Yalnızca tarihi her yıl aynı olan resmî tatiller ekli. Ara tatiller, yarıyıl tatili ve '
                        'dinî bayramlar MEB çalışma takvimine göre eklenmeli. Takvim ekranı ve düzenleme bir sonraki adımda.',
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
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SectionCard(
                      title: 'Tatiller',
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        children: [
                          if (holidays.isEmpty) const _Empty('Tanımlı tatil yok'),
                          for (final h in holidays) _holidayRow(h, today),
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

  Widget _holidayRow(Holiday h, DateTime today) {
    final range = h.start == h.end ? _date(h.start) : '${_date(h.start)} – ${_date(h.end)}';
    final current = h.contains(today);
    return _row(
      range,
      h.name,
      current
          ? const Pill('Bugün', background: AppColors.lesson, foreground: Colors.white)
          : const Pill('Tatil', background: AppColors.okTint, foreground: AppColors.okText),
      past: h.end.isBefore(today),
    );
  }

  Widget _row(String date, String text, Widget trailing, {bool past = false}) {
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

  static String _date(DateTime d) => '${d.day} ${turkishMonths[d.month - 1]} ${d.year}';

  static String _recurrence(SpecialEvent e) => switch (e.recurrence) {
        Recurrence.once => e.date == null ? 'Tek sefer' : _date(e.date!),
        Recurrence.yearly => 'Her yıl ${e.day} ${turkishMonths[(e.month ?? 1) - 1]}',
        Recurrence.weekly => 'Her ${(e.weekdays.toList()..sort()).map((d) => turkishWeekdays[d - 1]).join(', ')}',
      };
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
