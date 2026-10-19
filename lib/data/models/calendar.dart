import '../../core/clock_time.dart';
import '../../core/date_utils.dart';
import 'bell_event.dart';

/// Zil çalmayacak tarih aralığı (bitiş günü dahil).
class Holiday {
  Holiday({
    required this.name,
    required DateTime start,
    required DateTime end,
  })  : start = dateOnly(start),
        end = dateOnly(end);

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
        name: json['name'] as String,
        start: parseDateKey(json['start'] as String),
        end: parseDateKey(json['end'] as String),
      );

  final String name;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final d = dateOnly(date);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'start': dateKey(start),
        'end': dateKey(end),
      };
}

/// Tek bir gün için haftalık planın ve tatillerin önüne geçen istisna.
class DateOverride {
  DateOverride({required DateTime date, this.templateId, this.note})
      : date = dateOnly(date);

  factory DateOverride.fromJson(Map<String, dynamic> json) => DateOverride(
        date: parseDateKey(json['date'] as String),
        templateId: json['templateId'] as String?,
        note: json['note'] as String?,
      );

  final DateTime date;

  /// Null ise o gün hiç zil çalmaz.
  final String? templateId;
  final String? note;

  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'templateId': templateId,
        'note': note,
      };
}

enum Recurrence { once, weekly, yearly }

/// Ders zillerinden bağımsız etkinlik: İstiklal Marşı, 10 Kasım saygı
/// duruşu, anons vb. Yalnızca zil programı olan (okul olan) günlerde çalar.
class SpecialEvent {
  SpecialEvent({
    required this.id,
    required this.name,
    required this.time,
    required this.recurrence,
    this.soundId,
    this.enabled = true,
    DateTime? date,
    this.weekdays = const {},
    this.month,
    this.day,
    this.loopSeconds,
  }) : date = date == null ? null : dateOnly(date);

  factory SpecialEvent.fromJson(Map<String, dynamic> json) => SpecialEvent(
        id: json['id'] as String,
        name: json['name'] as String,
        time: ClockTime.parse(json['time'] as String),
        recurrence: Recurrence.values.byName(json['recurrence'] as String),
        soundId: json['soundId'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        date: json['date'] == null
            ? null
            : parseDateKey(json['date'] as String),
        weekdays: {
          for (final w in (json['weekdays'] as List? ?? const [])) (w as num).toInt(),
        },
        month: (json['month'] as num?)?.toInt(),
        day: (json['day'] as num?)?.toInt(),
        loopSeconds: (json['loopSeconds'] as num?)?.toInt(),
      );

  final String id;
  final String name;
  final ClockTime time;
  final Recurrence recurrence;
  final String? soundId;
  final bool enabled;

  /// [Recurrence.once] için tarih.
  final DateTime? date;

  /// [Recurrence.weekly] için günler (1 = Pazartesi ... 7 = Pazar).
  final Set<int> weekdays;

  /// [Recurrence.yearly] için ay ve gün.
  final int? month;
  final int? day;

  /// Doluysa ses bu kadar saniye tekrarlanır (ör. 10 Kasım sireni).
  final int? loopSeconds;

  SpecialEvent copyWith({bool? enabled, String? Function()? soundId, int? Function()? loopSeconds}) => SpecialEvent(
        id: id,
        name: name,
        time: time,
        recurrence: recurrence,
        soundId: soundId == null ? this.soundId : soundId(),
        enabled: enabled ?? this.enabled,
        date: date,
        weekdays: weekdays,
        month: month,
        day: day,
        loopSeconds: loopSeconds == null ? this.loopSeconds : loopSeconds(),
      );

  bool occursOn(DateTime d) => switch (recurrence) {
        Recurrence.once => date != null && isSameDay(date!, d),
        Recurrence.weekly => weekdays.contains(d.weekday),
        Recurrence.yearly => d.month == month && d.day == day,
      };

  BellEvent toBellEvent() => BellEvent(
        id: 'special-$id',
        time: time,
        type: BellType.special,
        label: name,
        soundId: soundId,
        loopSeconds: loopSeconds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'time': time.toString(),
        'recurrence': recurrence.name,
        'soundId': soundId,
        'enabled': enabled,
        'date': date == null ? null : dateKey(date!),
        'weekdays': weekdays.toList()..sort(),
        'month': month,
        'day': day,
        'loopSeconds': loopSeconds,
      };
}
