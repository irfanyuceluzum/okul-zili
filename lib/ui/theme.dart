import 'package:flutter/material.dart';

import '../core/scheduler/day_schedule.dart';

/// Tasarımdaki renkler. Renkler anlam taşır: lacivert ders, sarı teneffüs,
/// turuncu öğle arası, yeşil tatil/tamam, kırmızı yalnızca acil durum ve hata.
abstract final class AppColors {
  static const ink = Color(0xFF14213D);
  static const inkSecondary = Color(0xFF4E5A6E);
  static const inkMuted = Color(0xFF7A8496);
  static const line = Color(0xFFE4E9F0);
  static const lineSoft = Color(0xFFEFF2F6);
  static const lineStrong = Color(0xFFD3DAE5);
  static const ground = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const neutralTint = Color(0xFFEFF2F6);

  /// Yazı alanları ve açılır menülerin dolgusu.
  static const field = Color(0xFFF4F6FA);
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

/// Kartların yumuşak gölgesi (çizgi yerine derinlik).
abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0A14213D), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D14213D), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const raised = [
    BoxShadow(color: Color(0x1414213D), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1F14213D), blurRadius: 32, offset: Offset(0, 16)),
  ];
}

/// Ana ekrandaki durum kartının renk geçişi ve yazı rengi.
class PeriodGradient {
  const PeriodGradient(this.colors, this.foreground, this.soft);

  final List<Color> colors;
  final Color foreground;

  /// Kart üstündeki yarı saydam yüzeyler (halka izi, çizelge zemini).
  final Color soft;

  LinearGradient get gradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors);

  static PeriodGradient of(PeriodKind kind) => switch (kind) {
        PeriodKind.lesson =>
          const PeriodGradient([Color(0xFF173C80), Color(0xFF2D63C8)], Colors.white, Color(0x33FFFFFF)),
        PeriodKind.breakTime =>
          const PeriodGradient([Color(0xFFF2B825), Color(0xFFF9D66A)], AppColors.recessText, Color(0x336A5000)),
        PeriodKind.lunch =>
          const PeriodGradient([Color(0xFFD9701C), Color(0xFFF0A055)], Colors.white, Color(0x40FFFFFF)),
        _ => const PeriodGradient([Color(0xFF3D4B66), Color(0xFF6B7A96)], Colors.white, Color(0x33FFFFFF)),
      };
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
  // Material 3'ün mor tonlu yüzeyleri yerine beyaz ve açık gri: pencereler,
  // menüler ve tarih seçici kartlarla aynı ailede görünsün.
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.lesson,
    primary: AppColors.lesson,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSecondary,
    error: AppColors.danger,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
  ).copyWith(
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.field,
    secondaryContainer: AppColors.lessonTint,
    onSecondaryContainer: AppColors.lessonText,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    scaffoldBackgroundColor: AppColors.ground,
    visualDensity: VisualDensity.standard,
  );
  final text = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14)));
  const fieldRadius = BorderRadius.all(Radius.circular(12));
  const buttonText = TextStyle(fontFamily: appFontFamily, fontSize: 15, fontWeight: FontWeight.w600);
  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleMedium: text.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13, color: AppColors.inkSecondary),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: Color(0x3314213D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      titleTextStyle: TextStyle(fontFamily: appFontFamily, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(12),
        shadowColor: WidgetStatePropertyAll(Color(0x4014213D)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14)))),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: appFontFamily, fontSize: 15, fontWeight: FontWeight.w500)),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? AppColors.inkMuted : AppColors.ink),
        overlayColor: const WidgetStatePropertyAll(AppColors.lessonTint),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.all(Radius.circular(8))),
      textStyle: TextStyle(fontFamily: appFontFamily, fontSize: 13, color: Colors.white),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: Duration(milliseconds: 400),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(fontFamily: appFontFamily, fontSize: 15, color: Colors.white),
      actionTextColor: Color(0xFFB9CCF2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      width: 560,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
      side: const BorderSide(color: AppColors.lineStrong, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.lesson : Colors.transparent),
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
      thumbColor: WidgetStatePropertyAll(AppColors.inkMuted.withValues(alpha: 0.4)),
    ),
    listTileTheme: const ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lesson,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
      ).copyWith(
        // Yumuşak renkli gölge: birincil düğme öne çıksın ama ağır durmasın.
        shadowColor: const WidgetStatePropertyAll(Color(0x661F4EA3)),
        elevation: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? 0 : (s.contains(WidgetState.hovered) ? 6 : 3)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: AppColors.line),
        shape: buttonShape,
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
      ).copyWith(
        overlayColor: const WidgetStatePropertyAll(AppColors.lessonTint),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.lesson,
        textStyle: buttonText,
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      border: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: AppColors.lesson, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: AppColors.danger, width: 1.5)),
      labelStyle: TextStyle(color: AppColors.inkSecondary),
      floatingLabelStyle: TextStyle(color: AppColors.lesson, fontWeight: FontWeight.w600),
      isDense: true,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.inkMuted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.lesson : AppColors.line),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : AppColors.lineStrong),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.lesson,
      thumbColor: AppColors.lesson,
      inactiveTrackColor: AppColors.lineSoft,
    ),
  );
}
