import '../../core/clock_time.dart';
import 'bell_event.dart';

class Lesson {
  const Lesson(this.start, this.end);

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        ClockTime.parse(json['start'] as String),
        ClockTime.parse(json['end'] as String),
      );

  final ClockTime start;
  final ClockTime end;

  int get minutes => end.inMinutes - start.inMinutes;

  Map<String, dynamic> toJson() => {
        'start': start.toString(),
        'end': end.toString(),
      };

  @override
  bool operator ==(Object other) => other is Lesson && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start–$end';
}

/// Bir günün ders düzeni (ör. "Normal Gün", "Kısaltılmış Gün").
///
/// Kullanıcı yalnızca ders saatlerini girer; ziller bu şablondan üretilir.
class ScheduleTemplate {
  const ScheduleTemplate({
    required this.id,
    required this.name,
    required this.lessons,
    this.assemblyTime,
    this.teacherBellMinutesBefore = 2,
    this.lunchAfterLesson,
  });

  factory ScheduleTemplate.fromJson(Map<String, dynamic> json) =>
      ScheduleTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        assemblyTime: json['assemblyTime'] == null
            ? null
            : ClockTime.parse(json['assemblyTime'] as String),
        lessons: (json['lessons'] as List)
            .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList(),
        teacherBellMinutesBefore:
            json['teacherBellMinutesBefore'] as int? ?? 0,
        lunchAfterLesson: json['lunchAfterLesson'] as int?,
      );

  /// Eşit süreli ders ve teneffüslerle ders listesi üretir ("Hızlı doldur").
  /// [lunchAfter] 0 ya da null ise öğle arası yoktur. Ders gece yarısını
  /// geçerse [RangeError] fırlatır.
  static List<Lesson> generateLessons({
    required ClockTime firstStart,
    required int count,
    required int lessonMinutes,
    required int breakMinutes,
    int? lunchAfter,
    int lunchMinutes = 0,
  }) {
    final lessons = <Lesson>[];
    var start = firstStart.inMinutes;
    for (var n = 1; n <= count; n++) {
      final end = start + lessonMinutes;
      lessons.add(Lesson(ClockTime.fromMinutes(start), ClockTime.fromMinutes(end)));
      start = end + (n == lunchAfter ? lunchMinutes : breakMinutes);
    }
    return lessons;
  }

  ScheduleTemplate copyWith({
    String? id,
    String? name,
    ClockTime? Function()? assemblyTime,
    List<Lesson>? lessons,
    int? teacherBellMinutesBefore,
    int? Function()? lunchAfterLesson,
  }) =>
      ScheduleTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        assemblyTime: assemblyTime == null ? this.assemblyTime : assemblyTime(),
        lessons: lessons ?? this.lessons,
        teacherBellMinutesBefore: teacherBellMinutesBefore ?? this.teacherBellMinutesBefore,
        lunchAfterLesson: lunchAfterLesson == null ? this.lunchAfterLesson : lunchAfterLesson(),
      );

  final String id;
  final String name;

  /// Toplanma zili (ör. 08:30). Null ise çalmaz.
  final ClockTime? assemblyTime;
  final List<Lesson> lessons;

  /// Öğretmen zilinin dersten kaç dakika önce çalacağı. 0 ise çalmaz.
  final int teacherBellMinutesBefore;

  /// Bu dersten sonraki ara "Öğle Arası" olarak gösterilir (1'den başlar).
  final int? lunchAfterLesson;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assemblyTime': assemblyTime?.toString(),
        'lessons': lessons.map((l) => l.toJson()).toList(),
        'teacherBellMinutesBefore': teacherBellMinutesBefore,
        'lunchAfterLesson': lunchAfterLesson,
      };

  /// Şablondaki hataları Türkçe olarak döndürür; boş liste geçerli demektir.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('Şablonun adı boş olamaz.');
    if (lessons.isEmpty) errors.add('En az bir ders olmalı.');
    if (lunchAfterLesson != null && (lunchAfterLesson! < 1 || lunchAfterLesson! >= lessons.length)) {
      errors.add('Öğle arası, son dersten önceki bir dersten sonra olmalı.');
    }
    for (var i = 0; i < lessons.length; i++) {
      final l = lessons[i];
      if (l.end <= l.start) {
        errors.add('${i + 1}. dersin bitişi başlangıcından sonra olmalı.');
      }
      if (i > 0 && l.start < lessons[i - 1].end) {
        errors.add('${i + 1}. ders, $i. ders bitmeden başlıyor.');
      }
    }
    if (assemblyTime != null &&
        lessons.isNotEmpty &&
        assemblyTime! > lessons.first.start) {
      errors.add('Toplanma saati ilk dersten sonra olamaz.');
    }
    return errors;
  }

  /// Şablondan günün zillerini saat sırasıyla üretir.
  List<BellEvent> generateBells() {
    final bells = <BellEvent>[];
    if (assemblyTime != null) {
      bells.add(BellEvent(
        id: 'assembly',
        time: assemblyTime!,
        type: BellType.assembly,
        label: 'Toplanma',
      ));
    }

    for (var i = 0; i < lessons.length; i++) {
      final n = i + 1;
      final lesson = lessons[i];
      final isLast = i == lessons.length - 1;

      if (teacherBellMinutesBefore > 0) {
        final teacherTime = lesson.start.tryAddMinutes(-teacherBellMinutesBefore);
        // Öğretmen zili bir önceki zil anıyla çakışmamalı: ilk derste
        // toplanmadan, diğerlerinde önceki dersin bitişinden sonra olmalı.
        final previous = i == 0 ? assemblyTime : lessons[i - 1].end;
        if (teacherTime != null &&
            (previous == null || teacherTime > previous)) {
          bells.add(BellEvent(
            id: 'L$n-teacher',
            time: teacherTime,
            type: BellType.teacher,
            label: '$n. ders öğretmen zili',
          ));
        }
      }

      bells.add(BellEvent(
        id: 'L$n-start',
        time: lesson.start,
        type: BellType.lessonStart,
        label: '$n. ders giriş',
      ));
      bells.add(BellEvent(
        id: 'L$n-end',
        time: lesson.end,
        type: isLast ? BellType.dayEnd : BellType.lessonEnd,
        label: isLast ? '$n. ders çıkış (okul çıkışı)' : '$n. ders çıkış',
      ));
    }

    // sort kararlı değildir; aynı saatteki ziller için üretim sırasını koru.
    final indexed = bells.asMap().entries.toList()
      ..sort((a, b) {
        final byTime = a.value.time.compareTo(b.value.time);
        return byTime != 0 ? byTime : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }
}
