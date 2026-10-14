import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/core/clock_time.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/bell_event.dart';
import 'package:okul_zili/data/models/schedule_template.dart';

void main() {
  group('ClockTime', () {
    test('iki nokta ve nokta ayracını çözümler', () {
      expect(ClockTime.parse('08:40'), const ClockTime(8, 40));
      expect(ClockTime.parse('08.30'), const ClockTime(8, 30));
    });

    test('geçersiz saatleri reddeder', () {
      expect(() => ClockTime.parse('24:00'), throwsFormatException);
      expect(() => ClockTime.parse('8'), throwsFormatException);
      expect(() => ClockTime.parse('ab:cd'), throwsFormatException);
    });

    test('gün dışına taşan kaydırma null döner', () {
      expect(const ClockTime(0, 1).tryAddMinutes(-2), isNull);
      expect(const ClockTime(8, 40).tryAddMinutes(-2), const ClockTime(8, 38));
    });
  });

  group('Normal gün şablonu', () {
    final bells = normalDayTemplate.generateBells();

    test('geçerli', () {
      expect(normalDayTemplate.validate(), isEmpty);
    });

    test('toplanma + 6 ders × (öğretmen, giriş, çıkış) = 19 zil', () {
      expect(bells, hasLength(19));
    });

    test('ziller saat sırasında ve fotoğraftaki programla aynı', () {
      expect(
        bells.map((b) => '${b.time} ${b.type.name}').toList(),
        [
          '08:30 assembly',
          '08:38 teacher', '08:40 lessonStart', '09:20 lessonEnd',
          '09:33 teacher', '09:35 lessonStart', '10:15 lessonEnd',
          '10:33 teacher', '10:35 lessonStart', '11:15 lessonEnd',
          '11:28 teacher', '11:30 lessonStart', '12:10 lessonEnd',
          '12:38 teacher', '12:40 lessonStart', '13:20 lessonEnd',
          '13:33 teacher', '13:35 lessonStart', '14:15 dayEnd',
        ],
      );
    });

    test('zil kimlikleri benzersiz', () {
      expect(bells.map((b) => b.id).toSet(), hasLength(bells.length));
    });
  });

  group('Öğretmen zili', () {
    test('0 dakika ise üretilmez', () {
      final t = ScheduleTemplate(
        id: 'x',
        name: 'x',
        teacherBellMinutesBefore: 0,
        lessons: [Lesson(ClockTime.parse('08:40'), ClockTime.parse('09:20'))],
      );
      expect(t.generateBells().where((b) => b.type == BellType.teacher), isEmpty);
    });

    test('teneffüs öğretmen zilinden kısaysa üretilmez', () {
      final t = ScheduleTemplate(
        id: 'x',
        name: 'x',
        teacherBellMinutesBefore: 5,
        lessons: [
          Lesson(ClockTime.parse('08:40'), ClockTime.parse('09:20')),
          Lesson(ClockTime.parse('09:23'), ClockTime.parse('10:00')),
        ],
      );
      final teacher = t.generateBells().where((b) => b.type == BellType.teacher);
      expect(teacher.map((b) => b.id), ['L1-teacher']);
    });
  });

  test('kısa teneffüs ve aynı dakikadaki ziller için uyarı verilir', () {
    final t = ScheduleTemplate(
      id: 'x',
      name: 'x',
      teacherBellMinutesBefore: 2,
      lessons: [
        Lesson(ClockTime.parse('08:40'), ClockTime.parse('09:20')),
        Lesson(ClockTime.parse('09:20'), ClockTime.parse('10:00')),
        Lesson(ClockTime.parse('10:02'), ClockTime.parse('10:40')),
      ],
    );
    expect(t.validate(), isEmpty);
    expect(t.notes(), [
      contains('teneffüs yok'),
      contains('3. ders öğretmen zili çalmayacak'),
    ]);
    expect(normalDayTemplate.notes(), isEmpty);
  });

  group('Süre tabanlı kaydırma', () {
    String fmt(ScheduleTemplate t) => t.lessons.map((l) => '$l').join(' ');

    test('withLessonMinutes sonraki dersleri kaydırır, teneffüsler sabit kalır', () {
      final t = normalDayTemplate.withLessonMinutes(1, 45)!;
      expect(t.validate(), isEmpty);
      expect(t.lessons[1].toString(), '09:35–10:20');
      expect(t.lessons[2].toString(), '10:40–11:20');
      expect(t.lessons[5].toString(), '13:40–14:20');
      expect(t.lessons[0], normalDayTemplate.lessons[0]);
      for (var i = 1; i < t.lessons.length; i++) {
        expect(
          t.lessons[i].start.inMinutes - t.lessons[i - 1].end.inMinutes,
          normalDayTemplate.lessons[i].start.inMinutes - normalDayTemplate.lessons[i - 1].end.inMinutes,
        );
      }
    });

    test('withBreakMinutes sonraki dersleri kaydırır, ders süreleri sabit kalır', () {
      final t = normalDayTemplate.withBreakMinutes(0, 20)!;
      expect(t.validate(), isEmpty);
      expect(t.lessons[1].toString(), '09:40–10:20');
      expect(t.lessons[5].toString(), '13:40–14:20');
      expect(t.lessons.map((l) => l.minutes), normalDayTemplate.lessons.map((l) => l.minutes));
      expect(t.lessons[0], normalDayTemplate.lessons[0]);
    });

    test('diğer alanlar değişmez', () {
      final base = normalDayTemplate.copyWith(lunchAfterLesson: () => 4);
      for (final t in [base.withLessonMinutes(0, 50)!, base.withBreakMinutes(2, 3)!]) {
        expect(t.id, base.id);
        expect(t.name, base.name);
        expect(t.assemblyTime, base.assemblyTime);
        expect(t.teacherBellMinutesBefore, base.teacherBellMinutesBefore);
        expect(t.lunchAfterLesson, 4);
      }
    });

    test('taşma ve geçersiz girdi null döner', () {
      expect(normalDayTemplate.withLessonMinutes(0, 1000), isNull);
      expect(normalDayTemplate.withBreakMinutes(0, 1000), isNull);
      expect(normalDayTemplate.withLessonMinutes(0, 0), isNull);
      expect(normalDayTemplate.withLessonMinutes(6, 40), isNull);
      expect(normalDayTemplate.withLessonMinutes(-1, 40), isNull);
      expect(normalDayTemplate.withBreakMinutes(0, -1), isNull);
      expect(normalDayTemplate.withBreakMinutes(5, 10), isNull);
      expect(normalDayTemplate.withBreakMinutes(-1, 10), isNull);
      expect(fmt(normalDayTemplate.withBreakMinutes(0, 15)!), fmt(normalDayTemplate));
    });
  });

  test('çakışan dersler doğrulamada yakalanır', () {
    final t = ScheduleTemplate(
      id: 'x',
      name: 'x',
      lessons: [
        Lesson(ClockTime.parse('08:40'), ClockTime.parse('09:20')),
        Lesson(ClockTime.parse('09:10'), ClockTime.parse('09:50')),
        Lesson(ClockTime.parse('10:30'), ClockTime.parse('10:00')),
      ],
    );
    expect(t.validate(), hasLength(2));
  });
}
