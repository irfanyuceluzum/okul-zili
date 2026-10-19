import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/data/quotes.dart';
import 'package:okul_zili/data/special_days.dart';
import 'package:okul_zili/platform/weather.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

SpecialDay byId(String id) => builtInSpecialDays.firstWhere((s) => s.id == id);

DayRange inYear(String id, int year) => byId(id).rule.inYear(year)!;

const erzin = WeatherPlace(name: 'Erzin', region: 'Hatay', latitude: 36.95, longitude: 36.2);

WeatherReport report({double temp = 22.3, DateTime? at}) => WeatherReport(
      temperature: temp,
      code: 2,
      isDay: true,
      min: 16,
      max: 23,
      precipitationChance: 30,
      fetchedAt: at ?? DateTime(2026),
    );

void main() {
  group('Belirli gün kuralları (2026–2027 takvimiyle elle doğrulandı)', () {
    test('ayın n. günü', () {
      expect(inYear('anneler-gunu', 2026).start, d(2026, 5, 10));
      expect(inYear('anneler-gunu', 2027).start, d(2027, 5, 9));
      expect(inYear('babalar-gunu', 2026).start, d(2026, 6, 21));
      expect(inYear('ilk-yardim-gunu', 2026).start, d(2026, 9, 12));
    });

    test('ayın n. haftası ve son hafta (pazartesi–pazar)', () {
      final ilkogretim = inYear('ilkogretim-haftasi', 2026);
      expect(ilkogretim.start, d(2026, 9, 21));
      expect(ilkogretim.end, d(2026, 9, 27));
      expect(inYear('ogrenciler-gunu', 2026).start, d(2026, 9, 25), reason: 'haftanın son okul günü (cuma)');
      expect(inYear('kutuphaneler', 2027).start, d(2027, 3, 29));
      expect(inYear('kutuphaneler', 2027).end, d(2027, 4, 4));
      expect(inYear('vergi', 2027).start, d(2027, 2, 22));
      expect(inYear('enerji', 2027).start, d(2027, 1, 11));
    });

    test('ilk haftanın perşembesi ve günü içine alan hafta', () {
      expect(inYear('disleksi-gunu', 2026).start, d(2026, 10, 8));
      expect(inYear('yesilay', 2027).start, d(2027, 3, 1));
      expect(inYear('insan-haklari', 2026).start, d(2026, 12, 7));
      expect(inYear('insan-haklari', 2026).end, d(2026, 12, 13));
    });

    test('ay aşan aralık ve kaçıncı gün', () {
      final kizilay = inYear('kizilay', 2026);
      expect(kizilay.contains(d(2026, 11, 2)), isTrue);
      expect(kizilay.dayIndex(d(2026, 11, 2)), 5);
    });

    test('MEB çizelgesinin 69 maddesi ve farkındalık günleri; kimlikler benzersiz', () {
      expect(builtInSpecialDays.where((s) => s.category == SpecialDayCategory.meb), hasLength(69));
      expect(builtInSpecialDays.map((s) => s.id).toSet(), hasLength(builtInSpecialDays.length));
      expect(byId('down-sendromu').rule.inYear(2027)!.start, d(2027, 3, 21));
      expect(byId('down-sendromu').category, SpecialDayCategory.awareness);
    });

    test('bugünün günleri: önce tek günlükler, sonra haftalar; kapatılan ve tarihi girilen', () {
      final today = specialDaysOn(d(2027, 3, 22));
      expect(today.first.day.id, 'su-gunu');
      expect(today.map((t) => t.label), containsAll(['Yaşlılar Haftası · 5. gün', 'Orman Haftası · 2. gün']));

      expect(specialDaysOn(d(2027, 3, 22), disabled: {'su-gunu'}).map((t) => t.day.id), isNot(contains('su-gunu')));

      expect(specialDaysOn(d(2026, 8, 26)).map((t) => t.day.id), isNot(contains('mevlid-i-nebi')));
      final announced = {'mevlid-i-nebi': DayRange(d(2026, 8, 24), d(2026, 8, 30))};
      expect(specialDaysOn(d(2026, 8, 26), announced: announced).single.label, 'Mevlid-i Nebî Haftası · 3. gün');
    });
  });

  group('Günün sözü', () {
    test('aynı gün aynı söz; her üç günde bir Atatürk', () {
      expect(quoteForDay(d(2026, 10, 14)).text, quoteForDay(d(2026, 10, 14)).text);
      final week = [for (var i = 0; i < 9; i++) quoteForDay(d(2026, 10, 1 + i))];
      expect(week.where((q) => q.author == 'Atatürk'), hasLength(3));
    });

    test('belirli güne uygun söz', () {
      final kasim10 = quoteForDay(d(2026, 11, 10), specialDays: specialDaysOn(d(2026, 11, 10)));
      expect(kasim10.text, startsWith('Benim naçiz vücudum'));
      final nisan23 = quoteForDay(d(2027, 4, 23), specialDays: specialDaysOn(d(2027, 4, 23)));
      expect(nisan23.text, startsWith('Küçük hanımlar'));
    });

    test('listelerde tekrar ve boş söz yok; bir yıl boyunca hepsi kullanılır', () {
      for (final list in [ataturkQuotes, proverbs]) {
        expect(list.map((q) => q.text).toSet(), hasLength(list.length));
        expect(list.every((q) => q.text.trim().isNotEmpty), isTrue);
      }
      final seen = {for (var i = 0; i < 365; i++) quoteForDay(d(2026, 1, 1 + i)).text};
      expect(seen.length, greaterThan(140));
    });
  });

  group('Ayarlar', () {
    test('yeni alanlar JSON\'da korunur; eski dosyada varsayılanlar', () {
      final config = createDefaultConfig().copyWith(
        panoShowQuote: false,
        weatherPlace: () => erzin,
        disabledSpecialDays: {'su-gunu'},
        announcedSpecialDays: {'mevlid-i-nebi': DayRange(d(2026, 8, 24), d(2026, 8, 30))},
      );
      final back = AppConfig.fromJson(config.toJson());
      expect(back.panoShowQuote, isFalse);
      expect(back.panoShowWeather, isTrue);
      expect(back.weatherPlace!.label, 'Erzin, Hatay');
      expect(back.disabledSpecialDays, {'su-gunu'});
      expect(back.announcedSpecialDays['mevlid-i-nebi']!.end, d(2026, 8, 30));

      final old = createDefaultConfig().toJson()
        ..remove('panoShowWeather')
        ..remove('panoShowQuote');
      final parsed = AppConfig.fromJson(old);
      expect(parsed.panoShowWeather, isTrue);
      expect(parsed.weatherPlace, isNull);
    });
  });

  group('Hava durumu', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_hava'));
    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });

    var clock = DateTime(2026, 10, 19, 10);
    AppController make(FakeWeather w, {AppConfig? config}) => AppController(
          config: config ?? createDefaultConfig().copyWith(weatherPlace: () => erzin),
          repository: ConfigRepository(File('${tmp.path}/config.json')),
          player: SilentPlayer(),
          now: () => clock,
          weatherClient: w,
        );

    test('yenilenir, diske yazılır, yeni açılışta önbellekten okunur', () async {
      clock = DateTime(2026, 10, 19, 10);
      final c = make(FakeWeather(report: report()));
      await c.refreshWeather();
      expect(c.weather!.temperature, 22.3);
      expect(c.weather!.fetchedAt, clock, reason: 'zaman denetleyicinin saatinden');

      final again = make(FakeWeather());
      again.start();
      addTearDown(again.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(again.weather!.temperature, 22.3, reason: 'internet yokken son bilgi');
    });

    test('internet yoksa son bilgi kalır; 6 saatten eskisi gösterilmez', () async {
      clock = DateTime(2026, 10, 19, 10);
      final w = FakeWeather(report: report());
      final c = make(w);
      await c.refreshWeather();
      w.report = null;
      clock = DateTime(2026, 10, 19, 12);
      await c.refreshWeather();
      expect(c.weather, isNotNull);
      clock = DateTime(2026, 10, 19, 16, 1);
      expect(c.weather, isNull);
    });

    test('konum yoksa ya da kapalıysa sorulmaz; konum değişince eski bilgi silinir', () async {
      final w = FakeWeather(report: report());
      final none = make(w, config: createDefaultConfig());
      await none.refreshWeather();
      final off = make(w, config: createDefaultConfig().copyWith(weatherPlace: () => erzin, panoShowWeather: false));
      await off.refreshWeather();
      expect(w.fetches, 0);

      final c = make(w);
      await c.refreshWeather();
      w.report = null;
      await c.setWeatherPlace(const WeatherPlace(name: 'Dörtyol', region: 'Hatay', latitude: 36.84, longitude: 36.23));
      expect(c.weather, isNull);
      expect(c.config.weatherPlace!.name, 'Dörtyol');
    });
  });

  test('sorgu sürerken konum değişirse bitince yeni konum için yeniden sorulur', () async {
    final tmp = Directory.systemTemp.createTempSync('okul_zili_hava2');
    final w = _SlowWeather();
    final c = AppController(
      config: createDefaultConfig().copyWith(weatherPlace: () => erzin),
      repository: ConfigRepository(File('${tmp.path}/config.json')),
      player: SilentPlayer(),
      now: () => DateTime(2026, 10, 19, 10),
      weatherClient: w,
    );
    final first = c.refreshWeather();
    await c.setWeatherPlace(const WeatherPlace(name: 'Dörtyol', region: 'Hatay', latitude: 36.84, longitude: 36.23));
    w.release();
    await first;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(w.asked.map((p) => p.name), ['Erzin', 'Dörtyol']);
    expect(c.weather, isNotNull);
  });

  group('Arayüz', () {
    setUpAll(loadAppFont);
    final now = DateTime(2027, 3, 22, 10, 2);

    testWidgets('pano: hava durumu, günün sözü ve bugünün günleri', (tester) async {
      final w = FakeWeather(report: report(at: now));
      final (c, _) = await pumpOkulZili(
        tester,
        now: now,
        page: AppPage.pano,
        size: const Size(1920, 1080),
        config: createDefaultConfig().copyWith(weatherPlace: () => erzin),
        weatherClient: w,
      );
      await tester.runAsync(() => c.refreshWeather());
      // Pano saniyede bir yenilenir.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('22°'), findsOneWidget);
      expect(find.text('Parçalı bulutlu'), findsOneWidget);
      expect(find.text('GÜNÜN SÖZÜ'), findsOneWidget);
      expect(find.text('Dünya Su Günü'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.runAsync(() => c.setPanoExtras(quote: false, specialDays: false, weather: false));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('GÜNÜN SÖZÜ'), findsNothing);
      expect(find.text('Dünya Su Günü'), findsNothing);
      expect(find.text('22°'), findsNothing);
    });

    testWidgets('Ayarlar: konum aranır ve seçilir', (tester) async {
      final w = FakeWeather(report: report(at: now), places: [erzin]);
      final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.settings, weatherClient: w);
      await tapVisible(tester, find.text('Konum seç…'));
      await tester.enterText(find.widgetWithText(TextField, 'İlçe ya da il'), 'Erzin');
      await tester.tap(find.text('Ara'));
      await tester.pump();
      await tester.pump();
      expect(w.lastQuery, 'Erzin');
      await tester.tap(find.widgetWithText(ListTile, 'Erzin'));
      for (var i = 0; i < 50 && c.config.weatherPlace == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(c.config.weatherPlace!.label, 'Erzin, Hatay');
    });

    testWidgets('Takvim: belirli günler kartı, kapatma ve seçili günde gösterim', (tester) async {
      final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.calendar, size: const Size(1440, 1400));
      expect(find.text('Belirli gün ve haftalar'), findsOneWidget);
      expect(find.text('Dünya Su Günü'), findsWidgets);
      await tester.runAsync(() => c.setSpecialDayEnabled('su-gunu', false));
      await tester.pump();
      expect(c.specialDaysOn(now).map((t) => t.day.id), isNot(contains('su-gunu')));
    });
  });
}

/// İlk isteği bekleten hava durumu kaynağı.
class _SlowWeather implements WeatherClient {
  final asked = <WeatherPlace>[];
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<List<WeatherPlace>> searchPlaces(String query) async => [];

  @override
  Future<WeatherReport> fetch(WeatherPlace place) async {
    asked.add(place);
    if (asked.length == 1) await _gate.future;
    return report(at: DateTime(2026, 10, 19, 10));
  }
}
