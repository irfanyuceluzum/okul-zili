import 'error_log.dart';
import 'notifier.dart';

/// Sorun bildirimini yönlendirir: tepsi ipucu her zaman; pencere gizliyse
/// ayrıca toast ve odak çalmadan pencereyi öne getirme. Bir adım hata verse
/// de diğerleri denenir.
class NoticePresenter {
  NoticePresenter({
    required this.setToolTip,
    required this.isWindowVisible,
    required this.showInactive,
    required this.toast,
    this.toastTimeout = const Duration(seconds: 5),
  });

  final Future<void> Function(String) setToolTip;
  final Future<bool> Function() isWindowVisible;
  final Future<void> Function() showInactive;
  final ToastNotifier toast;

  /// Toast takılırsa en fazla bu kadar beklenir; ardından pencere öne gelir.
  final Duration toastTimeout;

  Future<void> present(String title, String body) async {
    try {
      await setToolTip('Okul Zili — DİKKAT: $title');
    } catch (e, st) {
      ErrorLog.write('bildirim ipucu', e, st);
    }
    var visible = false;
    try {
      visible = await isWindowVisible();
    } catch (e, st) {
      ErrorLog.write('bildirim pencere durumu', e, st);
    }
    if (visible) return;
    try {
      await toast.show(title, body).timeout(toastTimeout);
    } catch (e, st) {
      ErrorLog.write('bildirim toast', e, st);
    }
    try {
      await showInactive();
    } catch (e, st) {
      ErrorLog.write('bildirim pencere', e, st);
    }
  }
}
