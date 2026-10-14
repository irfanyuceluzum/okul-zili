import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app_controller.dart';
import '../../ui/navigation.dart';

/// Bilgisayar ayarlanan süre boyunca kullanılmazsa pano moduna geçer.
///
/// Windows'ta boşta kalma süresi tüm sistemden okunur: biri başka bir
/// programda çalışıyorsa pano onun ekranını kaplamaz. Okunamazsa yalnızca
/// bu uygulamadaki fare/klavye hareketlerine bakılır.
class PanoIdleWatcher extends StatefulWidget {
  const PanoIdleWatcher({
    super.key,
    required this.controller,
    required this.navigation,
    required this.windowControls,
    required this.child,
    this.checkInterval = const Duration(seconds: 5),
  });

  final AppController controller;
  final ValueNotifier<AppPage> navigation;
  final WindowControls windowControls;
  final Widget child;
  final Duration checkInterval;

  @override
  State<PanoIdleWatcher> createState() => _PanoIdleWatcherState();
}

class _PanoIdleWatcherState extends State<PanoIdleWatcher> {
  late DateTime _lastInput;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _lastInput = widget.controller.now();
    _timer = Timer.periodic(widget.checkInterval, (_) => _check());
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    _timer.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    _markInput();
    return false;
  }

  void _markInput() => _lastInput = widget.controller.now();

  Duration _idleFor() {
    final inApp = widget.controller.now().difference(_lastInput);
    final system = widget.controller.system.idleTime();
    return system != null && system < inApp ? system : inApp;
  }

  Future<void> _check() async {
    final minutes = widget.controller.config.panoIdleMinutes;
    if (minutes <= 0 || widget.navigation.value == AppPage.pano) return;
    if (_idleFor() < Duration(minutes: minutes)) return;
    await widget.windowControls.showWindow();
    widget.navigation.value = AppPage.pano;
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _markInput(),
        onPointerMove: (_) => _markInput(),
        onPointerHover: (_) => _markInput(),
        onPointerSignal: (_) => _markInput(),
        child: widget.child,
      );
}
