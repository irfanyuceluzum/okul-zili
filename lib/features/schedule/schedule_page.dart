import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/date_utils.dart';
import '../../data/models/schedule_template.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Ders programını gösterir. Düzenleme ekranı sonraki adımda eklenecek.
class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.config;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(
                title: 'Ders programı',
                subtitle: Text('Ders saatlerinden ziller kendiliğinden oluşur.'),
              ),
              const SizedBox(height: 16),
              const _ComingSoon('Programı düzenleme ekranı bir sonraki adımda eklenecek.'),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  for (final t in config.templates)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _TemplateCard(template: t),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: SectionCard(
                      title: 'Haftalık plan',
                      subtitle: 'Her gün hangi şablonun kullanıldığı',
                      child: Column(
                        children: [
                          for (var d = 1; d <= 7; d++)
                            Container(
                              height: 44,
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
                              child: Row(
                                children: [
                                  Expanded(child: Text(turkishWeekdays[d - 1], style: const TextStyle(fontWeight: FontWeight.w600))),
                                  Text(
                                    config.weekPlan[d] == null
                                        ? 'Zil çalmaz'
                                        : config.templateById(config.weekPlan[d]!)?.name ?? 'Bilinmeyen şablon',
                                    style: TextStyle(color: config.weekPlan[d] == null ? AppColors.inkMuted : AppColors.ink),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final ScheduleTemplate template;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final errors = t.validate();
    final rows = <Widget>[];
    if (t.assemblyTime != null) {
      rows.add(_row('Toplanma', t.assemblyTime.toString(), '', null));
    }
    for (var i = 0; i < t.lessons.length; i++) {
      final l = t.lessons[i];
      rows.add(_row('${i + 1}. ders', '${l.start} – ${l.end}', '${l.end.inMinutes - l.start.inMinutes} dk', null));
      if (i < t.lessons.length - 1) {
        final gap = t.lessons[i + 1].start.inMinutes - l.end.inMinutes;
        final lunch = t.lunchAfterLesson == i + 1;
        rows.add(_row(
          lunch ? 'Öğle arası' : 'Teneffüs',
          '',
          '$gap dk',
          lunch ? (AppColors.lunchTint, AppColors.lunchText) : (AppColors.recessTint, AppColors.recessText),
        ));
      }
    }
    return SectionCard(
      title: t.name,
      subtitle: '${t.generateBells().length} zil · öğretmen zili '
          '${t.teacherBellMinutesBefore == 0 ? 'kapalı' : 'dersten ${t.teacherBellMinutesBefore} dk önce'}',
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows,
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            child: errors.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip(icon: Icons.check, label: 'Çakışma yok'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final e in errors) Text(e, style: const TextStyle(color: AppColors.dangerText))],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(String name, String time, String duration, (Color, Color)? tint) {
    return Container(
      height: tint == null ? 48 : 36,
      padding: EdgeInsets.only(left: tint == null ? 0 : 12, right: 12),
      decoration: BoxDecoration(
        color: tint?.$1,
        border: const Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: tint?.$2, fontSize: tint == null ? 15 : 14, fontFeatures: tabularFigures),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(name, style: TextStyle(fontWeight: tint == null ? FontWeight.w700 : FontWeight.w600))),
            Expanded(child: Text(time)),
            Text(duration, style: TextStyle(color: tint?.$2 ?? AppColors.inkSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.lessonTint, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.lessonText, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: AppColors.lessonText, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
