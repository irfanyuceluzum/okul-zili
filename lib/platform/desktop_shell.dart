import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app_controller.dart';
import '../ui/lock_dialog.dart';
import '../ui/navigation.dart';
import 'error_log.dart';
import 'notice_presenter.dart';
import 'notifier.dart';
import 'windows/windows_notifier.dart';

/// Pencere ve sistem tepsisi. Pencerenin çarpısı uygulamayı kapatmaz,
/// yalnızca gizler; ziller tepside çalışmaya devam eder. Tamamen kapatmak
/// için tepsi menüsündeki "Çıkış" onay ister.
class DesktopShell with TrayListener, WindowListener implements WindowControls {
  DesktopShell({
    required this.controller,
    required this.navigation,
    required this.navigatorKey,
  });

  static bool get isSupported => Platform.isWindows || Platform.isMacOS;

  final AppController controller;
  final ValueNotifier<AppPage> navigation;
  final GlobalKey<NavigatorState> navigatorKey;

  bool _quitting = false;
  bool? _menuMuted;

  Future<void> init({required bool startHidden}) async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'Okul Zili',
      size: Size(1280, 820),
      minimumSize: Size(1024, 640),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (!startHidden) await showWindow();
    });
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await trayManager.setIcon(Platform.isWindows ? 'assets/tray/tray.ico' : 'assets/tray/tray.png');
    await trayManager.setToolTip('Okul Zili');
    trayManager.addListener(this);
    _toast = Platform.isWindows ? WindowsToastNotifier(onTap: _onToastTap) : const NoopToastNotifier();
    _presenter = NoticePresenter(
      setToolTip: trayManager.setToolTip,
      isWindowVisible: windowManager.isVisible,
      showInactive: () => windowManager.show(inactive: true),
      toast: _toast,
    );
    controller.onNotice = _onNotice;
    controller.addListener(_syncMenu);
    await _syncMenu();
    // Toast en son ve beklenmeden kurulur: takılsa ya da hata verse de tepsi
    // menüsü ve ipucu+pencere yolu çalışır; hazır olmadan gelen bildirim
    // toast'suz gösterilir.
    _initToast();
  }

  void _initToast() {
    _toast.init().timeout(const Duration(seconds: 5)).catchError((Object e, StackTrace st) {
      ErrorLog.write('bildirim başlatma', e, st);
    });
  }

  @override
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _clearTooltip();
  }

  bool _alerting = false;

  late ToastNotifier _toast;
  NoticePresenter? _presenter;

  /// Sorun bildirimi: tepsi ipucu + pencere gizliyse toast ve odak çalmadan öne getirme.
  void _onNotice(String title, String body) {
    _alerting = true;
    _presenter?.present(title, body);
  }

  void _onToastTap() {
    navigation.value = AppPage.logs;
    showWindow();
  }

  void _clearTooltip() {
    if (!_alerting) return;
    _alerting = false;
    trayManager.setToolTip('Okul Zili').catchError((Object e, StackTrace st) {
      ErrorLog.write('tepsi ipucu', e, st);
    });
  }

  @override
  Future<void> setFullScreen(bool fullScreen) => windowManager.setFullScreen(fullScreen);

  @override
  Future<void> requestQuit() async {
    await showWindow();
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    // Şifre kilidi varsa ve oturum kilitliyse önce şifre sorulur.
    if (!await ensureUnlocked(context, controller)) return;
    if (!context.mounted) return;
    if (!await confirmQuit(context)) return;
    _quitting = true;
    controller.removeListener(_syncMenu);
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  /// Menü yalnızca susturma durumu değişince yeniden kurulur.
  Future<void> _syncMenu() async {
    final muted = controller.isMuted;
    if (_menuMuted == muted) return;
    _menuMuted = muted;
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Pencereyi göster'),
      MenuItem(key: 'ring', label: 'Şimdi zil çal'),
      muted
          ? MenuItem(key: 'unmute', label: 'Susturmayı kaldır')
          : MenuItem(key: 'mute', label: 'Bugün sustur'),
      MenuItem(key: 'pano', label: 'Pano modunu aç'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Çıkış…'),
    ]));
  }

  // ---- WindowListener -------------------------------------------------------

  @override
  void onWindowClose() {
    if (_quitting) return;
    controller.lock();
    windowManager.hide();
  }

  // ---- TrayListener ---------------------------------------------------------

  @override
  void onTrayIconMouseDown() => showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showWindow();
      case 'ring':
        controller.ringNow();
      case 'mute':
        controller.muteForToday();
      case 'unmute':
        controller.unmute();
      case 'pano':
        navigation.value = AppPage.pano;
        showWindow();
      case 'quit':
        requestQuit();
    }
  }
}
