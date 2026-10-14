import '../core/date_utils.dart';
import 'models/app_config.dart';
import 'models/calendar.dart';
import 'models/schedule_template.dart';

/// Ders programı ekranında kaydedilmemiş değişiklikler. "Kaydet"e basılana
/// kadar ziller eski programla çalmaya devam eder.
class ScheduleDraft {
  ScheduleDraft({
    required List<ScheduleTemplate> templates,
    required Map<int, String?> weekPlan,
    required this.selectedId,
  })  : templates = [...templates],
        weekPlan = {...weekPlan};

  factory ScheduleDraft.fromConfig(AppConfig config) {
    final firstUsed = [for (var d = 1; d <= 7; d++) config.weekPlan[d]].nonNulls.firstOrNull;
    return ScheduleDraft(
      templates: config.templates,
      weekPlan: config.weekPlan,
      selectedId: firstUsed ?? config.templates.firstOrNull?.id ?? '',
    );
  }

  List<ScheduleTemplate> templates;
  final Map<int, String?> weekPlan;
  String selectedId;
  bool dirty = false;

  ScheduleTemplate? get selected => byId(selectedId);

  ScheduleTemplate? byId(String id) => templates.where((t) => t.id == id).firstOrNull;

  /// Şablonun kullanıldığı günler (1 = Pazartesi).
  List<int> daysUsing(String id) => [for (var d = 1; d <= 7; d++) if (weekPlan[d] == id) d];

  void replace(ScheduleTemplate template) {
    templates = [for (final t in templates) t.id == template.id ? template : t];
    dirty = true;
  }

  void add(ScheduleTemplate template) {
    templates = [...templates, template];
    selectedId = template.id;
    dirty = true;
  }

  void remove(String id) {
    templates = templates.where((t) => t.id != id).toList();
    for (var d = 1; d <= 7; d++) {
      if (weekPlan[d] == id) weekPlan[d] = null;
    }
    if (selectedId == id) selectedId = templates.firstOrNull?.id ?? '';
    dirty = true;
  }

  void setDay(int weekday, String? templateId) {
    weekPlan[weekday] = templateId;
    dirty = true;
  }

  /// Kaydetmeyi engelleyen sorunlar; boşsa kaydedilebilir.
  List<String> validate(List<DateOverride> overrides) {
    final errors = <String>[];
    if (templates.isEmpty) errors.add('En az bir şablon olmalı.');
    final names = <String>{};
    for (final t in templates) {
      final label = t.name.trim().isEmpty ? 'Adsız şablon' : t.name.trim();
      for (final e in t.validate()) {
        errors.add('$label: $e');
      }
      if (!names.add(label.toLowerCase())) errors.add('"$label" adında birden fazla şablon var.');
    }
    for (final o in overrides) {
      if (o.templateId != null && byId(o.templateId!) == null) {
        errors.add('${o.date.day} ${turkishMonths[o.date.month - 1]} özel günü silinen bir şablonu kullanıyor.');
      }
    }
    return errors;
  }

  static String newId() => 't${DateTime.now().microsecondsSinceEpoch}';
}
