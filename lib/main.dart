import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'app_controller.dart';
import 'data/config_repository.dart';
import 'platform/bell_player.dart';
import 'platform/desktop_shell.dart';
import 'platform/system_services.dart';
import 'ui/app_shell.dart';
import 'ui/navigation.dart';
import 'ui/theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  DesktopShell? shell;
  if (Platform.isWindows) {
    // İkinci kez açılmaya çalışılırsa yeni kopya kapanır, açık olanın
    // penceresi öne gelir. Böylece aynı zil iki kez çalmaz.
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      'okul_zili_tek_kopya',
      onSecondWindow: (_) => shell?.showWindow(),
    );
  }

  final repository = await ConfigRepository.openDefault();
  final config = await repository.load();
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
    await shell.init(startHidden: args.contains(WindowsSystemServices.autostartArg));
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
      home: AppShell(controller: controller, navigation: navigation, windowControls: windowControls),
    );
  }
}
