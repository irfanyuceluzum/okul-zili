import 'dart:io';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/app_info.dart';
import '../../data/config_repository.dart';
import '../../data/models/app_config.dart';
import '../../ui/about_dialog.dart';
import '../../ui/lock_dialog.dart';
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

  /// Okul adı alandan çıkınca da kaydedilir; Kaydet'e basmayı unutan
  /// kişinin yazdığı kaybolmasın.
  final _nameFocus = FocusNode();
  String? _nameError;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && !_disposing) _saveSchoolName(quiet: true);
    });
  }

  @override
  void dispose() {
    // Sayfadan çıkılıyor: geçerli bir ad yazıldıysa kaydet, uyarı gösterme.
    _disposing = true;
    final name = _schoolName.text.trim();
    final c = widget.controller;
    if (name.isNotEmpty && name != c.config.schoolName) {
      // Ağaç kilitliyken arayüz yenilenemez; kayıt kare bitince yapılır.
      Future.microtask(() => c.updateConfig(c.config.copyWith(schoolName: name)));
    }
    _nameFocus.dispose();
    _schoolName.dispose();
    super.dispose();
  }

  /// Kilit etkin ve oturum kilitliyse önce şifre sorulur; sonra onaylı kapatma.
  Future<void> _quit() async {
    if (!await ensureUnlocked(context, widget.controller)) return;
    if (!mounted) return;
    await widget.windowControls.requestQuit();
  }

  Future<void> _saveSchoolName({bool quiet = false}) async {
    final name = _schoolName.text.trim();
    final c = widget.controller;
    if (name.isEmpty) {
      if (mounted && !_disposing) setState(() => _nameError = 'Okul adı boş olamaz');
      return;
    }
    if (name == c.config.schoolName) return;
    await c.updateConfig(c.config.copyWith(schoolName: name));
    if (!quiet && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Okul adı kaydedildi')));
    }
  }

  // ---- Yedekler ve taşıma --------------------------------------------------

  List<BackupInfo>? _backups;
  AppConfig? _backupsFor;

  /// Yedek listesi yalnız ayar değişince yeniden okunur (diske her karede bakılmasın).
  List<BackupInfo> _currentBackups(AppController c) {
    if (_backups == null || !identical(_backupsFor, c.config)) {
      try {
        _backups = c.repository.listBackups();
      } catch (_) {
        _backups = const [];
      }
      _backupsFor = c.config;
    }
    return _backups!;
  }

  Widget _backupList(AppController c) {
    final backups = _currentBackups(c);
    if (backups.isEmpty) {
      return const Text('Henüz yedek yok. Ayarlar ilk kez kaydedilince yedek alınır.',
          style: TextStyle(color: AppColors.inkSecondary));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final b in backups)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(b.label, style: const TextStyle(fontFeatures: tabularFigures)),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _replace(b.file, () => widget.controller.restoreBackup(b)),
                child: const Text('Geri yükle'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final c = widget.controller;
    final path = await c.pickExportPath();
    if (path == null || !mounted) return;
    final error = await c.exportConfig(path);
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayarlar dışa aktarıldı')));
    } else {
      await _showMessage('Dışa aktarılamadı', error);
    }
  }

  Future<void> _import() async {
    final c = widget.controller;
    final path = await c.pickConfigFile();
    if (path == null || !mounted) return;
    await _replace(File(path), () => c.importConfigFile(path));
  }

  /// Önce dosyanın özetini onaylatır; okunamıyorsa hata gösterir ve hiçbir şey değiştirmez.
  Future<void> _replace(File source, Future<ReplaceResult> Function() apply) async {
    final c = widget.controller;
    final AppConfig loaded;
    try {
      loaded = c.repository.readConfigFile(source).$1;
    } catch (e) {
      await _showMessage('Dosya okunamadı',
          'Ayarlar değişmedi. Bozuk ya da bu uygulamanın ayar dosyası değil.');
      return;
    }
    if (!mounted) return;
    final lessons = loaded.templates.fold<int>(0, (n, t) => n + t.lessons.length);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu ayarlar yüklensin mi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Okul adı: ${loaded.schoolName}'),
            Text('Program şablonu: ${loaded.templates.length}'),
            Text('Toplam ders: $lessons'),
            Text('Zil sesi: ${loaded.sounds.length}'),
            const SizedBox(height: 12),
            const Text('Mevcut ayarlar önce yedeklenecek.'),
            if (c.isLockEnabled)
              const Text('Şifre kilidi değişmeyecek.')
            else if (loaded.lock != null)
              const Text('Dosyadaki şifre kilidi alınmayacak.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yükle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await apply();
    if (!mounted) return;
    if (!r.ok) {
      await _showMessage('Ayarlar yüklenemedi', r.error ?? 'Bilinmeyen hata; ayarlar değişmedi.');
      return;
    }
    final notes = [
      if (r.missingSounds.isNotEmpty)
        'Bulunamayan sesler yerine klasik zil çalar: ${r.missingSounds.join(', ')}.',
      ...r.warnings,
    ];
    if (notes.isNotEmpty) await _showMessage('Ayarlar yüklendi', notes.join('\n'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Ayarlar yüklendi'),
      action: SnackBarAction(label: 'Geri al', onPressed: c.undoReplace),
    ));
  }

  Future<void> _showMessage(String title, String text) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );

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
                  icon: Icons.school_outlined,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _schoolName,
                          focusNode: _nameFocus,
                          decoration: InputDecoration(labelText: 'Okul adı', errorText: _nameError),
                          onChanged: (_) {
                            if (_nameError != null) setState(() => _nameError = null);
                          },
                          onSubmitted: (_) => _saveSchoolName(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () => _saveSchoolName(),
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Zil sesi',
                  icon: Icons.volume_up_outlined,
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
                  icon: Icons.power_settings_new_rounded,
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
                  icon: Icons.tv_outlined,
                  subtitle: 'Bilgisayar bu süre boyunca kullanılmazsa koridor ekranı görünümü kendiliğinden açılır. '
                      'Çıkmak için Esc tuşuna basın.',
                  child: Row(
                    children: [
                      const Text('Kendiliğinden aç:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      SoftDropdown<int>(
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
                  title: 'Şifre kilidi',
                  icon: Icons.lock_outline_rounded,
                  subtitle: 'Kilitliyken zil çalma, susturma, acil durum ve pano serbesttir; ayarlar korunur. '
                      'Şifre unutulursa kurtarma koduyla açılır.',
                  child: c.isLockEnabled
                      ? Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                              onPressed: () => setPasswordFlow(context, c),
                              icon: const Icon(Icons.key),
                              label: const Text('Şifreyi değiştir'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                              onPressed: () => removeLockFlow(context, c),
                              icon: const Icon(Icons.lock_open),
                              label: const Text('Kilidi kaldır'),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                            onPressed: () => setPasswordFlow(context, c),
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Şifre belirle'),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Yedekler ve taşıma',
                  icon: Icons.backup_outlined,
                  subtitle: 'Ayarlar kaydedildikçe otomatik yedek alınır. '
                      'Başka bir okula taşımak için ayarları dışa aktarın.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(c.repository.file.path, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                            onPressed: _export,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Dışa aktar…'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                            onPressed: _import,
                            icon: const Icon(Icons.download),
                            label: const Text('İçe aktar…'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Yedekler', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      _backupList(c),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Hakkında',
                  icon: Icons.info_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('${AppInfo.name} ${AppInfo.version} · Geliştirici: ${AppInfo.developer}',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Ücretsiz ve özgür yazılımdır; ${AppInfo.license} ile dağıtılır.',
                          style: TextStyle(color: AppColors.inkSecondary)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () => showAboutAppDialog(context),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Hakkında ve lisans'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
                    onPressed: _quit,
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
