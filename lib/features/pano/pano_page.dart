import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../core/date_utils.dart';
import '../../core/scheduler/day_schedule.dart';
import '../../ui/navigation.dart';
import '../../ui/theme.dart';

/// Koridor ekranı için tam ekran, koyu görünüm. 1920×1080 tuvalde
/// tasarlanır ve ekrana sığacak şekilde ölçeklenir. Esc ile çıkılır.
class PanoPage extends StatefulWidget {
  const PanoPage({super.key, required this.controller, required this.windowControls, required this.onExit});

  final AppController controller;
  final WindowControls windowControls;
  final VoidCallback onExit;

  @override
  State<PanoPage> createState() => _PanoPageState();
}

class _PanoPageState extends State<PanoPage> {
  late Timer _clock;
  late DateTime _now = widget.controller.now();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.windowControls.setFullScreen(true);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = widget.controller.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    _focus.dispose();
    widget.windowControls.setFullScreen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onExit},
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.panoGround,
          body: Stack(
            children: [
              Positioned.fill(
                child: FittedBox(
                  child: SizedBox(width: 1920, height: 1080, child: _content()),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 12,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.panoTextMuted),
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Panodan çık (Esc)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final c = widget.controller;
    final day = c.resolver.resolve(_now);
    final status = day.statusAt(_now);
    final next = c.resolver.nextBell(_now);
    final accent = switch (status.kind) {
      PeriodKind.lesson => AppColors.panoLesson,
      PeriodKind.breakTime => AppColors.recess,
      PeriodKind.lunch => AppColors.panoLunch,
      _ => AppColors.panoTextSecondary,
    };
    final progress = status.progressAt(_now);

    return DefaultTextStyle(
      style: const TextStyle(fontFamily: appFontFamily, color: AppColors.panoText),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(80, 64, 80, 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.recess, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.notifications, size: 36, color: AppColors.panoGround),
                ),
                const SizedBox(width: 20),
                Expanded(child: Text(c.config.schoolName.isEmpty ? 'Okul Zili' : c.config.schoolName, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600))),
                Text(formatTurkishDate(_now), style: const TextStyle(fontSize: 32, color: AppColors.panoTextSecondary)),
              ],
            ),
            const SizedBox(height: 48),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 155,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_two(_now.hour)}:${_two(_now.minute)}',
                            style: const TextStyle(fontSize: 300, fontWeight: FontWeight.w600, height: 0.95, fontFeatures: tabularFigures),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(status.title, style: TextStyle(fontSize: 104, fontWeight: FontWeight.w700, height: 1, color: accent)),
                        if (status.startsAt != null && status.endsAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${_hm(status.startsAt!)} – ${_hm(status.endsAt!)}',
                              style: const TextStyle(fontSize: 36, color: AppColors.panoTextSecondary, fontFeatures: tabularFigures),
                            ),
                          ),
                        if (status.endsAt != null && status.untilLabel != null) ...[
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('${status.untilLabel} kalan', style: const TextStyle(fontSize: 40, color: AppColors.panoTextSecondary)),
                              const SizedBox(width: 20),
                              Text(
                                formatCountdown(status.endsAt!.difference(_now)),
                                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w600, fontFeatures: tabularFigures),
                              ),
                            ],
                          ),
                        ],
                        if (progress != null) ...[
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 20,
                              backgroundColor: AppColors.panoSurface,
                              color: accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    flex: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PanoCard(title: 'Bugünün programı', child: _lessonList(day, status)),
                        const SizedBox(height: 32),
                        _PanoCard(
                          title: 'Sıradaki zil',
                          child: Text(
                            next == null
                                ? 'Yakın zamanda zil yok'
                                : isSameDay(next.at, _now)
                                    ? '${next.bell.time} · ${next.bell.label}'
                                    : '${turkishWeekdays[next.at.weekday - 1]} ${next.bell.time}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lessonList(DaySchedule day, PeriodStatus status) {
    final t = day.template;
    if (t == null) {
      return Text(day.offReason ?? 'Bugün ders yok', style: const TextStyle(fontSize: 32, color: AppColors.panoTextSecondary));
    }
    return Column(
      children: [
        for (var i = 0; i < t.lessons.length; i++) _lessonRow(day, i, status),
      ],
    );
  }

  Widget _lessonRow(DaySchedule day, int i, PeriodStatus status) {
    final lesson = day.template!.lessons[i];
    final start = lesson.start.on(day.date);
    final end = lesson.end.on(day.date);
    final current = status.kind == PeriodKind.lesson && !_now.isBefore(start) && _now.isBefore(end);
    final upcomingAfterBreak = (status.kind == PeriodKind.breakTime || status.kind == PeriodKind.lunch) &&
        status.endsAt != null &&
        start == status.endsAt;
    final past = !_now.isBefore(end);
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: current ? AppColors.panoLesson : null,
        borderRadius: BorderRadius.circular(14),
        border: upcomingAfterBreak ? Border.all(color: AppColors.recess, width: 3) : null,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 30,
          color: current ? AppColors.panoGround : (past ? AppColors.panoTextMuted : AppColors.panoText),
          fontWeight: current ? FontWeight.w700 : FontWeight.w400,
          fontFeatures: tabularFigures,
        ),
        child: Row(
          children: [
            Expanded(child: Text('${i + 1}. Ders')),
            Text('${lesson.start} – ${lesson.end}'),
          ],
        ),
      ),
    );
  }
}

class _PanoCard extends StatelessWidget {
  const _PanoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(36, 32, 36, 32),
        decoration: BoxDecoration(color: AppColors.panoSurface, borderRadius: BorderRadius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.panoTextSecondary)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}

String _two(int v) => v.toString().padLeft(2, '0');
String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
