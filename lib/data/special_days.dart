/// Belirli gün ve haftalar: MEB çizelgesi ve farkındalık günleri.
///
/// MEB listesi: Millî Eğitim Bakanlığı Eğitim Kurumları Sosyal Etkinlikler
/// Yönetmeliği EK-8 "Belirli Gün ve Haftalar Çizelgesi" (8/6/2017, RG 30090;
/// EK-8 en son 18/1/2023, RG 32077 ile değiştirildi). "Mahallî kurtuluş
/// günleri" (madde 70) yere göre değiştiği için listede yoktur.
///
/// Hafta kuralları: hafta pazartesi başlar, pazar biter. "Ayın n. haftası",
/// ayın n. pazartesisiyle başlayan haftadır; "son hafta" ayın son
/// pazartesisiyle başlayan haftadır.
library;

enum SpecialDayCategory {
  meb('MEB çizelgesi'),
  awareness('Farkındalık günü');

  const SpecialDayCategory(this.label);

  final String label;
}

/// Bir yıl içindeki gerçekleşme (başlangıç ve bitiş günleri dahil).
class DayRange {
  const DayRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  bool get isSingleDay => start == end;

  /// [day] aralığın kaçıncı günü (1'den başlar).
  int dayIndex(DateTime day) => DateTime(day.year, day.month, day.day).difference(start).inDays + 1;
}

/// Tarih kuralı: verilen yıldaki gerçekleşmeyi döndürür (yoksa null).
sealed class DayRule {
  const DayRule();

  DayRange? inYear(int year);

  /// Listede tarihin yanında gösterilen açıklama (ör. "Eylül'ün 3. haftası").
  String get description;
}

const _months = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const _weekdays = ['pazartesi', 'salı', 'çarşamba', 'perşembe', 'cuma', 'cumartesi', 'pazar'];

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// Ayın [n]. pazartesisi; n = -1 ise son pazartesi.
DateTime _nthMonday(int year, int month, int n) {
  if (n > 0) {
    final first = _d(year, month, 1);
    final offset = (DateTime.monday - first.weekday + 7) % 7;
    return _d(year, month, 1 + offset + 7 * (n - 1));
  }
  final last = _d(year, month + 1, 0);
  final back = (last.weekday - DateTime.monday + 7) % 7;
  return _d(year, month, last.day - back);
}

DateTime _mondayOf(DateTime d) => _d(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// Sabit gün: 12 Mart gibi.
class FixedDay extends DayRule {
  const FixedDay(this.month, this.day);

  final int month;
  final int day;

  @override
  DayRange inYear(int year) => DayRange(_d(year, month, day), _d(year, month, day));

  @override
  String get description => '$day ${_months[month - 1]}';
}

/// Sabit aralık: 29 Ekim – 4 Kasım gibi (aynı yıl içinde).
class FixedRange extends DayRule {
  const FixedRange(this.month, this.day, this.endMonth, this.endDay);

  final int month;
  final int day;
  final int endMonth;
  final int endDay;

  @override
  DayRange inYear(int year) => DayRange(_d(year, month, day), _d(year, endMonth, endDay));

  @override
  String get description => month == endMonth
      ? '$day–$endDay ${_months[month - 1]}'
      : '$day ${_months[month - 1]} – $endDay ${_months[endMonth - 1]}';
}

/// Ayın [n]. haftası (n = -1 son hafta): pazartesiden pazara.
class NthWeek extends DayRule {
  const NthWeek(this.month, this.n);

  final int month;
  final int n;

  @override
  DayRange inYear(int year) {
    final start = _nthMonday(year, month, n);
    return DayRange(start, _d(start.year, start.month, start.day + 6));
  }

  @override
  String get description => '${_months[month - 1]} ayının ${n == -1 ? 'son' : n == 1 ? 'ilk' : '$n.'} haftası';
}

/// Ayın [n]. haftasının belirli günü (ör. Ekim'in ilk haftasının perşembesi).
class WeekdayOfNthWeek extends DayRule {
  const WeekdayOfNthWeek(this.month, this.n, this.weekday, {this.label});

  final int month;
  final int n;
  final int weekday;

  /// Açıklama özelse (ör. "İlköğretim Haftası'nın son günü").
  final String? label;

  @override
  DayRange inYear(int year) {
    final monday = _nthMonday(year, month, n);
    final day = _d(monday.year, monday.month, monday.day + weekday - DateTime.monday);
    return DayRange(day, day);
  }

  @override
  String get description =>
      label ?? '${_months[month - 1]} ayının ${n == 1 ? 'ilk' : '$n.'} haftasının ${_weekdays[weekday - 1]} günü';
}

/// Ayın [n]. [weekday] günü (ör. Mayıs'ın 2. pazarı).
class NthWeekday extends DayRule {
  const NthWeekday(this.month, this.n, this.weekday);

  final int month;
  final int n;
  final int weekday;

  @override
  DayRange inYear(int year) {
    final first = _d(year, month, 1);
    final offset = (weekday - first.weekday + 7) % 7;
    final day = _d(year, month, 1 + offset + 7 * (n - 1));
    return DayRange(day, day);
  }

  @override
  String get description => '${_months[month - 1]} ayının $n. ${_weekdays[weekday - 1]}';
}

/// [month]/[day] gününü içine alan hafta.
class WeekContaining extends DayRule {
  const WeekContaining(this.month, this.day);

  final int month;
  final int day;

  @override
  DayRange inYear(int year) {
    final start = _mondayOf(_d(year, month, day));
    return DayRange(start, _d(start.year, start.month, start.day + 6));
  }

  @override
  String get description => '$day ${_months[month - 1]} gününü içine alan hafta';
}

/// Tarihi her yıl ilan edilen (ör. Mevlid-i Nebi Haftası); okul girer.
class AnnouncedEachYear extends DayRule {
  const AnnouncedEachYear(this.note);

  final String note;

  @override
  DayRange? inYear(int year) => null;

  @override
  String get description => note;
}

class SpecialDay {
  const SpecialDay(this.id, this.name, this.rule, this.category);

  final String id;
  final String name;
  final DayRule rule;
  final SpecialDayCategory category;

  bool get needsDate => rule is AnnouncedEachYear;
}

const _meb = SpecialDayCategory.meb;
const _aw = SpecialDayCategory.awareness;

/// MEB EK-8 sırasıyla (madde 70 hariç) ve ardından farkındalık günleri.
const builtInSpecialDays = <SpecialDay>[
  SpecialDay('temiz-hava', 'Uluslararası Temiz Hava Günü', FixedDay(9, 7), _meb),
  SpecialDay('ilk-yardim-gunu', 'Dünya İlk Yardım Günü', NthWeekday(9, 2, DateTime.saturday), _meb),
  SpecialDay('ilkogretim-haftasi', 'İlköğretim Haftası', NthWeek(9, 3), _meb),
  SpecialDay('ogrenciler-gunu', 'Öğrenciler Günü',
      WeekdayOfNthWeek(9, 3, DateTime.friday, label: 'İlköğretim Haftası\'nın son günü'), _meb),
  SpecialDay('gaziler-gunu', 'Gaziler Günü', FixedDay(9, 19), _meb),
  // EK-8: "Ders yılının başladığı ikinci hafta içerisinde anma programları
  // uygulanır." Ders yılı eylülün 2. pazartesisi başladığından 3. hafta.
  SpecialDay('15-temmuz', '15 Temmuz Demokrasi ve Millî Birlik Günü', NthWeek(9, 3), _meb),
  SpecialDay('okul-sutu', 'Dünya Okul Sütü Günü', FixedDay(9, 28), _meb),
  SpecialDay('disleksi-haftasi', 'Disleksi Haftası', NthWeek(10, 1), _meb),
  SpecialDay('disleksi-gunu', 'Dünya Disleksi Günü', WeekdayOfNthWeek(10, 1, DateTime.thursday), _meb),
  SpecialDay('mevlid-i-nebi', 'Mevlid-i Nebî Haftası',
      AnnouncedEachYear('Diyanet İşleri Başkanlığınca belirlenen hafta'), _meb),
  SpecialDay('hayvanlari-koruma', 'Hayvanları Koruma Günü', FixedDay(10, 4), _meb),
  SpecialDay('ahilik', 'Ahilik Kültürü Haftası', FixedRange(10, 8, 10, 12), _meb),
  SpecialDay('afet-azaltma', 'Dünya Afet Azaltma Günü', FixedDay(10, 13), _meb),
  SpecialDay('bm-gunu', 'Birleşmiş Milletler Günü', FixedDay(10, 24), _meb),
  SpecialDay('cumhuriyet-bayrami', 'Cumhuriyet Bayramı', FixedDay(10, 29), _meb),
  SpecialDay('kizilay', 'Kızılay Haftası', FixedRange(10, 29, 11, 4), _meb),
  SpecialDay('organ-bagisi', 'Organ Bağışı ve Nakli Haftası', FixedRange(11, 3, 11, 9), _meb),
  SpecialDay('losemili-cocuklar', 'Lösemili Çocuklar Haftası', FixedRange(11, 2, 11, 8), _meb),
  SpecialDay('ataturk-haftasi', 'Atatürk Haftası', FixedRange(11, 10, 11, 16), _meb),
  SpecialDay('diyabet', 'Dünya Diyabet Günü', FixedDay(11, 14), _meb),
  SpecialDay('afet-egitimi', 'Afet Eğitimi Hazırlık Günü', FixedDay(11, 12), _meb),
  SpecialDay('felsefe', 'Dünya Felsefe Günü', FixedDay(11, 20), _meb),
  SpecialDay('cocuk-haklari', 'Dünya Çocuk Hakları Günü', FixedDay(11, 20), _meb),
  SpecialDay('agiz-dis', 'Ağız ve Diş Sağlığı Haftası', FixedRange(11, 21, 11, 27), _meb),
  SpecialDay('ogretmenler-gunu', 'Öğretmenler Günü', FixedDay(11, 24), _meb),
  SpecialDay('engelliler-gunu', 'Dünya Engelliler Günü', FixedDay(12, 3), _meb),
  SpecialDay('madenciler', 'Dünya Madenciler Günü', FixedDay(12, 4), _meb),
  SpecialDay('kadin-secme', 'Türk Kadınına Seçme ve Seçilme Hakkının Verilişi', FixedDay(12, 5), _meb),
  SpecialDay('mevlana', 'Mevlana Haftası', FixedRange(12, 7, 12, 17), _meb),
  SpecialDay('insan-haklari', 'İnsan Hakları ve Demokrasi Haftası', WeekContaining(12, 10), _meb),
  SpecialDay('tutum', 'Tutum, Yatırım ve Türk Malları Haftası', FixedRange(12, 12, 12, 18), _meb),
  SpecialDay('akif-haftasi', 'Mehmet Akif Ersoy\'u Anma Haftası', FixedRange(12, 20, 12, 27), _meb),
  SpecialDay('enerji', 'Enerji Tasarrufu Haftası', NthWeek(1, 2), _meb),
  SpecialDay('vergi', 'Vergi Haftası', NthWeek(2, -1), _meb),
  SpecialDay('yesilay', 'Yeşilay Haftası', WeekContaining(3, 1), _meb),
  SpecialDay('girisimcilik', 'Girişimcilik Haftası', NthWeek(3, 1), _meb),
  SpecialDay('kadinlar-gunu', 'Dünya Kadınlar Günü', FixedDay(3, 8), _meb),
  SpecialDay('bilim-teknoloji', 'Bilim ve Teknoloji Haftası', FixedRange(3, 8, 3, 14), _meb),
  SpecialDay('istiklal-marsi', 'İstiklâl Marşı\'nın Kabulü ve Mehmet Akif Ersoy\'u Anma Günü', FixedDay(3, 12), _meb),
  SpecialDay('tuketici', 'Tüketiciyi Koruma Haftası', FixedRange(3, 15, 3, 21), _meb),
  SpecialDay('sehitler-gunu', 'Şehitler Günü', FixedDay(3, 18), _meb),
  SpecialDay('yaslilar', 'Yaşlılar Haftası', FixedRange(3, 18, 3, 24), _meb),
  SpecialDay('turk-dunyasi', 'Türk Dünyası ve Toplulukları Haftası', WeekContaining(3, 21), _meb),
  SpecialDay('orman', 'Orman Haftası', FixedRange(3, 21, 3, 26), _meb),
  SpecialDay('su-gunu', 'Dünya Su Günü', FixedDay(3, 22), _meb),
  SpecialDay('tiyatrolar', 'Dünya Tiyatrolar Günü', FixedDay(3, 27), _meb),
  SpecialDay('kutuphaneler', 'Kütüphaneler Haftası', NthWeek(3, -1), _meb),
  SpecialDay('kanser', 'Kanser Haftası', FixedRange(4, 1, 4, 7), _meb),
  SpecialDay('otizm', 'Dünya Otizm Farkındalık Günü', FixedDay(4, 2), _meb),
  SpecialDay('kisisel-veriler', 'Kişisel Verileri Koruma Günü', FixedDay(4, 7), _meb),
  SpecialDay('saglik', 'Dünya Sağlık Günü / Dünya Sağlık Haftası', FixedRange(4, 7, 4, 13), _meb),
  SpecialDay('turizm', 'Turizm Haftası', FixedRange(4, 15, 4, 22), _meb),
  SpecialDay('23-nisan', 'Ulusal Egemenlik ve Çocuk Bayramı', FixedDay(4, 23), _meb),
  SpecialDay('fikri-mulkiyet', 'Dünya Fikrî Mülkiyet Günü', FixedDay(4, 26), _meb),
  SpecialDay('kutul-amare', 'Kût\'ül Amâre Zaferi', FixedDay(4, 29), _meb),
  SpecialDay('bilisim', 'Bilişim Haftası', NthWeek(5, 1), _meb),
  SpecialDay('trafik', 'Trafik ve İlkyardım Haftası', NthWeek(5, 1), _meb),
  SpecialDay('is-sagligi', 'İş Sağlığı ve Güvenliği Haftası', FixedRange(5, 4, 5, 10), _meb),
  SpecialDay('vakiflar', 'Vakıflar Haftası', NthWeek(5, 2), _meb),
  SpecialDay('anneler-gunu', 'Anneler Günü', NthWeekday(5, 2, DateTime.sunday), _meb),
  SpecialDay('engelliler-haftasi', 'Engelliler Haftası', FixedRange(5, 10, 5, 16), _meb),
  SpecialDay('muzeler', 'Müzeler Haftası', FixedRange(5, 18, 5, 24), _meb),
  SpecialDay('19-mayis', 'Atatürk\'ü Anma ve Gençlik ve Spor Bayramı', FixedDay(5, 19), _meb),
  SpecialDay('etik', 'Etik Günü', FixedDay(5, 25), _meb),
  SpecialDay('istanbul-fethi', 'İstanbul\'un Fethi', FixedDay(5, 29), _meb),
  SpecialDay('hayat-boyu', 'Hayat Boyu Öğrenme Haftası', NthWeek(6, 1), _meb),
  SpecialDay('cevre-iklim', 'Çevre ve İklim Değişikliği Haftası', NthWeek(6, 2), _meb),
  SpecialDay('babalar-gunu', 'Babalar Günü', NthWeekday(6, 3, DateTime.sunday), _meb),
  SpecialDay('zafer-bayrami', 'Zafer Bayramı', FixedDay(8, 30), _meb),

  // Farkındalık günleri (Birleşmiş Milletler ve kuruluşları).
  SpecialDay('okuma-yazma', 'Uluslararası Okuma Yazma Günü', FixedDay(9, 8), _aw),
  SpecialDay('baris', 'Uluslararası Barış Günü', FixedDay(9, 21), _aw),
  SpecialDay('ruh-sagligi', 'Dünya Ruh Sağlığı Günü', FixedDay(10, 10), _aw),
  SpecialDay('kiz-cocuklari', 'Dünya Kız Çocukları Günü', FixedDay(10, 11), _aw),
  SpecialDay('gida', 'Dünya Gıda Günü', FixedDay(10, 16), _aw),
  SpecialDay('hosgoru', 'Uluslararası Hoşgörü Günü', FixedDay(11, 16), _aw),
  SpecialDay('anadil', 'Uluslararası Anadil Günü', FixedDay(2, 21), _aw),
  SpecialDay('yaban-hayati', 'Dünya Yaban Hayatı Günü', FixedDay(3, 3), _aw),
  SpecialDay('mutluluk', 'Uluslararası Mutluluk Günü', FixedDay(3, 20), _aw),
  SpecialDay('down-sendromu', 'Dünya Down Sendromu Günü', FixedDay(3, 21), _aw),
  SpecialDay('ari', 'Dünya Arı Günü', FixedDay(5, 20), _aw),
  SpecialDay('sigarasiz', 'Dünya Sigarasız Günü', FixedDay(5, 31), _aw),
  SpecialDay('bisiklet', 'Dünya Bisiklet Günü', FixedDay(6, 3), _aw),
  SpecialDay('cevre-gunu', 'Dünya Çevre Günü', FixedDay(6, 5), _aw),
  SpecialDay('okyanus', 'Dünya Okyanus Günü', FixedDay(6, 8), _aw),
  SpecialDay('cocuk-isciligi', 'Dünya Çocuk İşçiliğiyle Mücadele Günü', FixedDay(6, 12), _aw),
];

/// Bugün süren bir belirli gün/hafta ve kaçıncı günü olduğu.
class SpecialDayToday {
  const SpecialDayToday(this.day, this.range, this.dayIndex);

  final SpecialDay day;
  final DayRange range;
  final int dayIndex;

  /// "Bilim ve Teknoloji Haftası · 3. gün" gibi.
  String get label => range.isSingleDay ? day.name : '${day.name} · $dayIndex. gün';
}

/// [date] gününde süren belirli günler: önce tek günlük olanlar (MEB önce),
/// sonra haftalar. [disabled] kapatılanlar; [announced] her yıl ilan edilen
/// günlerin girilen tarihleri (yıla göre).
List<SpecialDayToday> specialDaysOn(
  DateTime date, {
  Set<String> disabled = const {},
  Map<String, DayRange> announced = const {},
  List<SpecialDay> days = builtInSpecialDays,
}) {
  final out = <SpecialDayToday>[];
  for (final d in days) {
    if (disabled.contains(d.id)) continue;
    final range = d.needsDate ? announced[d.id] : d.rule.inYear(date.year);
    if (range == null || !range.contains(date)) continue;
    out.add(SpecialDayToday(d, range, range.dayIndex(date)));
  }
  int rank(SpecialDayToday t) => (t.range.isSingleDay ? 0 : 2) + (t.day.category == SpecialDayCategory.meb ? 0 : 1);
  // Eşit sıradakiler listedeki (çizelgedeki) sırayı korusun.
  final order = {for (var i = 0; i < out.length; i++) out[i]: i};
  out.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : order[a]!.compareTo(order[b]!);
  });
  return out;
}
