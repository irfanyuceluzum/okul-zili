import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/data/models/notices.dart';

void main() {
  final now = DateTime(2026, 10, 15, 14, 30);

  test('duyuru ve nöbet JSON gidiş-dönüşü bozulmaz', () {
    final config = createDefaultConfig().copyWith(
      announcements: [
        Announcement(id: 'a1', text: 'Veli toplantısı', endDate: DateTime(2026, 10, 20)),
        Announcement(id: 'a2', text: 'Süresiz', enabled: false),
      ],
      dutyRoster: const [
        DutyEntry(weekday: 1, place: 'Bahçe', teacher: 'Ayşe Hoca'),
        DutyEntry(weekday: 1, place: 'Kantin', teacher: 'Ali Hoca'),
      ],
    );
    final back = AppConfig.fromJson(jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>);

    expect(back.announcements.length, 2);
    expect(back.announcements[0].id, 'a1');
    expect(back.announcements[0].text, 'Veli toplantısı');
    expect(back.announcements[0].endDate, DateTime(2026, 10, 20));
    expect(back.announcements[1].endDate, isNull);
    expect(back.announcements[1].enabled, isFalse);
    expect(back.dutyRoster.map((d) => '${d.weekday}/${d.place}/${d.teacher}'), ['1/Bahçe/Ayşe Hoca', '1/Kantin/Ali Hoca']);
    expect(config.toJson()['announcements'][0]['endDate'], '2026-10-20');
    expect(jsonEncode(back.toJson()), jsonEncode(config.toJson()));
  });

  test('activeAnnouncements: süresi dolan, kapalı ve boş metinli elenir; bugün bitenler kalır', () {
    final config = createDefaultConfig().copyWith(announcements: [
      Announcement(id: 'dun', text: 'Dün bitti', endDate: DateTime(2026, 10, 14)),
      Announcement(id: 'bugun', text: 'Bugün bitiyor', endDate: DateTime(2026, 10, 15)),
      Announcement(id: 'suresiz', text: 'Süresiz'),
      Announcement(id: 'kapali', text: 'Kapalı', enabled: false),
      Announcement(id: 'bos', text: '   '),
    ]);
    expect(config.activeAnnouncements(now).map((a) => a.id), ['bugun', 'suresiz']);
  });

  test('dutiesOn: o günün nöbetleri girildiği sırada gelir', () {
    final config = createDefaultConfig().copyWith(dutyRoster: const [
      DutyEntry(weekday: 2, place: 'Bahçe', teacher: 'B'),
      DutyEntry(weekday: 3, place: 'Koridor', teacher: 'C'),
      DutyEntry(weekday: 2, place: 'Kantin', teacher: 'A'),
    ]);
    expect(config.dutiesOn(2).map((d) => d.teacher), ['B', 'A']);
    expect(config.dutiesOn(3).length, 1);
    expect(config.dutiesOn(5), isEmpty);
  });

  test('bu alanlar olmayan eski config aynen yüklenir', () {
    final json = jsonDecode(jsonEncode(createDefaultConfig().toJson())) as Map<String, dynamic>
      ..remove('announcements')
      ..remove('dutyRoster');
    final warnings = <String>[];
    final config = AppConfig.fromJson(json, warnings: warnings);
    expect(config.announcements, isEmpty);
    expect(config.dutyRoster, isEmpty);
    expect(warnings, isEmpty);
    expect(config.templates, isNotEmpty);
  });

  test('bozuk duyuru ve nöbet kaydı atlanır, uyarı verilir', () {
    final json = jsonDecode(jsonEncode(createDefaultConfig().toJson())) as Map<String, dynamic>;
    json['announcements'] = [
      {'id': 'iyi', 'text': 'Sağlam'},
      {'id': 'bozuk', 'text': 'Tarih bozuk', 'endDate': 'yarın'},
      {'text': 'kimliksiz'},
    ];
    json['dutyRoster'] = [
      {'weekday': 1, 'place': 'Bahçe', 'teacher': 'X'},
      {'weekday': 'pazartesi', 'place': 'Kantin', 'teacher': 'Y'},
    ];
    final warnings = <String>[];
    final config = AppConfig.fromJson(json, warnings: warnings);
    expect(config.announcements.map((a) => a.id), ['iyi']);
    expect(config.dutyRoster.length, 1);
    expect(warnings.single, allOf(contains('2 duyuru'), contains('1 nöbet')));
  });
}
