# Okul Zili

Windows'ta çalışan okul zili uygulaması (Flutter). Ders saatlerinden zilleri
kendisi üretir, bilgisayar açılınca sistem tepsisinde başlar, zil çalmadan önce
bilgisayarın sesini açar.

## Kurulum dosyası

`main` dalına her gönderimde GitHub Actions testleri çalıştırır, Windows
derlemesini yapar ve `OkulZili-Kurulum-<sürüm>.exe` dosyasını üretir:
**Actions → son çalışma → Artifacts → OkulZili-Kurulum**.

Kurulum yönetici izni istemez; "Bilgisayar açılınca otomatik başlat" seçeneği
varsayılan olarak işaretlidir.

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
