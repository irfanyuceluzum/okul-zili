import '../../data/models/app_config.dart';
import '../../data/models/bell_event.dart';
import '../../data/models/schedule_template.dart';
import '../date_utils.dart';

enum PeriodKind { noSchool, beforeSchool, lesson, breakTime, lunch, afterSchool }

/// Ekranda gösterilen "şu an ne var" bilgisi.
class PeriodStatus {
  const PeriodStatus(this.kind, this.title, {this.startsAt, this.endsAt, this.untilLabel});

  final PeriodKind kind;
  final String title;

  /// Bu dönemin başlangıç ve bitiş anı (ders/teneffüs için); yoksa null.
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Bitişte ne başlayacağı: "Teneffüse", "3. derse", "Okul çıkışına".
  final String? untilLabel;

  /// Dönemin geçen kısmı (0.0–1.0); başlangıç/bitiş yoksa null.
  double? progressAt(DateTime now) {
    final s = startsAt, e = endsAt;
    if (s == null || e == null || !e.isAfter(s)) return null;
    return (now.difference(s).inMilliseconds / e.difference(s).inMilliseconds).clamp(0.0, 1.0);
  }
}

/// Belirli bir günün çözümlenmiş zil programı.
class DaySchedule {
  DaySchedule({
    required DateTime date,
    required this.template,
    required this.bells,
    this.offReason,
  }) : date = dateOnly(date);

  DaySchedule.off(DateTime date, String reason)
      : this(date: date, template: null, bells: const [], offReason: reason);

  final DateTime date;
  final ScheduleTemplate? template;

  /// Saat sırasına göre dizili.
  final List<BellEvent> bells;

  /// Zil çalmayan günlerde nedeni (ör. "Cumhuriyet Bayramı").
  final String? offReason;

  bool get isSchoolDay => template != null;

  DateTime timeOf(BellEvent bell) => bell.time.on(date);

  PeriodStatus statusAt(DateTime now) {
    final t = template;
    if (t == null) return PeriodStatus(PeriodKind.noSchool, offReason ?? 'Zil yok');
    if (t.lessons.isEmpty) return const PeriodStatus(PeriodKind.noSchool, 'Ders yok');

    final lessons = t.lessons;
    final firstStart = lessons.first.start.on(date);
    if (now.isBefore(firstStart)) {
      final assembly = t.assemblyTime?.on(date);
      final inAssembly = assembly != null && !now.isBefore(assembly);
      return PeriodStatus(
        PeriodKind.beforeSchool,
        inAssembly ? 'Toplanma' : 'Dersler başlamadı',
        startsAt: inAssembly ? assembly : null,
        endsAt: firstStart,
        untilLabel: 'Derslerin başlamasına',
      );
    }

    for (var i = 0; i < lessons.length; i++) {
      final n = i + 1;
      final start = lessons[i].start.on(date);
      final end = lessons[i].end.on(date);
      final isLast = i == lessons.length - 1;
      if (!now.isBefore(start) && now.isBefore(end)) {
        final until = isLast
            ? 'Okul çıkışına'
            : t.lunchAfterLesson == n
                ? 'Öğle arasına'
                : 'Teneffüse';
        return PeriodStatus(PeriodKind.lesson, '$n. Ders',
            startsAt: start, endsAt: end, untilLabel: until);
      }
      if (!isLast) {
        final nextStart = lessons[i + 1].start.on(date);
        if (!now.isBefore(end) && now.isBefore(nextStart)) {
          final lunch = t.lunchAfterLesson == n;
          return PeriodStatus(
            lunch ? PeriodKind.lunch : PeriodKind.breakTime,
            lunch ? 'Öğle Arası' : 'Teneffüs',
            startsAt: end,
            endsAt: nextStart,
            untilLabel: '${n + 1}. derse',
          );
        }
      }
    }
    return const PeriodStatus(PeriodKind.afterSchool, 'Dersler bitti');
  }
}

/// Bir sonraki zil ve ait olduğu gün.
class UpcomingBell {
  const UpcomingBell(this.day, this.bell);

  final DaySchedule day;
  final BellEvent bell;

  DateTime get at => day.timeOf(bell);
}

/// Ayarlara bakarak herhangi bir günün zil programını çıkarır.
///
/// Öncelik sırası: tarih istisnası → tatil → haftalık plan.
class ScheduleResolver {
  const ScheduleResolver(this.config);

  final AppConfig config;

  DaySchedule resolve(DateTime date) {
    final day = dateOnly(date);

    final override =
        config.overrides.where((o) => isSameDay(o.date, day)).firstOrNull;
    final String? templateId;
    final String offReason;
    if (override != null) {
      templateId = override.templateId;
      offReason = override.note ?? 'Bugün zil çalmayacak';
    } else {
      final holiday = config.holidays.where((h) => h.contains(day)).firstOrNull;
      if (holiday != null) return DaySchedule.off(day, holiday.name);
      templateId = config.weekPlan[day.weekday];
      offReason = day.weekday >= DateTime.saturday
          ? 'Hafta sonu'
          : 'Bu gün için zil programı yok';
    }

    final template = templateId == null ? null : config.templateById(templateId);
    if (template == null) return DaySchedule.off(day, offReason);

    final specials = config.specialEvents
        .where((e) => e.enabled && e.occursOn(day))
        .map((e) => e.toBellEvent());
    // Özel etkinlikler, aynı saatteki ders zillerinden sonra gelir.
    final bells = [...template.generateBells(), ...specials];
    final indexed = bells.asMap().entries.toList()
      ..sort((a, b) {
        final byTime = a.value.time.compareTo(b.value.time);
        return byTime != 0 ? byTime : a.key.compareTo(b.key);
      });

    return DaySchedule(
      date: day,
      template: template,
      bells: [for (final e in indexed) e.value],
    );
  }

  /// [now] anından sonraki ilk zili, en fazla [searchDays] gün ileriye
  /// bakarak bulur (uzun tatillerde null dönebilir).
  UpcomingBell? nextBell(DateTime now, {int searchDays = 30}) {
    final today = dateOnly(now);
    for (var i = 0; i <= searchDays; i++) {
      final day = resolve(DateTime(today.year, today.month, today.day + i));
      for (final bell in day.bells) {
        if (day.timeOf(bell).isAfter(now)) return UpcomingBell(day, bell);
      }
    }
    return null;
  }
}
