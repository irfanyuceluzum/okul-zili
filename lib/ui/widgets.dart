import 'package:flutter/material.dart';

import '../core/scheduler/day_schedule.dart';
import '../data/models/schedule_template.dart';
import 'theme.dart';

enum ChipTone { ok, warning, danger, neutral }

/// Yuvarlak durum işareti ("Ses açık · %80").
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.icon, required this.label, this.tone = ChipTone.ok, this.tooltip});

  final IconData icon;
  final String label;
  final ChipTone tone;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.ok => (AppColors.okTint, AppColors.okText),
      ChipTone.warning => (AppColors.recessTint, AppColors.recessText),
      ChipTone.danger => (AppColors.dangerTint, AppColors.dangerText),
      ChipTone.neutral => (AppColors.neutralTint, AppColors.inkSecondary),
    };
    final chip = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Küçük etiket ("Giriş", "Tatil").
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Başlıklı beyaz kart.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.subtitle, this.trailing, required this.child, this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 20)});

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: theme.textTheme.titleMedium),
                        if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          Padding(
            padding: title == null ? padding : EdgeInsets.fromLTRB(padding.left, 0, padding.right, padding.bottom),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Sayfa başlığı ve açıklaması.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            if (subtitle != null)
              DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 15, color: AppColors.inkSecondary),
                child: subtitle!,
              ),
          ],
        ),
        ?trailing,
      ],
    );
  }
}

/// Basılı tutunca dolan ve süre sonunda [onConfirmed] çağıran düğme.
/// Acil durum gibi yanlışlıkla tetiklenmemesi gereken işlemler için.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.holdingLabel,
    required this.icon,
    required this.onConfirmed,
    this.duration = const Duration(seconds: 2),
  });

  final String label;
  final String holdingLabel;
  final IconData icon;
  final VoidCallback onConfirmed;
  final Duration duration;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onConfirmed();
        _progress.value = 0;
      }
    });

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _start() => _progress.forward(from: 0);
  void _cancel() {
    if (_progress.status != AnimationStatus.completed) _progress.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.label}, ${widget.duration.inSeconds} saniye basılı tutun',
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              final holding = _progress.value > 0;
              final remaining = widget.duration.inMilliseconds * (1 - _progress.value) / 1000;
              return Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progress.value,
                        child: const ColoredBox(color: Color(0xFFF6C7C7)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, color: AppColors.dangerText, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            holding ? '${widget.holdingLabel} ${remaining.toStringAsFixed(1).replaceAll('.', ',')} sn' : widget.label,
                            style: const TextStyle(color: AppColors.dangerText, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Günün ders/teneffüs çizelgesi: renkli şerit ve "şimdi" işareti.
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.day, required this.now, this.dark = false});

  final DaySchedule day;
  final DateTime now;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = day.template;
    if (t == null || t.lessons.isEmpty) return const SizedBox.shrink();
    final segments = _segments(t);
    final start = (t.assemblyTime ?? t.lessons.first.start).on(day.date);
    final end = t.lessons.last.end.on(day.date);
    final total = end.difference(start).inSeconds;
    final pos = (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
    final showMarker = !now.isBefore(start) && now.isBefore(end);
    final labelColor = dark ? AppColors.panoTextSecondary : AppColors.lessonText;
    final markerColor = dark ? AppColors.panoText : AppColors.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: LayoutBuilder(builder: (context, c) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0, right: 0, top: 6, height: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        for (var i = 0; i < segments.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(flex: segments[i].minutes, child: ColoredBox(color: segments[i].color)),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showMarker) ...[
                  Positioned(
                    left: 0, top: 6, height: 20, width: c.maxWidth * pos,
                    child: ColoredBox(color: (dark ? AppColors.panoGround : AppColors.lessonTint).withValues(alpha: 0.55)),
                  ),
                  Positioned(
                    left: c.maxWidth * pos - 1.5, top: 0, width: 3, height: 32,
                    child: DecoratedBox(decoration: BoxDecoration(color: markerColor, borderRadius: BorderRadius.circular(2))),
                  ),
                ],
              ],
            );
          }),
        ),
        const SizedBox(height: 6),
        DefaultTextStyle(
          style: TextStyle(fontSize: 13, color: labelColor, fontFeatures: tabularFigures),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('${t.assemblyTime ?? t.lessons.first.start}'), Text('${t.lessons.last.end}')],
          ),
        ),
      ],
    );
  }

  List<_Segment> _segments(ScheduleTemplate t) {
    final out = <_Segment>[];
    final first = t.lessons.first.start;
    if (t.assemblyTime != null && t.assemblyTime! < first) {
      out.add(_Segment(first.inMinutes - t.assemblyTime!.inMinutes, AppColors.assembly));
    }
    for (var i = 0; i < t.lessons.length; i++) {
      final l = t.lessons[i];
      out.add(_Segment(l.end.inMinutes - l.start.inMinutes, dark ? AppColors.panoLesson : AppColors.lesson));
      if (i < t.lessons.length - 1) {
        final gap = t.lessons[i + 1].start.inMinutes - l.end.inMinutes;
        if (gap > 0) {
          final lunch = t.lunchAfterLesson == i + 1;
          out.add(_Segment(gap, lunch ? AppColors.lunch : AppColors.recess));
        }
      }
    }
    return out.where((s) => s.minutes > 0).toList();
  }
}

class _Segment {
  const _Segment(this.minutes, this.color);

  final int minutes;
  final Color color;
}

/// Lejant için küçük renkli kare ve etiket.
class LegendDot extends StatelessWidget {
  const LegendDot(this.color, this.label, {super.key, this.textColor});

  final Color color;
  final String label;
  final Color? textColor;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: textColor)),
        ],
      );
}
