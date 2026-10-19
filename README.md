# Okul Zili

Windows'ta çalışan okul zili uygulaması (Flutter). Ders saatlerinden zilleri
kendisi üretir, bilgisayar açılınca sistem tepsisinde başlar, zil çalmadan önce
bilgisayarın sesini açar.

## Kurulum dosyası

Son sürümü **[Releases](https://github.com/irfanyuceluzum/okul-zili/releases)**
sayfasından indirin (`OkulZili-Kurulum-<sürüm>.exe`).

`main` dalına her gönderimde GitHub Actions testleri çalıştırır, Windows
derlemesini yapar ve aynı dosyayı üretir:
**Actions → son çalışma → Artifacts → OkulZili-Kurulum**.

Kurulum yönetici izni istemez; "Bilgisayar açılınca otomatik başlat" seçeneği
varsayılan olarak işaretlidir.

## Zil sesleri ve törenler

Uygulama yalnız kendi yerleşik seslerini (klasik zil, ding-dong, siren) içerir.
İstiklal Marşı, saygı duruşu ve diğer zil sesi kayıtları telif nedeniyle depoda
**yoktur**; okul kendi kayıtlarını yükler:

1. Ses dosyalarını (mp3, wav, m4a, aac, wma) tek bir klasöre koyun.
2. **Zil sesleri → Ses paketi yükle…** ile klasörü seçin.
3. Adında "istiklal" geçen dosya *İstiklal Marşı*, "saygı" geçen dosya
   *Saygı duruşu ve İstiklal Marşı* olarak tanınır ve ana ekrandaki **Tören**
   düğmesine atanır; saygı duruşu kaydı 10 Kasım etkinliğine de atanır.
   "zilsesi3" gibi adlar *Zil sesi 3* olur; hangi zilde hangisinin çalacağını
   aynı sayfadan seçin.

Tören kaydı çalarken saati gelen zil marşı kesmez; kayıt bitince (gecikme
toleransı içindeyse) çalar.

## Geliştirme

Geliştirme Mac'te macOS hedefiyle yapılır. Windows'a özgü kısımlar
(`lib/platform/`) Mac'te hiçbir şey yapmaz.

```bash
flutter test
flutter run -d macos
```

- `lib/core/scheduler/` — zamanlayıcı motoru (saf Dart, testli)
- `lib/data/` — ayar modeli ve `config.json` depolama
- `lib/platform/` — Windows ses denetimi, otomatik başlatma, sistem tepsisi
- `lib/features/` — ekranlar
- `tools/baglanti_testi.ps1` — telefonun zil bilgisayarına okul ağında
  ulaşıp ulaşamadığını dener (Android kumanda için)

## Geliştirici

İrfan Yücel ÜZÜM — uygulamada **Hakkında** (kenar menüsünün altı ya da
Ayarlar) penceresinde sürüm, geliştirici ve lisans bilgisi bulunur.

## Lisans

[GNU GPL v3](LICENSE). Copyright © 2026 İrfan Yücel ÜZÜM.
Uygulama ücretsizdir; değiştirip dağıtan herkes kaynak kodunu da aynı
lisansla paylaşmak zorundadır. IBM Plex Sans yazı tipi
[SIL Open Font License](assets/fonts/OFL.txt) ile dağıtılır.
