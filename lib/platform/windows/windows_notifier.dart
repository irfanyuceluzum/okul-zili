import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../error_log.dart';
import '../notifier.dart';

/// Windows bildirim merkezine gerçek toast gönderir. Hatalar kayda yazılır,
/// dışarı fırlatılmaz; ziller bildirim yüzünden aksamaz.
class WindowsToastNotifier implements ToastNotifier {
  WindowsToastNotifier({required this.onTap});

  /// Bildirime tıklanınca çağrılır.
  final void Function() onTap;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  Future<void> init() async {
    if (!Platform.isWindows) return;
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          windows: WindowsInitializationSettings(
            appName: 'Okul Zili',
            appUserModelId: 'OkulZili.OkulZili',
            guid: '6f1b7c0e-3d2a-4c58-9a41-8e5b2d7f4a13',
          ),
        ),
        onDidReceiveNotificationResponse: (_) => onTap(),
      );
      _ready = ok ?? false;
    } catch (e, st) {
      _ready = false;
      ErrorLog.write('bildirim başlatma', e, st);
    }
  }

  @override
  Future<void> show(String title, String body) async {
    if (!Platform.isWindows || !_ready) return;
    try {
      await _plugin.show(
        id: 1,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(windows: WindowsNotificationDetails()),
      );
    } catch (e, st) {
      ErrorLog.write('bildirim gösterme', e, st);
    }
  }
}
