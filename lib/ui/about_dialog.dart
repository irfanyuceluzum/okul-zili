import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_info.dart';
import 'theme.dart';

/// Lisans sayfasında (Kullanılan bileşenler) paketlerin yanında görünecek
/// lisansları kaydeder. main() açılışta bir kez çağırır.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['IBM Plex Sans (yazı tipi)'], ofl);
  });
}

/// Geliştirici, sürüm ve lisans bilgisi. Şifre kilidinden bağımsızdır.
Future<void> showAboutAppDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _AboutDialog(),
  );
}

class _AboutDialog extends StatefulWidget {
  const _AboutDialog();

  @override
  State<_AboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<_AboutDialog> {
  bool _copied = false;

  Future<void> _copyUrl() async {
    await Clipboard.setData(const ClipboardData(text: AppInfo.sourceUrl));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const muted = TextStyle(color: AppColors.inkSecondary, height: 1.4);
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.recess, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.notifications, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text(AppInfo.name)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Sürüm', AppInfo.version),
              _row('Geliştirici', AppInfo.developer),
              const SizedBox(height: 4),
              const Text('Kaynak kod ve güncellemeler', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Expanded(child: SelectableText(AppInfo.sourceUrl)),
                  TextButton.icon(
                    onPressed: _copyUrl,
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                    label: Text(_copied ? 'Kopyalandı' : 'Kopyala'),
                  ),
                ],
              ),
              const Divider(height: 28),
              Text('Lisans', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              const Text(
                '${AppInfo.name} özgür yazılımdır ve ${AppInfo.license} ile dağıtılır. '
                'Programı kullanabilir, inceleyebilir, değiştirebilir ve paylaşabilirsiniz. '
                'Programı (değiştirilmiş ya da değiştirilmemiş) dağıtan herkes kaynak kodunu da '
                'aynı lisansla vermek zorundadır.',
                style: muted,
              ),
              const SizedBox(height: 10),
              const Text(
                'Ücretsizdir: ${AppInfo.name} para kazanma amacı olmadan geliştirilmiştir ve ücretsiz '
                'dağıtılır. Resmî indirme adresi yukarıdaki GitHub sayfasıdır.',
                style: muted,
              ),
              const SizedBox(height: 10),
              const Text(
                'Garanti yoktur: Bu program yararlı olması umuduyla, HİÇBİR GARANTİ OLMADAN dağıtılır. '
                'Ayrıntılar için lisans metnine bakın.',
                style: muted,
              ),
              const SizedBox(height: 10),
              const Text('IBM Plex Sans yazı tipi SIL Open Font License 1.1 ile kullanılmıştır.', style: muted),
              const SizedBox(height: 14),
              Text(AppInfo.copyright, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => _showLicenseText(context), child: const Text('Lisans metni')),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: AppInfo.name,
            applicationVersion: AppInfo.version,
            applicationLegalese: '${AppInfo.copyright}\n${AppInfo.license}',
          ),
          child: const Text('Kullanılan bileşenler'),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Kapat')),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: SelectableText(value)),
          ],
        ),
      );
}

/// GPL-3.0 tam metni (İngilizce; lisansın resmî metni budur).
Future<void> _showLicenseText(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Lisans metni (GPL-3.0)'),
      content: SizedBox(
        width: 640,
        height: 480,
        child: FutureBuilder<String>(
          future: rootBundle.loadString('LICENSE'),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Lisans metni açılamadı. Metin için: ${AppInfo.sourceUrl}/blob/main/LICENSE');
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return SingleChildScrollView(
              child: SelectableText(snapshot.data!, style: const TextStyle(fontSize: 12, height: 1.35)),
            );
          },
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Kapat')),
      ],
    ),
  );
}
