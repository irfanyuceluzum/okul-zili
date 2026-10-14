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
