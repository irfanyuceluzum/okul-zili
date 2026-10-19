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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Yumuşak gölgeli beyaz yüzey (çizgi yerine derinlik).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.color = AppColors.surface, this.radius = 20});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppShadows.card,
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );
}

/// Yuvarlak köşeli renkli zemin üstünde simge (kart başlıkları, bilgi kutuları).
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.background = AppColors.lessonTint, this.foreground = AppColors.lesson, this.size = 36});

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(icon, size: size * 0.55, color: foreground),
      );
}

/// Başlıklı beyaz kart. [icon] verilirse başlığın solunda renkli rozet olur.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 22),
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 14),
              child: Row(
                crossAxisAlignment: subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[IconBadge(icon!), const SizedBox(width: 14)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: theme.textTheme.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(height: 1.35)),
                        ],
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

/// Yumuşak dolgulu açılır seçim kutusu (alt çizgisiz). İçeride standart
/// [DropdownButton] durur.
class SoftDropdown<T> extends StatelessWidget {
  const SoftDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.isExpanded = false,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? hint;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        padding: const EdgeInsets.only(left: 14, right: 8),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            hint: hint,
            isExpanded: isExpanded,
            borderRadius: BorderRadius.circular(14),
            dropdownColor: AppColors.surface,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.inkSecondary),
            style: const TextStyle(fontFamily: appFontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink),
          ),
        ),
      );
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
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.55), width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: AlignmentDirectional.centerStart,
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
/// [dark] pano için; [onColor] renk geçişli kartın üstünde (beyaz tonlar).
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.day, required this.now, this.dark = false, this.onColor});

  final DaySchedule day;
  final DateTime now;
  final bool dark;

  /// Doluysa şerit bu rengin tonlarıyla çizilir (ör. lacivert kart üstünde beyaz).
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final t = day.template;
    if (t == null || t.lessons.isEmpty) return const SizedBox.shrink();
    final start = (t.assemblyTime ?? t.lessons.first.start).on(day.date);
    final end = t.lessons.last.end.on(day.date);
    final total = end.difference(start).inSeconds;
    final pos = total <= 0 ? 0.0 : (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
    final showMarker = !now.isBefore(start) && now.isBefore(end);
    final on = onColor;
    final labelColor = on?.withValues(alpha: 0.85) ?? (dark ? AppColors.panoTextSecondary : AppColors.lessonText);
    final markerColor = on ?? (dark ? AppColors.panoText : AppColors.ink);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: CustomPaint(
            painter: _TimelinePainter(
              segments: _segments(t, on),
              position: showMarker ? pos : null,
              marker: markerColor,
              pastShade: on == null
                  ? (dark ? AppColors.panoGround : Colors.white).withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.0),
              dimPast: on != null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        DefaultTextStyle.merge(
          style: TextStyle(fontSize: 13, color: labelColor, fontFeatures: tabularFigures, fontWeight: FontWeight.w500),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('${t.assemblyTime ?? t.lessons.first.start}'), Text('${t.lessons.last.end}')],
          ),
        ),
      ],
    );
  }

  List<_Segment> _segments(ScheduleTemplate t, Color? on) {
    final lesson = on ?? (dark ? AppColors.panoLesson : AppColors.lesson);
    final out = <_Segment>[];
    final first = t.lessons.first.start;
    if (t.assemblyTime != null && t.assemblyTime! < first) {
      out.add(_Segment(first.inMinutes - t.assemblyTime!.inMinutes,
          on?.withValues(alpha: 0.35) ?? AppColors.assembly));
    }
    for (var i = 0; i < t.lessons.length; i++) {
      final l = t.lessons[i];
      out.add(_Segment(l.end.inMinutes - l.start.inMinutes, lesson));
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

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.segments,
    required this.position,
    required this.marker,
    required this.pastShade,
    required this.dimPast,
  });

  final List<_Segment> segments;
  final double? position;
  final Color marker;
  final Color pastShade;

  /// Renkli kart üstünde geçmiş kısım saydamlaştırılır (örtü yerine).
  final bool dimPast;

  static const _gap = 2.0;
  static const _barTop = 6.0;
  static const _barHeight = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final totalMinutes = segments.fold<int>(0, (a, s) => a + s.minutes);
    if (totalMinutes == 0) return;
    final usable = size.width - _gap * (segments.length - 1);
    final cut = position == null ? null : size.width * position!;
    final bar = RRect.fromRectAndRadius(Rect.fromLTWH(0, _barTop, size.width, _barHeight), const Radius.circular(8));
    canvas.save();
    canvas.clipRRect(bar);
    var x = 0.0;
    for (final s in segments) {
      final w = usable * s.minutes / totalMinutes;
      final rect = Rect.fromLTWH(x, _barTop, w, _barHeight);
      if (dimPast && cut != null && x + w <= cut) {
        canvas.drawRect(rect, Paint()..color = s.color.withValues(alpha: s.color.a * 0.4));
      } else if (dimPast && cut != null && x < cut) {
        canvas.drawRect(Rect.fromLTRB(x, _barTop, cut, _barTop + _barHeight),
            Paint()..color = s.color.withValues(alpha: s.color.a * 0.4));
        canvas.drawRect(Rect.fromLTRB(cut, _barTop, x + w, _barTop + _barHeight), Paint()..color = s.color);
      } else {
        canvas.drawRect(rect, Paint()..color = s.color);
      }
      x += w + _gap;
    }
    if (!dimPast && cut != null) {
      canvas.drawRect(Rect.fromLTWH(0, _barTop, cut, _barHeight), Paint()..color = pastShade);
    }
    canvas.restore();
    if (cut != null) {
      final markerRect = RRect.fromRectAndRadius(
          Rect.fromLTWH((cut - 2).clamp(0, size.width - 4), 0, 4, size.height), const Radius.circular(2));
      canvas.drawRRect(markerRect, Paint()..color = marker);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.position != position || old.segments.length != segments.length || old.marker != marker;
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
