import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'app_controller.dart';
import 'data/config_repository.dart';
import 'features/pano/pano_idle_watcher.dart';
import 'platform/bell_player.dart';
import 'platform/desktop_shell.dart';
import 'platform/error_log.dart';
import 'platform/system_services.dart';
import 'ui/app_shell.dart';
import 'ui/navigation.dart';
import 'ui/theme.dart';

Future<void> main(List<String> args) async {
  // Hiçbir hata uygulamayı görünmez ve zilsiz bırakmasın: her adım ayrı
  // korunur, yakalanmayan hatalar hata_kayitlari.log'a yazılır.
  runZonedGuarded(() => _start(args), (error, stack) => ErrorLog.write('yakalanmayan hata', error, stack));
}

Future<void> _start(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLog.write('arayüz', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLog.write('platform', error, stack);
    return true;
  };

  DesktopShell? shell;
  if (Platform.isWindows) {
    try {
      // İkinci kez açılmaya çalışılırsa yeni kopya kapanır, açık olanın
      // penceresi öne gelir. Böylece aynı zil iki kez çalmaz.
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        'okul_zili_tek_kopya',
        onSecondWindow: (_) => shell != null ? shell.showWindow() : windowManager.show(),
      );
    } catch (e, st) {
      ErrorLog.write('tek kopya denetimi', e, st);
    }
  }

  ConfigRepository repository;
  try {
    repository = await ConfigRepository.openDefault();
  } catch (e, st) {
    // Uygulama veri klasörü alınamazsa geçici klasörle de olsa çalış.
    final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}okul_zili')..createSync(recursive: true);
    repository = ConfigRepository(File('${dir.path}${Platform.pathSeparator}config.json'));
    ErrorLog.init(dir);
    ErrorLog.write('ayar klasörü', e, st);
  }
  ErrorLog.init(repository.file.parent);
  final config = await repository.load(); // Hata fırlatmaz; gerekirse yedeğe döner.

  final controller = AppController(
    config: config,
    repository: repository,
    player: AudioBellPlayer(),
    system: SystemServices.forPlatform(),
  )..start();

  final navigation = ValueNotifier(AppPage.home);
  final navigatorKey = GlobalKey<NavigatorState>();
  if (DesktopShell.isSupported) {
    shell = DesktopShell(controller: controller, navigation: navigation, navigatorKey: navigatorKey);
    // Ayarlar yedekten yüklendiyse otomatik başlatmada da pencere açılsın;
    // uyarı tepside kimsenin görmediği bir pencerede kalmasın.
    final hidden = args.contains(WindowsSystemServices.autostartArg) && repository.lastLoadWarning == null;
    try {
      await shell.init(startHidden: hidden);
    } catch (e, st) {
      ErrorLog.write('pencere/sistem tepsisi', e, st);
      try {
        await windowManager.show();
      } catch (_) {}
    }
  }

  runApp(OkulZiliApp(
    controller: controller,
    navigation: navigation,
    navigatorKey: navigatorKey,
    windowControls: shell ?? const NoopWindowControls(),
  ));
}

class OkulZiliApp extends StatelessWidget {
  const OkulZiliApp({
    super.key,
    required this.controller,
    required this.navigation,
    required this.windowControls,
    this.navigatorKey,
  });

  final AppController controller;
  final ValueNotifier<AppPage> navigation;
  final WindowControls windowControls;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Okul Zili',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildAppTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => PanoIdleWatcher(
        controller: controller,
        navigation: navigation,
        windowControls: windowControls,
        child: child!,
      ),
      home: AppShell(controller: controller, navigation: navigation, windowControls: windowControls),
    );
  }
}
