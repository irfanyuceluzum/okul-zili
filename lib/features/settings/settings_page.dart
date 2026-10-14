import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/navigation.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller, required this.windowControls});

  final AppController controller;
  final WindowControls windowControls;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _schoolName = TextEditingController(text: widget.controller.config.schoolName);
  late double _volume = widget.controller.config.volumePercent.toDouble();

  @override
  void dispose() {
    _schoolName.dispose();
    super.dispose();
  }

  Future<void> _saveSchoolName() async {
    final name = _schoolName.text.trim();
    if (name.isEmpty) return;
    final c = widget.controller;
    await c.updateConfig(c.config.copyWith(schoolName: name));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Okul adı kaydedildi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(title: 'Ayarlar'),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Okul',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _schoolName,
                          decoration: const InputDecoration(labelText: 'Okul adı'),
                          onSubmitted: (_) => _saveSchoolName(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: _saveSchoolName,
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Zil sesi',
                  subtitle: c.system.controlsVolume
                      ? 'Zil çalmadan önce bilgisayarın sessiz modu kapatılır ve ses en az bu seviyeye açılır.'
                      : 'Zil bu seviyede çalar. (Sistem sesi yalnızca Windows\'ta otomatik açılır.)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.volume_down, color: AppColors.inkSecondary),
                          Expanded(
                            child: Slider(
                              value: _volume,
                              min: 10,
                              max: 100,
                              divisions: 18,
                              label: '%${_volume.round()}',
                              onChanged: (v) => setState(() => _volume = v),
                              onChangeEnd: (v) => c.updateConfig(c.config.copyWith(volumePercent: v.round())),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text('%${_volume.round()}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFeatures: tabularFigures)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: c.ringNow,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Deneme zili çal'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Başlatma',
                  child: c.system.supportsAutostart
                      ? SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: c.autostartEnabled ?? false,
                          onChanged: c.autostartEnabled == null ? null : c.setAutostart,
                          title: const Text('Bilgisayar açılınca otomatik başlat', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Uygulama pencere açmadan sistem tepsisinde başlar ve zilleri çalar.'),
                        )
                      : const Text('Otomatik başlatma yalnızca Windows\'ta kullanılabilir.',
                          style: TextStyle(color: AppColors.inkSecondary)),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Pano modu',
                  subtitle: 'Bilgisayar bu süre boyunca kullanılmazsa koridor ekranı görünümü kendiliğinden açılır. '
                      'Çıkmak için Esc tuşuna basın.',
                  child: Row(
                    children: [
                      const Text('Kendiliğinden aç:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: const [0, 1, 3, 5, 10, 15, 30].contains(c.config.panoIdleMinutes) ? c.config.panoIdleMinutes : 3,
                        onChanged: (v) => c.updateConfig(c.config.copyWith(panoIdleMinutes: v)),
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('Kapalı')),
                          for (final m in const [1, 3, 5, 10, 15, 30])
                            DropdownMenuItem(value: m, child: Text('$m dakika boşta kalınca')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Ayar dosyası',
                  subtitle: 'Yedeklemek ya da başka bir bilgisayara taşımak için bu dosyayı kopyalayın.',
                  child: SelectableText(c.repository.file.path, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
                    onPressed: widget.windowControls.requestQuit,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Uygulamayı tamamen kapat'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
