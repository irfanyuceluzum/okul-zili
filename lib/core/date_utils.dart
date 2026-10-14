/// Saat bilgisini atarak yalnızca günü döndürür.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "2026-10-29" biçiminde gün anahtarı (JSON ve kayıtlar için).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String text) => dateOnly(DateTime.parse(text));

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const turkishWeekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

const turkishMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// "14 Ekim 2026 Çarşamba"
String formatTurkishDate(DateTime d) =>
    '${d.day} ${turkishMonths[d.month - 1]} ${d.year} '
    '${turkishWeekdays[d.weekday - 1]}';

/// Süreyi "1:05:09" veya "05:09" biçiminde yazar.
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
