import '../core/clock_time.dart';
import 'models/app_config.dart';
import 'models/bell_event.dart';
import 'models/calendar.dart';
import 'models/schedule_template.dart';

ClockTime _t(String s) => ClockTime.parse(s);

/// Okulun mevcut ders programı.
final normalDayTemplate = ScheduleTemplate(
  id: 'normal',
  name: 'Normal Gün',
  assemblyTime: _t('08:30'),
  teacherBellMinutesBefore: 2,
  lunchAfterLesson: 4,
  lessons: [
    Lesson(_t('08:40'), _t('09:20')),
    Lesson(_t('09:35'), _t('10:15')),
    Lesson(_t('10:35'), _t('11:15')),
    Lesson(_t('11:30'), _t('12:10')),
    Lesson(_t('12:40'), _t('13:20')),
    Lesson(_t('13:35'), _t('14:15')),
  ],
);

/// İlk açılışta kullanılan ayarlar.
AppConfig createDefaultConfig() => AppConfig(
      schoolName: '',
      templates: [normalDayTemplate],
      weekPlan: const {
        DateTime.monday: 'normal',
        DateTime.tuesday: 'normal',
        DateTime.wednesday: 'normal',
        DateTime.thursday: 'normal',
        DateTime.friday: 'normal',
      },
      sounds: const [
        BellSound(id: 'zil', name: 'Klasik zil', path: 'sounds/zil.wav', isAsset: true),
        BellSound(id: 'gong', name: 'Ding-dong', path: 'sounds/gong.wav', isAsset: true),
        BellSound(id: 'alarm', name: 'Siren', path: 'sounds/alarm.wav', isAsset: true),
      ],
      soundForType: const {
        BellType.assembly: 'zil',
        BellType.teacher: 'gong',
        BellType.lessonStart: 'zil',
        BellType.lessonEnd: 'zil',
        BellType.dayEnd: 'zil',
        BellType.special: 'zil',
        BellType.manual: 'zil',
        BellType.emergency: 'alarm',
      },
      // Yalnızca tarihi her yıl aynı olan resmî tatiller. Ara tatiller,
      // yarıyıl tatili ve dinî bayramlar MEB çalışma takvimine göre eklenmeli.
      holidays: [
        Holiday(name: 'Cumhuriyet Bayramı', start: DateTime(2026, 10, 29), end: DateTime(2026, 10, 29)),
        Holiday(name: 'Yılbaşı', start: DateTime(2027, 1, 1), end: DateTime(2027, 1, 1)),
        Holiday(name: 'Ulusal Egemenlik ve Çocuk Bayramı', start: DateTime(2027, 4, 23), end: DateTime(2027, 4, 23)),
        Holiday(name: 'Emek ve Dayanışma Günü', start: DateTime(2027, 5, 1), end: DateTime(2027, 5, 1)),
        Holiday(name: 'Atatürk\'ü Anma, Gençlik ve Spor Bayramı', start: DateTime(2027, 5, 19), end: DateTime(2027, 5, 19)),
      ],
      specialEvents: [
        // Siren sesi eklenince etkinleştirilecek.
        SpecialEvent(
          id: '10-kasim',
          name: '10 Kasım saygı duruşu',
          time: _t('09:05'),
          recurrence: Recurrence.yearly,
          month: 11,
          day: 10,
          enabled: false,
        ),
      ],
    );
