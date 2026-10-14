import '../default_config.dart';
import 'bell_event.dart';
import '../../core/date_utils.dart';
import 'calendar.dart';
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
    );
    if (skipped.isNotEmpty) {
      warnings?.add('Okunamayan kayıtlar atlandı: ${skipped.entries.map((e) => '${e.value} ${e.key}').join(', ')}.');
    }
    return config;
  }

  static int? _int(Object? v) => v is num ? v.toInt() : null;

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

  /// Zil için çalınacak sesi bulur: önce zile özel ses, sonra türün sesi,
  /// en son listedeki ilk ses.
  BellSound? soundFor(BellEvent bell) {
    final specific = bell.soundId == null ? null : soundById(bell.soundId!);
    if (specific != null) return specific;
    final byType = soundForType[bell.type];
    return (byType == null ? null : soundById(byType)) ?? sounds.firstOrNull;
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
      };
}
