# Proje profili — Okul Zili

Windows'ta tek okul bilgisayarında 7/24 çalışan okul zili uygulaması
(Flutter, masaüstü). Geliştirme Mac'te (macOS hedefi); Windows derlemesi
yalnız GitHub Actions'ta. En kötü sonuç: zilin çalmaması ya da okulun
programının (ayarların) kaybolması.

## Harita
- `lib/core/` — saat yardımcıları ve zamanlayıcı motoru (`scheduler/`), saf Dart
- `lib/data/` — ayar modeli (`models/`), `config_repository.dart` (kayıt, yedek), `schedule_draft.dart`
- `lib/app_controller.dart` — ayar, zamanlayıcı, ses, sistem servislerini birleştiren denetleyici
- `lib/platform/` — ses çalar, Windows FFI (`windows/`), tepsi/pencere (`desktop_shell.dart`), hata kaydı
- `lib/features/` — ekranlar (dashboard, pano, schedule, calendar, events, sounds, logs, settings)
- `lib/ui/` — tema, ortak bileşenler, kenar menüsü, saat alanı
- `test/` — birim + arayüz testleri; ortak kurulum `test/support/app_harness.dart`
- `installer/okul_zili.iss` — Inno Setup kurulum betiği
- `.github/workflows/windows.yml` — Windows test + derleme + kurulum dosyası
- `tools/baglanti_testi.ps1` — Android kumanda için ağ testi (Windows)

## Büyük dosyalar (baştan okunmaz; Grep + offset/limit)
- `lib/features/schedule/schedule_page.dart`, `lib/features/calendar/calendar_page.dart`,
  `lib/features/dashboard/dashboard_page.dart`, `lib/app_controller.dart` (her biri 15–35 KB)

## Bakılmayacak dizinler
- `build/`, `.dart_tool/`, `macos/Flutter/ephemeral/`, `windows/flutter/ephemeral/`, `assets/fonts/`, `assets/sounds/`

## Yazma yasakları (implementer hiçbir durumda yazmaz)
- `build/`, `.dart_tool/` — derleme çıktısı
- `pubspec.lock` — yalnız `flutter pub` komutlarıyla değişir
- `assets/fonts/`, `assets/sounds/`, `assets/tray/`, `windows/runner/resources/` — ikili dosyalar
- `LICENSE` — GPL-3.0 metni
- `.github/workflows/` — CI; ana oturum onayıyla değişir
- `.claude/` — orkestra profili

## Canlı sisteme giden komutlar (hiçbir ajan çalıştırmaz)
- `git commit`, `git push` — ana oturum kullanıcı onayıyla yapar
- `gh run ...`, `gh repo edit ...`, `gh release ...` — GitHub'da işlem

## Biçimlendirme (yalnız yeni dosyalarda)
- Depoda `dart format` zorunlu değil; çevredeki biçime uy (satırlar ~120 karaktere kadar).

## Kod kuralları (implementer)
- Arayüz metinleri ve kod yorumları Türkçe; kullanıcı teknik değil, metinler sade.
- Windows'a özgü kod `lib/platform/` altında ve `SystemServices` arayüzü arkasında; Mac'te no-op.
- Saat girdisi için `ClockTime.tryCreate`/`ClockTime.parse` kullan (kurucudaki assert yayında çalışmaz).
- Ayar değişikliği yalnız `AppController.updateConfig` üzerinden; yeni ayar alanı `AppConfig` toJson/fromJson/copyWith'e eklenir, fromJson eksik alanda varsayılan verir.
- Yeni arayüz testleri `test/support/app_harness.dart` (`pumpOkulZili`, `loadAppFont`, `tapVisible`) kullanır.
- testWidgets içinde gerçek dosya G/Ç'si tamamlanmayabilir; dosya işlemi gereken mantığı düz `test` ile sına.
- dispose sırasında `notifyListeners`/`setState` tetikleyen işi `Future.microtask` ile ertele.

## Korunacak davranışlar
- Saati geçen zil tolerans dışında çalınmaz, "kaçırıldı" yazılır; uygulama açılmadan önceki ziller sessiz atlanır.
- Susturma her zaman süreli; acil durum düğmesi 2 sn basılı tutmayla çalışır.
- Ders programı taslağı: Kaydet'e kadar ziller eski programla çalar; hatalı program kaydedilmez.
- Yüklenen ses çalınamazsa yerleşik zil çalar; zil sessiz kalmaz.
- Açılış hiçbir hatada görünmez/zilsiz kalmaz; ayar okunamazsa son sağlam yedek yüklenir.
- Kayıtlar sıralı yapılır; ayar dosyası her kayıttan önce yedeklenir.
- Boşta kalınca pano: yazı alanında imleç ya da açık diyalog varken açılmaz.

## Risk listesi (danisman)
- Zilin çalmaması: zamanlayıcı anahtarları, susturma/bekletme, ses çalar sırası.
- Ayar kaybı: config şeması geriye uyumlu mu, geri yükleme/içe aktarma mevcut ayarı ezmeden önce yedek alıyor mu.
- Yetki: şifre kilidi varsa atlatılabiliyor mu, şifre düz metin saklanıyor mu.
- Windows FFI ve kurulum betiği yalnız CI'da derleniyor; gerçek cihazda denenmedi.

## Ortam kısıtları
- Mac'te Windows derlenemez/çalıştırılamaz; PowerShell ve Inno Setup yok.
- Flutter 3.47.7 (CI'da sabit). Testler `flutter test` (~10 sn).
