import '../../data/models/bell_event.dart';

enum BellOutcome {
  played('Çaldı'),
  missed('Kaçırıldı'),
  muted('Susturuldu'),
  failed('Hata');

  const BellOutcome(this.label);

  final String label;
}

class BellLogEntry {
  const BellLogEntry({
    required this.at,
    required this.bell,
    required this.outcome,
    this.key,
    this.detail,
  });

  /// Kaydın oluştuğu an.
  final DateTime at;
  final BellEvent bell;
  final BellOutcome outcome;

  /// Programlı zillerde "gün|zil kimliği" anahtarı; elle çalınanlarda null.
  final String? key;
  final String? detail;

  @override
  String toString() =>
      '$at ${bell.label}: ${outcome.label}${detail == null ? '' : ' ($detail)'}';
}
