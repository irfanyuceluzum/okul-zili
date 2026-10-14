import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/core/clock_time.dart';
import 'package:okul_zili/core/scheduler/day_schedule.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/data/models/bell_event.dart';
import 'package:okul_zili/data/models/calendar.dart';
import 'package:okul_zili/data/models/schedule_template.dart';

AppConfig _configWith({
  List<Holiday>? holidays,
  List<DateOverride>? overrides,
  List<SpecialEvent>? specials,
}) {
  final base = createDefaultConfig();
  return AppConfig(
    schoolName: base.schoolName,
    templates: [
      ...base.templates,
      ScheduleTemplate(
        id: 'kisa',
        name: 'Kısaltılmış Gün',
        lessons: [Lesson(ClockTime.parse('08:40'), ClockTime.parse('09:10'))],
      ),
    ],
    weekPlan: base.weekPlan,
    sounds: base.sounds,
    soundForType: base.soundForType,
    holidays: holidays ?? const [],
    overrides: overrides ?? const [],
    specialEvents: specials ?? const [],
  );
}

void main() {
  // 14 Ekim 2026 Çarşamba
  final wednesday = DateTime(2026, 10, 14);

  group('ScheduleResolver', () {
    test('hafta içi normal program', () {
      final day = ScheduleResolver(_configWith()).resolve(wednesday);
      expect(day.isSchoolDay, isTrue);
      expect(day.bells, hasLength(19));
    });

    test('hafta sonu zil yok', () {
      final day = ScheduleResolver(_configWith()).resolve(DateTime(2026, 10, 17));
      expect(day.isSchoolDay, isFalse);
      expect(day.offReason, 'Hafta sonu');
    });

    test('tatil günü zil yok ve tatil adı gösterilir', () {
      final day = ScheduleResolver(createDefaultConfig())
          .resolve(DateTime(2026, 10, 29, 10));
      expect(day.isSchoolDay, isFalse);
      expect(day.offReason, 'Cumhuriyet Bayramı');
    });

    test('çok günlük tatil iki ucu da kapsar', () {
      final config = _configWith(holidays: [
        Holiday(name: 'Ara tatil', start: DateTime(2026, 11, 9), end: DateTime(2026, 11, 13)),
      ]);
      final r = ScheduleResolver(config);
      expect(r.resolve(DateTime(2026, 11, 9)).isSchoolDay, isFalse);
      expect(r.resolve(DateTime(2026, 11, 13)).isSchoolDay, isFalse);
      expect(r.resolve(DateTime(2026, 11, 16)).isSchoolDay, isTrue);
    });

    test('istisna tatilin önüne geçer ve farklı şablon seçebilir', () {
      final config = _configWith(
        holidays: [Holiday(name: 'Tatil', start: wednesday, end: wednesday)],
        overrides: [DateOverride(date: wednesday, templateId: 'kisa')],
      );
      final day = ScheduleResolver(config).resolve(wednesday);
      expect(day.template?.id, 'kisa');
    });

    test('şablonsuz istisna o gün zili kapatır', () {
      final config = _configWith(overrides: [
        DateOverride(date: wednesday, note: 'Sınav günü'),
      ]);
      final day = ScheduleResolver(config).resolve(wednesday);
      expect(day.isSchoolDay, isFalse);
      expect(day.offReason, 'Sınav günü');
    });

    test('özel etkinlik okul günü eklenir, tatilde eklenmez', () {
      final marsi = SpecialEvent(
        id: 'marsi',
        name: 'İstiklal Marşı',
        time: ClockTime.parse('08:32'),
        recurrence: Recurrence.weekly,
        weekdays: {DateTime.monday},
      );
      final r = ScheduleResolver(_configWith(
        specials: [marsi],
        holidays: [Holiday(name: 'T', start: DateTime(2026, 10, 26), end: DateTime(2026, 10, 26))],
      ));
      final monday = r.resolve(DateTime(2026, 10, 19));
      expect(monday.bells.map((b) => b.id), contains('special-marsi'));
      expect(monday.bells[1].id, 'special-marsi', reason: 'toplanmadan hemen sonra');
      expect(r.resolve(wednesday).bells.any((b) => b.type == BellType.special), isFalse);
      expect(r.resolve(DateTime(2026, 10, 26)).bells, isEmpty);
    });

    test('kapalı özel etkinlik eklenmez', () {
      // Varsayılan 10 Kasım etkinliği kapalı gelir.
      final day = ScheduleResolver(createDefaultConfig()).resolve(DateTime(2026, 11, 10));
      expect(day.bells.any((b) => b.type == BellType.special), isFalse);
    });

    test('sıradaki zil hafta sonunu atlayıp pazartesiye geçer', () {
      final r = ScheduleResolver(_configWith());
      final next = r.nextBell(DateTime(2026, 10, 16, 15, 0)); // Cuma 15:00
      expect(next, isNotNull);
      expect(next!.at, DateTime(2026, 10, 19, 8, 30));
      expect(next.bell.type, BellType.assembly);
    });

    test('sıradaki zil tam zil anında bir sonrakini verir', () {
      final r = ScheduleResolver(_configWith());
      final next = r.nextBell(DateTime(2026, 10, 14, 8, 40));
      expect(next!.at, DateTime(2026, 10, 14, 9, 20));
    });
  });

  group('DaySchedule.statusAt', () {
    final day = ScheduleResolver(_configWith()).resolve(wednesday);
    PeriodStatus at(int h, int m) => day.statusAt(DateTime(2026, 10, 14, h, m));

    test('dönemler', () {
      expect(at(7, 50).title, 'Dersler başlamadı');
      expect(at(8, 35).title, 'Toplanma');
      expect(at(8, 40).title, '1. Ders');
      expect(at(9, 25).kind, PeriodKind.breakTime);
      expect(at(12, 20).title, 'Öğle Arası');
      expect(at(13, 40).title, '6. Ders');
      expect(at(14, 15).kind, PeriodKind.afterSchool);
    });

    test('bitiş anı doğru', () {
      expect(at(9, 0).endsAt, DateTime(2026, 10, 14, 9, 20));
      expect(at(10, 20).endsAt, DateTime(2026, 10, 14, 10, 35));
    });
  });

  test('AppConfig JSON gidiş-dönüşte bozulmaz', () {
    final original = _configWith(
      holidays: [Holiday(name: 'Ara tatil', start: DateTime(2026, 11, 9), end: DateTime(2026, 11, 13))],
      overrides: [DateOverride(date: wednesday, templateId: 'kisa', note: 'Veli toplantısı')],
      specials: createDefaultConfig().specialEvents,
    );
    final json = jsonEncode(original.toJson());
    final restored = AppConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
    expect(jsonEncode(restored.toJson()), json);
  });
}
