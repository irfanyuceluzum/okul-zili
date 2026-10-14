import 'bell_event.dart';
import 'calendar.dart';
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
    this.volumePercent = 100,
    this.lateToleranceSeconds = 60,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        schoolName: json['schoolName'] as String? ?? '',
        templates: (json['templates'] as List)
            .map((e) => ScheduleTemplate.fromJson(e as Map<String, dynamic>))
            .toList(),
        weekPlan: {
          for (final e in (json['weekPlan'] as Map<String, dynamic>).entries)
            int.parse(e.key): e.value as String?,
        },
        sounds: (json['sounds'] as List)
            .map((e) => BellSound.fromJson(e as Map<String, dynamic>))
            .toList(),
        soundForType: {
          for (final e
              in (json['soundForType'] as Map<String, dynamic>).entries)
            BellType.values.byName(e.key): e.value as String,
        },
        holidays: (json['holidays'] as List? ?? const [])
            .map((e) => Holiday.fromJson(e as Map<String, dynamic>))
            .toList(),
        overrides: (json['overrides'] as List? ?? const [])
            .map((e) => DateOverride.fromJson(e as Map<String, dynamic>))
            .toList(),
        specialEvents: (json['specialEvents'] as List? ?? const [])
            .map((e) => SpecialEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        volumePercent: json['volumePercent'] as int? ?? 100,
        lateToleranceSeconds: json['lateToleranceSeconds'] as int? ?? 60,
      );

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

  /// Zil çalarken kullanılacak ses seviyesi (0-100).
  final int volumePercent;

  /// Zil saatinden bu kadar saniye sonrasına kadar gecikmeli çalınabilir;
  /// daha geç kalınırsa (ör. bilgisayar uykudaydı) zil "kaçırıldı" sayılır.
  final int lateToleranceSeconds;

  AppConfig copyWith({
    String? schoolName,
    List<ScheduleTemplate>? templates,
    Map<int, String?>? weekPlan,
    List<BellSound>? sounds,
    Map<BellType, String>? soundForType,
    List<Holiday>? holidays,
    List<DateOverride>? overrides,
    List<SpecialEvent>? specialEvents,
    int? volumePercent,
    int? lateToleranceSeconds,
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
        volumePercent: volumePercent ?? this.volumePercent,
        lateToleranceSeconds: lateToleranceSeconds ?? this.lateToleranceSeconds,
      );

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
        'volumePercent': volumePercent,
        'lateToleranceSeconds': lateToleranceSeconds,
      };
}
