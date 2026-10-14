import '../../core/date_utils.dart';

/// Panoda gösterilen duyuru. [endDate] doluysa o gün dahil gösterilir;
/// boşsa süresizdir.
class Announcement {
  Announcement({
    required this.id,
    required this.text,
    DateTime? endDate,
    this.enabled = true,
  }) : endDate = endDate == null ? null : dateOnly(endDate);

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as String,
        text: json['text'] as String,
        endDate: json['endDate'] == null ? null : parseDateKey(json['endDate'] as String),
        enabled: json['enabled'] as bool? ?? true,
      );

  final String id;
  final String text;

  /// Gösterimin son günü (o gün dahil); null ise süresiz.
  final DateTime? endDate;
  final bool enabled;

  /// [endDate] null alanı da temizleyebilsin diye işlev alır.
  Announcement copyWith({
    String? text,
    DateTime? Function()? endDate,
    bool? enabled,
  }) =>
      Announcement(
        id: id,
        text: text ?? this.text,
        endDate: endDate == null ? this.endDate : endDate(),
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'endDate': endDate == null ? null : dateKey(endDate!),
        'enabled': enabled,
      };
}

/// Haftanın bir günü için nöbet yeri ve nöbetçi öğretmen.
class DutyEntry {
  const DutyEntry({required this.weekday, required this.place, required this.teacher});

  factory DutyEntry.fromJson(Map<String, dynamic> json) => DutyEntry(
        weekday: (json['weekday'] as num).toInt(),
        place: json['place'] as String,
        teacher: json['teacher'] as String,
      );

  /// 1 = Pazartesi ... 7 = Pazar.
  final int weekday;
  final String place;
  final String teacher;

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'place': place,
        'teacher': teacher,
      };
}
