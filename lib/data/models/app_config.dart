import '../default_config.dart';
import 'bell_event.dart';
import '../../core/date_utils.dart';
import 'calendar.dart';
import 'lock_settings.dart';
import '../special_days.dart';
import 'spoken_announcement.dart';
import 'weather_place.dart';
import 'notices.dart';
import 'schedule_template.dart';

class BellSound {
  const BellSound({
    required this.id,
    required this.name,
    required this.path,
    this.isAsset = false,
  });

  factory BellSound.fromJson(Map<String, dynamic> json) => BellSound(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        isAsset: json['isAsset'] as bool? ?? false,
      );

  final String id;
  final String name;

  /// [isAsset] true ise `assets/` altındaki yol, değilse diskteki dosya yolu.
  final String path;
  final bool isAsset;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'isAsset': isAsset,
      };
}

/// Uygulamanın tüm ayarları. Tek bir JSON dosyasında saklanır; böylece
/// yedeklemek veya başka bir okula aktarmak kolaydır.
/// Ana ekrandaki Tören düğmesinden elle çalınan kayıtlar.
enum Ceremony {
  anthem('İstiklal Marşı'),
  remembrance('Saygı duruşu ve İstiklal Marşı');

  const Ceremony(this.label);

  final String label;
}

class AppConfig {
  const AppConfig({
    required this.schoolName,
    required this.templates,
    required this.weekPlan,
    required this.sounds,
    required this.soundForType,
    this.holidays = const [],
    this.overrides = const [],
    this.specialEvents = const [],
    this.announcements = const [],
    this.dutyRoster = const [],
    this.volumePercent = 100,
    this.lateToleranceSeconds = 60,
    this.panoIdleMinutes = 3,
    this.lock,
    this.ceremonySounds = const {},
    this.spokenAnnouncements = const [],
    this.panoShowWeather = true,
    this.panoShowQuote = true,
    this.panoShowSpecialDays = true,
    this.weatherPlace,
    this.disabledSpecialDays = const {},
    this.announcedSpecialDays = const {},
  });

  /// Ayar dosyasını okur. Tek tek okunamayan kayıtlar (bir tatil, bir
  /// etkinlik...) atlanır ve [warnings] listesine yazılır; bir kayıttaki
  /// hata tüm ayarları geçersiz kılmasın. Hiç şablon okunamazsa
  /// [FormatException] fırlatır (yükleyici o zaman yedeğe döner).
  factory AppConfig.fromJson(Map<String, dynamic> json, {List<String>? warnings}) {
    final skipped = <String, int>{};
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) parse, String what) {
      if (raw is! List) return [];
      final out = <T>[];
      for (final e in raw) {
        try {
          out.add(parse(e as Map<String, dynamic>));
        } catch (_) {
          skipped[what] = (skipped[what] ?? 0) + 1;
        }
      }
      return out;
    }

    final templates = list(json['templates'], ScheduleTemplate.fromJson, 'şablon');
    if (templates.isEmpty) throw const FormatException('Ayar dosyasında okunabilir şablon yok');

    final weekPlan = <int, String?>{};
    final rawPlan = json['weekPlan'];
    if (rawPlan is Map) {
      for (final e in rawPlan.entries) {
        final day = int.tryParse('${e.key}');
        if (day != null && day >= 1 && day <= 7 && (e.value == null || e.value is String)) {
          weekPlan[day] = e.value as String?;
        }
      }
    }

    final defaults = createDefaultConfig();
    var sounds = list(json['sounds'], BellSound.fromJson, 'ses');
    if (sounds.isEmpty) sounds = defaults.sounds;

    final soundForType = <BellType, String>{};
    final rawTypes = json['soundForType'];
    if (rawTypes is Map) {
      for (final e in rawTypes.entries) {
        final type = BellType.values.where((t) => t.name == e.key).firstOrNull;
        if (type != null && e.value is String) soundForType[type] = e.value as String;
      }
    }
    for (final e in defaults.soundForType.entries) {
      soundForType.putIfAbsent(e.key, () => e.value);
    }

    LockSettings? lock;
    final rawLock = json['lock'];
    if (rawLock != null) {
      try {
        lock = LockSettings.fromJson(rawLock as Map<String, dynamic>);
      } catch (_) {
        warnings?.add('Kilit ayarı okunamadı.');
      }
    }

    final ceremonySounds = <Ceremony, String>{};
    final rawCeremonies = json['ceremonySounds'];
    if (rawCeremonies is Map) {
      for (final e in rawCeremonies.entries) {
        final kind = Ceremony.values.where((c) => c.name == e.key).firstOrNull;
        if (kind != null && e.value is String && sounds.any((s) => s.id == e.value)) {
          ceremonySounds[kind] = e.value as String;
        }
      }
    }

    final config = AppConfig(
      schoolName: json['schoolName'] is String ? json['schoolName'] as String : '',
      templates: templates,
      weekPlan: weekPlan,
      sounds: sounds,
      soundForType: soundForType,
      holidays: list(json['holidays'], Holiday.fromJson, 'tatil'),
      overrides: list(json['overrides'], DateOverride.fromJson, 'özel gün'),
      specialEvents: list(json['specialEvents'], SpecialEvent.fromJson, 'etkinlik'),
      announcements: list(json['announcements'], Announcement.fromJson, 'duyuru'),
      dutyRoster: list(json['dutyRoster'], DutyEntry.fromJson, 'nöbet'),
      volumePercent: _int(json['volumePercent']) ?? 100,
      lateToleranceSeconds: _int(json['lateToleranceSeconds']) ?? 60,
      panoIdleMinutes: _int(json['panoIdleMinutes']) ?? 3,
      lock: lock,
      ceremonySounds: ceremonySounds,
      spokenAnnouncements: list(json['spokenAnnouncements'], SpokenAnnouncement.fromJson, 'anons'),
      panoShowWeather: json['panoShowWeather'] as bool? ?? true,
      panoShowQuote: json['panoShowQuote'] as bool? ?? true,
      panoShowSpecialDays: json['panoShowSpecialDays'] as bool? ?? true,
      weatherPlace: _weatherPlace(json['weatherPlace'], warnings),
      disabledSpecialDays: {for (final id in (json['disabledSpecialDays'] as List? ?? const [])) if (id is String) id},
      announcedSpecialDays: _announced(json['announcedSpecialDays']),
    );
    if (skipped.isNotEmpty) {
      warnings?.add('Okunamayan kayıtlar atlandı: ${skipped.entries.map((e) => '${e.value} ${e.key}').join(', ')}.');
    }
    return config;
  }

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  static WeatherPlace? _weatherPlace(Object? v, List<String>? warnings) {
    if (v == null) return null;
    try {
      return WeatherPlace.fromJson(v as Map<String, dynamic>);
    } catch (_) {
      warnings?.add('Hava durumu konumu okunamadı.');
      return null;
    }
  }

  static Map<String, DayRange> _announced(Object? v) {
    final out = <String, DayRange>{};
    if (v is! Map) return out;
    for (final e in v.entries) {
      final r = e.value;
      if (e.key is! String || r is! Map) continue;
      final start = DateTime.tryParse('${r['start']}');
      final end = DateTime.tryParse('${r['end']}');
      if (start == null || end == null || end.isBefore(start)) continue;
      out[e.key as String] = DayRange(dateOnly(start), dateOnly(end));
    }
    return out;
  }

  static const schemaVersion = 1;

  final String schoolName;
  final List<ScheduleTemplate> templates;

  /// Haftanın günü (1 = Pazartesi ... 7 = Pazar) → şablon kimliği.
  /// Değer null ya da anahtar yoksa o gün zil çalmaz.
  final Map<int, String?> weekPlan;
  final List<BellSound> sounds;
  final Map<BellType, String> soundForType;
  final List<Holiday> holidays;
  final List<DateOverride> overrides;
  final List<SpecialEvent> specialEvents;

  /// Panoda gösterilen duyurular.
  final List<Announcement> announcements;

  /// Haftalık nöbetçi öğretmen listesi.
  final List<DutyEntry> dutyRoster;

  /// Zil çalarken kullanılacak ses seviyesi (0-100).
  final int volumePercent;

  /// Zil saatinden bu kadar saniye sonrasına kadar gecikmeli çalınabilir;
  /// daha geç kalınırsa (ör. bilgisayar uykudaydı) zil "kaçırıldı" sayılır.
  final int lateToleranceSeconds;

  /// Bilgisayar bu kadar dakika boşta kalınca pano modu açılır; 0 ise kapalı.
  final int panoIdleMinutes;

  /// Ayarlar kilidi; null ise kilit yok. Yalnız parola özetleri tutulur.
  final LockSettings? lock;

  /// Tören → ses kimliği. Ses paketi yüklenince dolar; kayıtlar uygulamayla
  /// gelmez (telif), okul kendisi yükler.
  final Map<Ceremony, String> ceremonySounds;

  /// Sesli anonslar (dosya, mikrofon kaydı ya da yazıdan okuma).
  final List<SpokenAnnouncement> spokenAnnouncements;

  /// Panoda hava durumu, günün sözü ve belirli günler gösterilsin mi.
  final bool panoShowWeather;
  final bool panoShowQuote;
  final bool panoShowSpecialDays;

  /// Hava durumu konumu; seçilmediyse hava durumu gösterilmez.
  final WeatherPlace? weatherPlace;

  /// Kapatılan belirli günlerin kimlikleri.
  final Set<String> disabledSpecialDays;

  /// Tarihi her yıl ilan edilen belirli günler (ör. Mevlid-i Nebî Haftası) için
  /// okulun girdiği tarih aralığı.
  final Map<String, DayRange> announcedSpecialDays;

  AppConfig copyWith({
    String? schoolName,
    List<ScheduleTemplate>? templates,
    Map<int, String?>? weekPlan,
    List<BellSound>? sounds,
    Map<BellType, String>? soundForType,
    List<Holiday>? holidays,
    List<DateOverride>? overrides,
    List<SpecialEvent>? specialEvents,
    List<Announcement>? announcements,
    List<DutyEntry>? dutyRoster,
    int? volumePercent,
    int? lateToleranceSeconds,
    int? panoIdleMinutes,
    LockSettings? Function()? lock,
    Map<Ceremony, String>? ceremonySounds,
    List<SpokenAnnouncement>? spokenAnnouncements,
    bool? panoShowWeather,
    bool? panoShowQuote,
    bool? panoShowSpecialDays,
    WeatherPlace? Function()? weatherPlace,
    Set<String>? disabledSpecialDays,
    Map<String, DayRange>? announcedSpecialDays,
  }) =>
      AppConfig(
        schoolName: schoolName ?? this.schoolName,
        templates: templates ?? this.templates,
        weekPlan: weekPlan ?? this.weekPlan,
        sounds: sounds ?? this.sounds,
        soundForType: soundForType ?? this.soundForType,
        holidays: holidays ?? this.holidays,
        overrides: overrides ?? this.overrides,
        specialEvents: specialEvents ?? this.specialEvents,
        announcements: announcements ?? this.announcements,
        dutyRoster: dutyRoster ?? this.dutyRoster,
        volumePercent: volumePercent ?? this.volumePercent,
        lateToleranceSeconds: lateToleranceSeconds ?? this.lateToleranceSeconds,
        panoIdleMinutes: panoIdleMinutes ?? this.panoIdleMinutes,
        lock: lock != null ? lock() : this.lock,
        ceremonySounds: ceremonySounds ?? this.ceremonySounds,
        spokenAnnouncements: spokenAnnouncements ?? this.spokenAnnouncements,
        panoShowWeather: panoShowWeather ?? this.panoShowWeather,
        panoShowQuote: panoShowQuote ?? this.panoShowQuote,
        panoShowSpecialDays: panoShowSpecialDays ?? this.panoShowSpecialDays,
        weatherPlace: weatherPlace != null ? weatherPlace() : this.weatherPlace,
        disabledSpecialDays: disabledSpecialDays ?? this.disabledSpecialDays,
        announcedSpecialDays: announcedSpecialDays ?? this.announcedSpecialDays,
      );

  /// [now] gününde panoda gösterilecek duyurular: açık, süresi dolmamış, metni dolu.
  List<Announcement> activeAnnouncements(DateTime now) {
    final today = dateOnly(now);
    return announcements
        .where((a) => a.enabled && a.text.trim().isNotEmpty && (a.endDate == null || !a.endDate!.isBefore(today)))
        .toList();
  }

  /// Haftanın [weekday]. günündeki nöbetler (girildiği sırada).
  List<DutyEntry> dutiesOn(int weekday) => dutyRoster.where((d) => d.weekday == weekday).toList();

  ScheduleTemplate? templateById(String id) =>
      templates.where((t) => t.id == id).firstOrNull;

  BellSound? soundById(String id) =>
      sounds.where((s) => s.id == id).firstOrNull;

  SpokenAnnouncement? announcementById(String id) => spokenAnnouncements.where((a) => a.id == id).firstOrNull;

  BellSound? ceremonySound(Ceremony kind) {
    final id = ceremonySounds[kind];
    return id == null ? null : soundById(id);
  }

  /// Zil için çalınacak sesi bulur: önce zile özel ses, sonra türün sesi.
  /// Bulunamazsa null (çağıran yerleşik klasik zili çalar); listedeki ilk ses
  /// alınmaz, yoksa zil yerine ör. İstiklal Marşı çalabilirdi.
  BellSound? soundFor(BellEvent bell) {
    final specific = bell.soundId == null ? null : soundById(bell.soundId!);
    if (specific != null) return specific;
    final byType = soundForType[bell.type];
    return byType == null ? null : soundById(byType);
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'schoolName': schoolName,
        'templates': templates.map((t) => t.toJson()).toList(),
        'weekPlan': {
          for (final e in weekPlan.entries) e.key.toString(): e.value,
        },
        'sounds': sounds.map((s) => s.toJson()).toList(),
        'soundForType': {
          for (final e in soundForType.entries) e.key.name: e.value,
        },
        'holidays': holidays.map((h) => h.toJson()).toList(),
        'overrides': overrides.map((o) => o.toJson()).toList(),
        'specialEvents': specialEvents.map((s) => s.toJson()).toList(),
        'announcements': announcements.map((a) => a.toJson()).toList(),
        'dutyRoster': dutyRoster.map((d) => d.toJson()).toList(),
        'volumePercent': volumePercent,
        'lateToleranceSeconds': lateToleranceSeconds,
        'panoIdleMinutes': panoIdleMinutes,
        if (lock != null) 'lock': lock!.toJson(),
        if (ceremonySounds.isNotEmpty)
          'ceremonySounds': {for (final e in ceremonySounds.entries) e.key.name: e.value},
        if (spokenAnnouncements.isNotEmpty) 'spokenAnnouncements': spokenAnnouncements.map((a) => a.toJson()).toList(),
        'panoShowWeather': panoShowWeather,
        'panoShowQuote': panoShowQuote,
        'panoShowSpecialDays': panoShowSpecialDays,
        if (weatherPlace != null) 'weatherPlace': weatherPlace!.toJson(),
        if (disabledSpecialDays.isNotEmpty) 'disabledSpecialDays': (disabledSpecialDays.toList()..sort()),
        if (announcedSpecialDays.isNotEmpty)
          'announcedSpecialDays': {
            for (final e in announcedSpecialDays.entries)
              e.key: {'start': dateKey(e.value.start), 'end': dateKey(e.value.end)},
          },
      };
}
