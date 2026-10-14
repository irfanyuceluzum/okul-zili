import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app_controller.dart';
import '../ui/navigation.dart';

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
    controller.addListener(_syncMenu);
    await _syncMenu();
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> setFullScreen(bool fullScreen) => windowManager.setFullScreen(fullScreen);

  @override
  Future<void> requestQuit() async {
    await showWindow();
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
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
