import '../../core/clock_time.dart';

enum BellType {
  assembly('Toplanma zili'),
  teacher('Öğretmen zili'),
  lessonStart('Giriş zili'),
  lessonEnd('Çıkış zili'),
  dayEnd('Okul çıkış zili'),
  special('Özel etkinlik'),
  manual('Elle çalınan zil'),
  emergency('Acil durum alarmı');

  const BellType(this.label);

  final String label;
}

/// Belirli bir saatte çalacak tek bir zil.
class BellEvent {
  const BellEvent({
    required this.id,
    required this.time,
    required this.type,
    required this.label,
    this.soundId,
    this.loopSeconds,
    this.announcementId,
  });

  /// Gün içinde benzersiz kimlik (ör. "L1-start"). Aynı zilin iki kez
  /// çalmasını engellemek için kullanılır.
  final String id;
  final ClockTime time;
  final BellType type;
  final String label;

  /// Null ise zil türüne atanmış varsayılan ses çalar.
  final String? soundId;

  /// Doluysa ses bu kadar saniye boyunca tekrarlanır (ör. siren); boşsa bir
  /// kez çalar.
  final int? loopSeconds;

  /// Doluysa zil yerine bu sesli anons yapılır (özel etkinlikten).
  final String? announcementId;

  @override
  String toString() => '$time $label';
}
