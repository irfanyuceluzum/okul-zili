import 'package:flutter/material.dart';

import '../core/scheduler/day_schedule.dart';

/// Tasarımdaki renkler. Renkler anlam taşır: lacivert ders, sarı teneffüs,
/// turuncu öğle arası, yeşil tatil/tamam, kırmızı yalnızca acil durum ve hata.
abstract final class AppColors {
  static const ink = Color(0xFF14213D);
  static const inkSecondary = Color(0xFF4E5A6E);
  static const inkMuted = Color(0xFF7A8496);
  static const line = Color(0xFFE1E6EE);
  static const lineSoft = Color(0xFFEEF1F5);
  static const lineStrong = Color(0xFFC9D1DE);
  static const ground = Color(0xFFF3F5F8);
  static const surface = Color(0xFFFFFFFF);
  static const neutralTint = Color(0xFFEEF1F5);
  static const assembly = Color(0xFFB8C3D6);

  static const lesson = Color(0xFF1F4EA3);
  static const lessonTint = Color(0xFFE6EDFA);
  static const lessonText = Color(0xFF173C80);

  static const recess = Color(0xFFF2C230);
  static const recessTint = Color(0xFFFFF3C4);
  static const recessText = Color(0xFF6A5000);

  static const lunch = Color(0xFFE8822A);
  static const lunchTint = Color(0xFFFDEAD7);
  static const lunchText = Color(0xFF8A4512);

  static const ok = Color(0xFF2F8F5B);
  static const okTint = Color(0xFFE2F3E9);
  static const okText = Color(0xFF1D6A41);

  static const danger = Color(0xFFC42B2B);
  static const dangerTint = Color(0xFFFCE7E7);
  static const dangerText = Color(0xFF9E1F1F);

  // Pano modu (koyu)
  static const panoGround = Color(0xFF0C1424);
  static const panoSurface = Color(0xFF152038);
  static const panoText = Color(0xFFF1F4F9);
  static const panoTextSecondary = Color(0xFFA7B1C4);
  static const panoTextMuted = Color(0xFF5F6B82);
  static const panoLesson = Color(0xFF7FA3F0);
  static const panoLunch = Color(0xFFF0974A);
}

/// Bir dönem türünün arka plan, metin ve vurgu renkleri.
class PeriodColors {
  const PeriodColors(this.tint, this.text, this.accent);

  final Color tint;
  final Color text;
  final Color accent;

  static PeriodColors of(PeriodKind kind) => switch (kind) {
        PeriodKind.lesson =>
          const PeriodColors(AppColors.lessonTint, AppColors.lessonText, AppColors.lesson),
        PeriodKind.breakTime =>
          const PeriodColors(AppColors.recessTint, AppColors.recessText, AppColors.recess),
        PeriodKind.lunch =>
          const PeriodColors(AppColors.lunchTint, AppColors.lunchText, AppColors.lunch),
        _ => const PeriodColors(AppColors.neutralTint, AppColors.inkSecondary, AppColors.assembly),
      };
}

const appFontFamily = 'IBM Plex Sans';

/// Eşit genişlikte rakamlar: geri sayım ve saatler titremesin.
const tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.lesson,
    primary: AppColors.lesson,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    scaffoldBackgroundColor: AppColors.ground,
    visualDensity: VisualDensity.standard,
  );
  final text = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
  const buttonText = TextStyle(fontFamily: appFontFamily, fontSize: 15, fontWeight: FontWeight.w600);
  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13, color: AppColors.inkSecondary),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lesson,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: const BorderSide(color: AppColors.lineStrong),
        shape: buttonShape,
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.lesson, textStyle: buttonText),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.lineStrong),
      ),
      isDense: true,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.inkMuted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.lesson : AppColors.lineSoft),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.lesson,
      thumbColor: AppColors.lesson,
      inactiveTrackColor: AppColors.lineSoft,
    ),
  );
}
