import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/date_utils.dart';
import '../../core/scheduler/bell_log.dart';
import '../../core/scheduler/day_schedule.dart';
import '../../data/models/bell_event.dart';
import '../../ui/navigation.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller, required this.onNavigate});

  final AppController controller;
  final ValueChanged<AppPage> onNavigate;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Timer _clock;
  late DateTime _now = widget.controller.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = widget.controller.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final resolver = c.resolver;
        final today = resolver.resolve(_now);
        final next = resolver.nextBell(_now);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._banners(c),
              PageHeader(
                title: '${_now.day} ${turkishMonths[_now.month - 1]} ${_now.year}, ${turkishWeekdays[_now.weekday - 1]}',
                subtitle: Text.rich(TextSpan(children: [
                  TextSpan(text: today.isSchoolDay ? '${today.template!.name} programı · Saat ' : '${today.offReason} · Saat '),
                  TextSpan(
                    text: _hms(_now),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontFeatures: tabularFigures),
                  ),
                ])),
                trailing: _StatusChips(controller: c, onNavigate: widget.onNavigate),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NowCard(day: today, now: _now),
                    const SizedBox(height: 16),
                    _InfoCards(controller: c, next: next, now: _now),
                    const SizedBox(height: 16),
                    _QuickActions(controller: c),
                  ],
                );
                final right = _TodayBells(
                  controller: c,
                  day: today,
                  next: next,
                  now: _now,
                  onEdit: () => widget.onNavigate(AppPage.program),
                );
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [left, const SizedBox(height: 24), right],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: right),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _banners(AppController c) {
    final banners = <Widget>[];
    void add(Widget w) => banners.addAll([w, const SizedBox(height: 16)]);

    if (c.emergencyActive) {
      add(_Banner(
        background: AppColors.danger,
        foreground: Colors.white,
        icon: Icons.warning_amber_rounded,
        text: 'Acil durum alarmı çalıyor',
        action: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.dangerText, minimumSize: const Size(0, 44)),
          onPressed: c.stopSound,
          child: const Text('Alarmı durdur'),
        ),
      ));
    }
    if (c.isMuted) {
      final until = c.mutedUntil!;
      final untilText = isSameDay(until, _now)
          ? 'saat ${_hm(until)}\'e kadar'
          : (until.hour == 0 && until.minute == 0 && isSameDay(until.subtract(const Duration(minutes: 1)), _now))
              ? 'bugün boyunca'
              : '${until.day} ${turkishMonths[until.month - 1]} ${_hm(until)}\'e kadar';
      add(_Banner(
        background: AppColors.recessTint,
        foreground: AppColors.recessText,
        icon: Icons.notifications_off_outlined,
        text: 'Ziller $untilText susturuldu.',
        action: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: c.unmute,
          child: const Text('Susturmayı kaldır'),
        ),
      ));
    }
    for (final message in [c.repository.lastLoadWarning, c.lastError]) {
      if (message == null) continue;
      add(_Banner(
        background: AppColors.dangerTint,
        foreground: AppColors.dangerText,
        icon: Icons.error_outline,
        text: message,
      ));
    }
    return banners;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.background, required this.foreground, required this.icon, required this.text, this.action});

  final Color background;
  final Color foreground;
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w600))),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
        ),
      );
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.controller, required this.onNavigate});

  final AppController controller;
  final ValueChanged<AppPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final chips = <Widget>[];
    if (c.system.controlsVolume) {
      final v = c.volume;
      final target = c.config.volumePercent;
      if (v.error != null) {
        chips.add(StatusChip(icon: Icons.volume_off, label: v.error!, tone: ChipTone.danger));
      } else if (v.muted) {
        chips.add(StatusChip(
          icon: Icons.volume_off,
          label: 'Ses kapalı',
          tone: ChipTone.warning,
          tooltip: 'Zil çalmadan önce ses açılıp %$target\'e getirilecek.',
        ));
      } else if (v.percent != null && v.percent! < target) {
        chips.add(StatusChip(
          icon: Icons.volume_down,
          label: 'Ses %${v.percent}',
          tone: ChipTone.warning,
          tooltip: 'Zil çalmadan önce %$target\'e yükseltilecek.',
        ));
      } else if (v.percent != null) {
        chips.add(StatusChip(icon: Icons.volume_up, label: 'Ses açık · %${v.percent}'));
      }
    } else {
      chips.add(const StatusChip(
        icon: Icons.volume_up,
        label: 'Sistem sesi denetlenmiyor',
        tone: ChipTone.neutral,
        tooltip: 'Sistem sesi yalnızca Windows\'ta otomatik açılır.',
      ));
    }
    if (c.system.supportsAutostart && c.autostartEnabled != null) {
      chips.add(InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onNavigate(AppPage.settings),
        child: c.autostartEnabled!
            ? const StatusChip(icon: Icons.power_settings_new, label: 'Otomatik başlatma açık')
            : const StatusChip(
                icon: Icons.power_settings_new,
                label: 'Otomatik başlatma kapalı',
                tone: ChipTone.warning,
                tooltip: 'Bilgisayar açılınca uygulama kendiliğinden başlamaz. Ayarlardan açın.',
              ),
      ));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({required this.day, required this.now});

  final DaySchedule day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = day.statusAt(now);
    final colors = PeriodColors.of(status.kind);
    final range = status.startsAt != null && status.endsAt != null
        ? '${_hm(status.startsAt!)} – ${_hm(status.endsAt!)} · '
            '${status.endsAt!.difference(status.startsAt!).inMinutes} dakika'
        : null;
    final remaining = status.endsAt?.difference(now);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: colors.tint, borderRadius: BorderRadius.circular(20)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.text),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 24,
              runSpacing: 16,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Eyebrow('Şu an'),
                    Text(
                      status.title,
                      style: TextStyle(fontSize: status.title.length > 12 ? 44 : 64, fontWeight: FontWeight.w700, height: 1.05),
                    ),
                    if (range != null) Text(range, style: const TextStyle(fontSize: 17)),
                  ],
                ),
                if (remaining != null && status.untilLabel != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Eyebrow('${status.untilLabel} kalan'),
                      Text(
                        formatCountdown(remaining),
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w600, height: 1.05, fontFeatures: tabularFigures),
                      ),
                    ],
                  ),
              ],
            ),
            if (day.isSchoolDay) ...[
              const SizedBox(height: 28),
              DayTimeline(day: day, now: now),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  LegendDot(AppColors.lesson, 'Ders'),
                  LegendDot(AppColors.recess, 'Teneffüs'),
                  LegendDot(AppColors.lunch, 'Öğle arası'),
                  LegendDot(AppColors.assembly, 'Toplanma'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1),
      );
}

class _InfoCards extends StatelessWidget {
  const _InfoCards({required this.controller, required this.next, required this.now});

  final AppController controller;
  final UpcomingBell? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    final holiday = controller.nextHoliday();
    final nextCard = _InfoCard(
      icon: Icons.notifications_outlined,
      label: 'Sıradaki zil',
      value: next == null ? '—' : next.bell.time.toString(),
      detail: next == null
          ? 'Önümüzdeki 30 günde zil yok'
          : [
              if (!isSameDay(next.at, now)) '${next.at.day} ${turkishMonths[next.at.month - 1]} ${turkishWeekdays[next.at.weekday - 1]}',
              next.bell.label,
              ?controller.config.soundFor(next.bell)?.name,
            ].join(' · '),
    );
    final today = dateOnly(now);
    final holidayCard = _InfoCard(
      icon: Icons.event_outlined,
      label: 'Sonraki tatil',
      value: holiday == null ? '—' : '${holiday.start.day} ${turkishMonths[holiday.start.month - 1]}',
      detail: holiday == null
          ? 'Tanımlı tatil yok'
          : holiday.contains(today)
              ? '${holiday.name} · bugün'
              : '${holiday.name} · ${holiday.start.difference(today).inDays} gün sonra',
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 480) {
        return Column(children: [nextCard, const SizedBox(height: 16), holidayCard]);
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: nextCard), const SizedBox(width: 16), Expanded(child: holidayCard)],
        ),
      );
    });
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label, required this.value, required this.detail});

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: AppColors.inkSecondary),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
              ]),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, fontFeatures: tabularFigures)),
              Text(detail, style: const TextStyle(fontSize: 15, color: AppColors.inkSecondary)),
            ],
          ),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SectionCard(
      title: 'Hızlı işlemler',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: c.emergencyActive ? null : c.ringNow,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Şimdi zil çal'),
              ),
              if (c.isMuted)
                OutlinedButton.icon(
                  onPressed: c.unmute,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Susturmayı kaldır'),
                )
              else
                MenuAnchor(
                  builder: (context, menu, _) => OutlinedButton.icon(
                    onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                    icon: const Icon(Icons.notifications_off_outlined),
                    label: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Sustur'), SizedBox(width: 4), Icon(Icons.expand_more, size: 18)]),
                  ),
                  menuChildren: [
                    MenuItemButton(onPressed: c.muteUntilPeriodEnd, child: const Text('Bu ders / teneffüs bitene kadar')),
                    MenuItemButton(
                      onPressed: () => c.muteUntil(c.now().add(const Duration(hours: 1))),
                      child: const Text('1 saat'),
                    ),
                    MenuItemButton(onPressed: c.muteForToday, child: const Text('Bugün boyunca')),
                  ],
                ),
              OutlinedButton.icon(
                onPressed: c.stopSound,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Sesi durdur'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HoldToConfirmButton(
                label: 'Acil durum alarmı',
                holdingLabel: 'Bırakmayın…',
                icon: Icons.warning_amber_rounded,
                onConfirmed: c.startEmergency,
              ),
              const Text('Yanlışlıkla çalmasın diye 2 saniye basılı tutun.', style: TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayBells extends StatelessWidget {
  const _TodayBells({required this.controller, required this.day, required this.next, required this.now, required this.onEdit});

  final AppController controller;
  final DaySchedule day;
  final UpcomingBell? next;
  final DateTime now;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final lastLog = controller.logs.firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bugünün zilleri', style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        day.isSchoolDay ? '${day.bells.length} zil · ${day.template!.name}' : 'Bugün zil çalmayacak',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onEdit, child: const Text('Programı gör')),
              ],
            ),
          ),
          if (!day.isSchoolDay)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
              child: Column(
                children: [
                  const Icon(Icons.event_busy, size: 40, color: AppColors.inkMuted),
                  const SizedBox(height: 8),
                  Text(day.offReason ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else
            for (final bell in day.bells) _BellRow(bell: bell, day: day, now: now, next: next, outcome: controller.outcomeOf(day, bell)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            child: Text(
              lastLog == null
                  ? 'Henüz kayıt yok'
                  : 'Son olay: ${_hm(lastLog.at)} · ${lastLog.bell.label} · ${lastLog.outcome.label}',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BellRow extends StatelessWidget {
  const _BellRow({required this.bell, required this.day, required this.now, required this.next, required this.outcome});

  final BellEvent bell;
  final DaySchedule day;
  final DateTime now;
  final UpcomingBell? next;
  final BellOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    final isNext = next != null && isSameDay(next.day.date, day.date) && next.bell.id == bell.id;
    final isPast = !day.timeOf(bell).isAfter(now);
    final textColor = isNext ? AppColors.lessonText : (isPast ? AppColors.inkMuted : AppColors.ink);
    final (pillBg, pillFg, pillText) = switch (bell.type) {
      BellType.lessonStart => (AppColors.lessonTint, AppColors.lessonText, 'Giriş'),
      BellType.lessonEnd => (AppColors.recessTint, AppColors.recessText, 'Çıkış'),
      BellType.dayEnd => (AppColors.okTint, AppColors.okText, 'Okul çıkışı'),
      BellType.teacher => (AppColors.neutralTint, AppColors.inkSecondary, 'Öğretmen'),
      BellType.assembly => (AppColors.neutralTint, AppColors.inkSecondary, 'Toplanma'),
      _ => (AppColors.lessonTint, AppColors.lessonText, bell.type.label),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isNext ? AppColors.lessonTint : null,
        border: Border(
          top: const BorderSide(color: AppColors.lineSoft),
          left: BorderSide(color: isNext ? AppColors.lesson : Colors.transparent, width: 4),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(bell.time.toString(),
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFeatures: tabularFigures)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_shortLabel(bell),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontWeight: isNext ? FontWeight.w600 : FontWeight.w400)),
          ),
          Opacity(opacity: isPast && !isNext ? 0.7 : 1, child: Pill(pillText, background: pillBg, foreground: pillFg)),
          SizedBox(width: 84, child: Align(alignment: Alignment.centerRight, child: _status(isNext, isPast))),
        ],
      ),
    );
  }

  /// Zil türü yandaki etikette yazdığı için satırda yalnızca "1. ders" kalır.
  static String _shortLabel(BellEvent bell) {
    for (final suffix in const [' öğretmen zili', ' çıkış (okul çıkışı)', ' giriş', ' çıkış']) {
      if (bell.label.endsWith(suffix)) return bell.label.substring(0, bell.label.length - suffix.length);
    }
    return bell.label;
  }

  Widget? _status(bool isNext, bool isPast) {
    if (isNext) return const Pill('Sıradaki', background: AppColors.lesson, foreground: Colors.white);
    final (icon, color, label) = switch (outcome) {
      BellOutcome.played => (Icons.check, AppColors.ok, 'Çaldı'),
      BellOutcome.missed => (Icons.warning_amber_rounded, AppColors.lunch, 'Kaçırıldı'),
      BellOutcome.muted => (Icons.notifications_off_outlined, AppColors.inkMuted, 'Susturuldu'),
      BellOutcome.failed => (Icons.error_outline, AppColors.danger, 'Hata'),
      null => isPast ? (Icons.remove, AppColors.inkMuted, 'Uygulama kapalıydı') : (null, null, null),
    };
    if (icon == null) return null;
    return Tooltip(message: label!, child: Icon(icon, size: 20, color: color));
  }
}

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _hms(DateTime t) => '${_hm(t)}:${t.second.toString().padLeft(2, '0')}';
