import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../core/date_utils.dart';
import '../../core/scheduler/day_schedule.dart';
import '../../data/models/notices.dart';
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
    final hasBand = widget.controller.config.activeAnnouncements(_now).isNotEmpty;
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
              // Duyuru bandı varken düğme bandın üstüne binmesin diye sağ üste alınır.
              Positioned(
                right: 16,
                top: hasBand ? 8 : null,
                bottom: hasBand ? null : 12,
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
    final announcements = c.config.activeAnnouncements(_now);
    final duties = c.config.dutiesOn(_now.weekday);
    final announcementText = announcements.map((a) => a.text.trim()).join(' • ');

    return DefaultTextStyle(
      style: const TextStyle(fontFamily: appFontFamily, color: AppColors.panoText),
      child: Column(
        children: [
          Expanded(child: Padding(
        padding: EdgeInsets.fromLTRB(80, 64, 80, announcements.isEmpty ? 72 : 24),
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
                    // Yoğun günde (çok ders + nöbetçi) sütun taşmasın diye gerekirse küçülür.
                    child: LayoutBuilder(
                      builder: (context, box) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: box.maxWidth,
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
                              if (duties.isNotEmpty) ...[
                                const SizedBox(height: 32),
                                _PanoCard(title: 'Bugünün nöbetçileri', child: _dutyList(duties)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          )),
          if (announcements.isNotEmpty) _AnnouncementBand(text: announcementText),
        ],
      ),
    );
  }

  Widget _dutyList(List<DutyEntry> duties) {
    const maxRows = 6;
    final shown = duties.take(maxRows).toList();
    final extra = duties.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${d.place} — ${d.teacher}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28)),
          ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('+$extra kişi daha', style: const TextStyle(fontSize: 26, color: AppColors.panoTextSecondary)),
          ),
      ],
    );
  }

  Widget _lessonList(DaySchedule day, PeriodStatus status) {
    final t = day.template;
    if (t == null) {
      return Text(day.offReason ?? 'Bugün ders yok', style: const TextStyle(fontSize: 32, color: AppColors.panoTextSecondary));
    }
    // Çok dersli günde satırlar alçalır ki sağ sütun sığsın.
    final rowHeight = t.lessons.length > 6 ? 48.0 : 60.0;
    return Column(
      children: [
        for (var i = 0; i < t.lessons.length; i++) _lessonRow(day, i, status, rowHeight),
      ],
    );
  }

  Widget _lessonRow(DaySchedule day, int i, PeriodStatus status, double rowHeight) {
    final lesson = day.template!.lessons[i];
    final start = lesson.start.on(day.date);
    final end = lesson.end.on(day.date);
    final current = status.kind == PeriodKind.lesson && !_now.isBefore(start) && _now.isBefore(end);
    final upcomingAfterBreak = (status.kind == PeriodKind.breakTime || status.kind == PeriodKind.lunch) &&
        status.endsAt != null &&
        start == status.endsAt;
    final past = !_now.isBefore(end);
    return Container(
      height: rowHeight,
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

/// Tuvalin altındaki sarı duyuru bandı: solda etiket, yanında sağdan sola akan metin.
class _AnnouncementBand extends StatelessWidget {
  const _AnnouncementBand({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        color: AppColors.recess,
        child: Row(
          children: [
            Container(
              width: 220,
              alignment: Alignment.center,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.panoGround, width: 4))),
              child: const Text('DUYURU', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.panoGround)),
            ),
            Expanded(child: _Marquee(key: ValueKey(text), text: text)),
          ],
        ),
      );
}

/// Metni sağdan sola sürekli kaydırır. Anahtarı metne bağlıdır; panonun
/// saniyelik yenilemesi animasyonu baştan başlatmaz.
class _Marquee extends StatefulWidget {
  const _Marquee({super.key, required this.text});

  final String text;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  static const _style = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w600,
    color: AppColors.panoGround,
  );
  static const _speed = 140.0; // piksel/sn
  static const _viewport = 1700.0; // süre hesabı için tahmini görünür genişlik

  late final double _textWidth;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final painter = TextPainter(text: TextSpan(text: widget.text, style: _style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    _textWidth = painter.width.ceilToDouble() + 4;
    painter.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ((_textWidth + _viewport) / _speed * 1000).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: _textWidth,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) =>
                  Transform.translate(offset: Offset(box.maxWidth - _controller.value * (box.maxWidth + _textWidth), 0), child: child),
              child: Text(widget.text, key: const ValueKey('duyuru-metni'), maxLines: 1, softWrap: false, style: _style),
            ),
          ),
        ),
      );
}

String _two(int v) => v.toString().padLeft(2, '0');
String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
