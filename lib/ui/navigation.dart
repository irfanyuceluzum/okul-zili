import 'package:flutter/material.dart';

enum AppPage {
  home('Ana ekran', Icons.home_outlined, Icons.home),
  program('Ders programı', Icons.schedule_outlined, Icons.schedule),
  calendar('Takvim ve tatiller', Icons.calendar_month_outlined, Icons.calendar_month),
  events('Özel etkinlikler', Icons.star_outline, Icons.star),
  sounds('Zil sesleri', Icons.music_note_outlined, Icons.music_note),
  notices('Duyuru ve nöbet', Icons.campaign_outlined, Icons.campaign),
  logs('Kayıtlar', Icons.list_alt_outlined, Icons.list_alt),
  settings('Ayarlar', Icons.tune_outlined, Icons.tune),
  pano('Pano modu', Icons.tv_outlined, Icons.tv);

  const AppPage(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Pencereyle ilgili işlemler; masaüstünde window_manager, testlerde boş.
abstract interface class WindowControls {
  Future<void> setFullScreen(bool fullScreen);

  /// Sistem tepsisinde gizliyse pencereyi gösterir.
  Future<void> showWindow();

  /// Onay sorup uygulamayı tamamen kapatır.
  Future<void> requestQuit();
}

class NoopWindowControls implements WindowControls {
  const NoopWindowControls();

  @override
  Future<void> setFullScreen(bool fullScreen) async {}

  @override
  Future<void> showWindow() async {}

  @override
  Future<void> requestQuit() async {}
}

/// Uygulamayı kapatmadan önce sorulan soru. Zil yalnızca uygulama açıkken
/// çaldığı için yanlışlıkla kapatılmasın.
Future<bool> confirmQuit(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Uygulama kapatılsın mı?'),
      content: const Text(
        'Okul Zili kapanırsa ziller çalmaz. Pencereyi kapatmak için '
        'çarpı düğmesini kullanın; uygulama sistem tepsisinde çalışmaya devam eder.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC42B2B), minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Uygulamayı kapat'),
        ),
      ],
    ),
  );
  return result ?? false;
}
