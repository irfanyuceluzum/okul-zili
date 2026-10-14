import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/scheduler/bell_log.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final logs = controller.logs;
        final logFile = controller.logFilePath;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Kayıtlar',
                subtitle: SelectableText('Uygulama açıldığından beri olanlar. Tüm geçmiş: $logFile'),
              ),
              const SizedBox(height: 24),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: const Color(0xFFF8F9FB),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: const DefaultTextStyle(
                        style: TextStyle(fontFamily: appFontFamily, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.inkMuted),
                        child: Row(
                          children: [
                            SizedBox(width: 160, child: Text('ZAMAN')),
                            Expanded(child: Text('ZİL')),
                            SizedBox(width: 120, child: Text('SONUÇ')),
                            Expanded(child: Text('AÇIKLAMA')),
                          ],
                        ),
                      ),
                    ),
                    if (logs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Henüz kayıt yok. İlk zil çaldığında burada görünecek.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkMuted)),
                      ),
                    for (final entry in logs) _LogRow(entry),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow(this.entry);

  final BellLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final at = entry.at;
    String two(int v) => v.toString().padLeft(2, '0');
    final (bg, fg) = switch (entry.outcome) {
      BellOutcome.played => (AppColors.okTint, AppColors.okText),
      BellOutcome.missed => (AppColors.lunchTint, AppColors.lunchText),
      BellOutcome.muted => (AppColors.neutralTint, AppColors.inkSecondary),
      BellOutcome.failed => (AppColors.dangerTint, AppColors.dangerText),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text('${two(at.day)}.${two(at.month)} ${two(at.hour)}:${two(at.minute)}:${two(at.second)}',
                style: const TextStyle(fontFeatures: tabularFigures)),
          ),
          Expanded(child: Text(entry.bell.label)),
          SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: Pill(entry.outcome.label, background: bg, foreground: fg))),
          Expanded(child: Text(entry.detail ?? '', style: const TextStyle(color: AppColors.inkSecondary))),
        ],
      ),
    );
  }
}
