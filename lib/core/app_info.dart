/// Uygulama kimliği: Hakkında penceresi ve lisans sayfası kullanır.
///
/// [appVersion] pubspec.yaml'daki sürümle aynı olmalıdır; test/app_info_test.dart
/// ikisinin eşleştiğini denetler.
abstract final class AppInfo {
  static const name = 'Okul Zili';
  static const version = '0.5.0';
  static const developer = 'İrfan Yücel ÜZÜM';
  static const sourceUrl = 'https://github.com/irfanyuceluzum/okul-zili';
  static const releasesUrl = '$sourceUrl/releases';
  static const copyright = 'Copyright © 2026 $developer';
  static const license = 'GNU Genel Kamu Lisansı sürüm 3 (GPL-3.0)';
}
