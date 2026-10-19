/// Panoda gösterilen "günün sözü". Telif sorunu olmayan iki kaynak:
/// Atatürk'ün konuşma ve metinlerinde geçtiği bilinen sözler (yanlış
/// atfedildiği yaygın sözler bilerek alınmadı) ve atasözleri.
library;

import 'special_days.dart';

class Quote {
  const Quote(this.text, this.author);

  final String text;

  /// "Atatürk" ya da "Atasözü".
  final String author;
}

const _a = 'Atatürk';
const _p = 'Atasözü';

const ataturkQuotes = <Quote>[
  // Samsun, öğretmenlere konuşma (22 Eylül 1924).
  Quote('Dünyada her şey için, medeniyet için, hayat için, muvaffakiyet için en hakiki mürşit ilimdir, fendir.', _a),
  // Muallimler Birliği Kongresi (25 Ağustos 1924).
  Quote('Öğretmenler! Cumhuriyet sizden fikri hür, vicdanı hür, irfanı hür nesiller ister.', _a),
  Quote('Öğretmenler! Yeni nesil sizin eseriniz olacaktır.', _a),
  // CHP beyannamesi (20 Nisan 1931).
  Quote('Yurtta sulh, cihanda sulh.', _a),
  // Onuncu Yıl Nutku (29 Ekim 1933).
  Quote('Ne mutlu Türküm diyene!', _a),
  Quote('Türk milletinin karakteri yüksektir; Türk milleti çalışkandır; Türk milleti zekidir.', _a),
  // Gençliğe Hitabe (20 Ekim 1927).
  Quote('Ey Türk gençliği! Birinci vazifen, Türk istiklâlini, Türk Cumhuriyetini, ilelebet muhafaza ve müdafaa etmektir.', _a),
  Quote('Muhtaç olduğun kudret, damarlarındaki asil kanda mevcuttur.', _a),
  // Sakarya Meydan Muharebesi (1921).
  Quote('Hattı müdafaa yoktur, sathı müdafaa vardır. O satıh bütün vatandır.', _a),
  // Büyük Taarruz (1 Eylül 1922).
  Quote('Ordular! İlk hedefiniz Akdeniz\'dir. İleri!', _a),
  Quote('Benim naçiz vücudum elbet bir gün toprak olacaktır, fakat Türkiye Cumhuriyeti ilelebet payidar kalacaktır.', _a),
  Quote('Küçük hanımlar, küçük beyler! Sizler hepiniz geleceğin bir gülü, yıldızı, bir ikbal ışığısınız.', _a),
  Quote('Eğitimdir ki bir milleti ya hür, bağımsız, şanlı, yüksek bir topluluk halinde yaşatır; ya da esaret ve sefalete terk eder.', _a),
  Quote('İlim ve fen nerede ise oradan alacağız ve millet ferdinin kafasına koyacağız.', _a),
  Quote('İstikbal göklerdedir.', _a),
  Quote('Tarih yazmak, tarih yapmak kadar mühimdir.', _a),
];

const proverbs = <Quote>[
  Quote('Damlaya damlaya göl olur.', _p),
  Quote('Ağaç yaşken eğilir.', _p),
  Quote('Birlikten kuvvet doğar.', _p),
  Quote('Bilmemek ayıp değil, sormamak ayıptır.', _p),
  Quote('Bir elin nesi var, iki elin sesi var.', _p),
  Quote('Bugünün işini yarına bırakma.', _p),
  Quote('İşleyen demir ışıldar.', _p),
  Quote('Çalışan demir pas tutmaz.', _p),
  Quote('Dost kara günde belli olur.', _p),
  Quote('Dost acı söyler.', _p),
  Quote('Emek olmadan yemek olmaz.', _p),
  Quote('Erken kalkan yol alır.', _p),
  Quote('Acele işe şeytan karışır.', _p),
  Quote('Ayağını yorganına göre uzat.', _p),
  Quote('Az olsun, öz olsun.', _p),
  Quote('Akıl akıldan üstündür.', _p),
  Quote('Akıl yaşta değil, baştadır.', _p),
  Quote('Tatlı dil yılanı deliğinden çıkarır.', _p),
  Quote('Sabır acıdır, meyvesi tatlıdır.', _p),
  Quote('Sabreden derviş muradına ermiş.', _p),
  Quote('Sakla samanı, gelir zamanı.', _p),
  Quote('Söz gümüşse sükût altındır.', _p),
  Quote('Sütten ağzı yanan yoğurdu üfleyerek yer.', _p),
  Quote('Taşıma su ile değirmen dönmez.', _p),
  Quote('Üzüm üzüme baka baka kararır.', _p),
  Quote('Yalancının mumu yatsıya kadar yanar.', _p),
  Quote('Yuvarlanan taş yosun tutmaz.', _p),
  Quote('Zahmetsiz rahmet olmaz.', _p),
  Quote('Zararın neresinden dönülse kârdır.', _p),
  Quote('Bin işit, bir söyle.', _p),
  Quote('Bir musibet bin nasihatten yeğdir.', _p),
  Quote('Dil kılıçtan keskindir.', _p),
  Quote('Eğri otur, doğru konuş.', _p),
  Quote('Gülü seven dikenine katlanır.', _p),
  Quote('Görünen köy kılavuz istemez.', _p),
  Quote('Hatasız kul olmaz.', _p),
  Quote('Her işte bir hayır vardır.', _p),
  Quote('İnsan yedisinde ne ise yetmişinde de odur.', _p),
  Quote('İyilik eden iyilik bulur.', _p),
  Quote('Kervan yolda düzülür.', _p),
  Quote('Komşu komşunun külüne muhtaçtır.', _p),
  Quote('Laf ile peynir gemisi yürümez.', _p),
  Quote('Nerede birlik, orada dirlik.', _p),
  Quote('Öfkeyle kalkan zararla oturur.', _p),
  Quote('Su testisi su yolunda kırılır.', _p),
  Quote('Tek kanatla kuş uçmaz.', _p),
  Quote('Yedi ölç, bir biç.', _p),
  Quote('Ne ekersen onu biçersin.', _p),
  Quote('Rüzgâr eken fırtına biçer.', _p),
  Quote('Meyve veren ağacı taşlarlar.', _p),
  Quote('Misafir umduğunu değil, bulduğunu yer.', _p),
  Quote('Sona kalan dona kalır.', _p),
  Quote('Taş yerinde ağırdır.', _p),
  Quote('Ummadığın taş baş yarar.', _p),
  Quote('Vakit nakittir.', _p),
  Quote('Yol yürümekle, borç ödemekle tükenir.', _p),
  Quote('Zaman her şeyin ilacıdır.', _p),
  Quote('Ağır kazan geç kaynar.', _p),
  Quote('Az veren candan, çok veren maldan.', _p),
  Quote('Bal tutan parmağını yalar.', _p),
  Quote('Bir fincan kahvenin kırk yıl hatırı vardır.', _p),
  Quote('Bin bilsen de bir bilene danış.', _p),
  Quote('Çivi çiviyi söker.', _p),
  Quote('Davulun sesi uzaktan hoş gelir.', _p),
  Quote('Dost dostun aynasıdır.', _p),
  Quote('Ekmeden biçilmez.', _p),
  Quote('Gülme komşuna, gelir başına.', _p),
  Quote('Her şeyin yenisi, dostun eskisi.', _p),
  Quote('İt ürür, kervan yürür.', _p),
  Quote('Mal canın yongasıdır.', _p),
  Quote('Ne doğrarsan aşına, o gelir kaşığına.', _p),
  Quote('Sel gider, kum kalır.', _p),
  Quote('Tavşan dağa küsmüş, dağın haberi olmamış.', _p),
  Quote('Yağmur yağarken küpleri doldurmalı.', _p),
  Quote('Yiğit düştüğü yerden kalkar.', _p),
  Quote('Bugün bana ise yarın sana.', _p),
  Quote('Fazla mal göz çıkarmaz.', _p),
  Quote('Güneş balçıkla sıvanmaz.', _p),
  Quote('Her inişin bir yokuşu vardır.', _p),
  Quote('İki gönül bir olunca samanlık seyran olur.', _p),
  Quote('Mart kapıdan baktırır, kazma kürek yaktırır.', _p),
  Quote('Tok açın halinden bilmez.', _p),
  Quote('Yerin kulağı vardır.', _p),
  Quote('Zaman sana uymazsa sen zamana uy.', _p),
  Quote('Ateş olmayan yerden duman çıkmaz.', _p),
  Quote('Damdan düşen damdan düşenin halinden anlar.', _p),
  Quote('Sabırla koruk helva olur, dut yaprağı atlas olur.', _p),
  Quote('Su uyur, düşman uyumaz.', _p),
  Quote('Söz uçar, yazı kalır.', _p),
  Quote('Ağlamayan çocuğa meme vermezler.', _p),
  Quote('Ateş düştüğü yeri yakar.', _p),
  Quote('Azıcık aşım, kaygısız başım.', _p),
  Quote('Bal bal demekle ağız tatlanmaz.', _p),
  Quote('Boş çuval dik durmaz.', _p),
  Quote('Çok bilen çok yanılır.', _p),
  Quote('Dağ dağa kavuşmaz, insan insana kavuşur.', _p),
  Quote('Dereyi görmeden paçaları sıvama.', _p),
  Quote('Eski dost düşman olmaz.', _p),
  Quote('El elden üstündür.', _p),
  Quote('Gün doğmadan neler doğar.', _p),
  Quote('Her yiğidin bir yoğurt yiyişi vardır.', _p),
  Quote('İki cambaz bir ipte oynamaz.', _p),
  Quote('Kaz gelecek yerden tavuk esirgenmez.', _p),
  Quote('Keskin sirke küpüne zarar.', _p),
  Quote('Mum dibine ışık vermez.', _p),
  Quote('Yalnız taş duvar olmaz.', _p),
  Quote('Akıllı düşman akılsız dosttan iyidir.', _p),
  Quote('Adam adama lazım olur.', _p),
  Quote('Atın ölümü arpadan olsun.', _p),
  Quote('Kendi düşen ağlamaz.', _p),
  Quote('Komşu hakkı Tanrı hakkı.', _p),
  Quote('Parayı veren düdüğü çalar.', _p),
  Quote('Tilkinin dönüp dolaşıp geleceği yer kürkçü dükkânıdır.', _p),
  Quote('Yolcu yolunda gerek.', _p),
  Quote('Zor oyunu bozar.', _p),
  Quote('Göz görmeyince gönül katlanır.', _p),
  Quote('Vakitsiz öten horozun başını keserler.', _p),
  Quote('Çocuktan al haberi.', _p),
  Quote('Doğru söyleyeni dokuz köyden kovarlar.', _p),
  Quote('Her ağacın meyvesi olmaz.', _p),
  Quote('Denize düşen yılana sarılır.', _p),
  Quote('Alçak yerde tepecik kendini dağ sanır.', _p),
  Quote('Ak akçe kara gün içindir.', _p),
  Quote('Kurt dumanlı havayı sever.', _p),
  Quote('Haydan gelen huya gider.', _p),
  Quote('Hamama giren terler.', _p),
  Quote('Cahile söz anlatmak, deveye hendek atlatmaktan güçtür.', _p),
  Quote('Sağır duymaz, uydurur.', _p),
  Quote('Elin ağzı torba değil ki büzesin.', _p),
  Quote('Ağaca dayanma kurur, insana dayanma ölür.', _p),
  Quote('Emanete hıyanet olmaz.', _p),
];

/// Belirli günlere uygun sözler (o gün bu gösterilir).
const _specialDayQuotes = <String, int>{
  'ataturk-haftasi': 10,
  'cumhuriyet-bayrami': 4,
  'ogretmenler-gunu': 1,
  '23-nisan': 11,
  '19-mayis': 6,
  'zafer-bayrami': 9,
  'ilkogretim-haftasi': 0,
  'bilim-teknoloji': 13,
  'baris': 3,
};

/// [date] gününün sözü. Belirli güne uygun söz varsa o; yoksa her üç günde
/// bir Atatürk'ün sözü, diğer günler atasözü. Aynı gün hep aynı söz çıkar.
Quote quoteForDay(DateTime date, {List<SpecialDayToday> specialDays = const []}) {
  for (final s in specialDays) {
    final i = _specialDayQuotes[s.day.id];
    if (i != null) return ataturkQuotes[i];
  }
  final day = DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(2024)).inDays;
  if (day % 3 == 0) return ataturkQuotes[(day ~/ 3) % ataturkQuotes.length];
  return proverbs[(day - day ~/ 3 - 1) % proverbs.length];
}
