/// Sistem bildirimi (toast) arayüzü. Windows dışında hiçbir şey yapmaz.
abstract interface class ToastNotifier {
  Future<void> init();
  Future<void> show(String title, String body);
}

/// Bildirim desteği olmayan platformlar ve testler için boş uygulama.
class NoopToastNotifier implements ToastNotifier {
  const NoopToastNotifier();

  @override
  Future<void> init() async {}

  @override
  Future<void> show(String title, String body) async {}
}
