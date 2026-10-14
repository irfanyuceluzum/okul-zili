/// Günün bir saatini dakika hassasiyetinde tutar (ör. 08:40).
///
/// Flutter'ın `TimeOfDay` sınıfı yerine bu kullanılır; böylece zamanlayıcı
/// motoru saf Dart olarak kalır ve arayüzden bağımsız test edilebilir.
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  /// "08:40" veya "08.40" biçimindeki metni çözümler.
  factory ClockTime.parse(String text) {
    final parts = text.trim().split(RegExp('[:.]'));
    if (parts.length != 2) {
      throw FormatException('Geçersiz saat: $text');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw FormatException('Geçersiz saat: $text');
    }
    return ClockTime(hour, minute);
  }

  factory ClockTime.fromMinutes(int totalMinutes) {
    if (totalMinutes < 0 || totalMinutes >= 24 * 60) {
      throw RangeError.range(totalMinutes, 0, 24 * 60 - 1, 'totalMinutes');
    }
    return ClockTime(totalMinutes ~/ 60, totalMinutes % 60);
  }

  final int hour;
  final int minute;

  int get inMinutes => hour * 60 + minute;

  /// Verilen dakika kadar kaydırılmış saati döndürür; gün dışına taşarsa null.
  ClockTime? tryAddMinutes(int minutes) {
    final total = inMinutes + minutes;
    if (total < 0 || total >= 24 * 60) return null;
    return ClockTime.fromMinutes(total);
  }

  /// Bu saatin verilen gündeki karşılığı.
  DateTime on(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  bool operator <(ClockTime other) => inMinutes < other.inMinutes;
  bool operator >(ClockTime other) => inMinutes > other.inMinutes;
  bool operator <=(ClockTime other) => inMinutes <= other.inMinutes;
  bool operator >=(ClockTime other) => inMinutes >= other.inMinutes;

  @override
  int compareTo(ClockTime other) => inMinutes.compareTo(other.inMinutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
