import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../features/calendar/calendar_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/events/events_page.dart';
import '../features/logs/logs_page.dart';
import '../features/pano/pano_page.dart';
import '../features/schedule/schedule_page.dart';
import '../features/settings/settings_page.dart';
import '../features/sounds/sounds_page.dart';
import 'navigation.dart';
import 'theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.navigation,
    required this.windowControls,
  });

  final AppController controller;
  final ValueNotifier<AppPage> navigation;
  final WindowControls windowControls;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppPage>(
      valueListenable: navigation,
      builder: (context, page, _) {
        if (page == AppPage.pano) {
          return PanoPage(
            controller: controller,
            windowControls: windowControls,
            onExit: () => navigation.value = AppPage.home,
          );
        }
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(
                controller: controller,
                current: page,
                onSelect: (p) => navigation.value = p,
              ),
              Expanded(child: _page(page)),
            ],
          ),
        );
      },
    );
  }

  Widget _page(AppPage page) => switch (page) {
        AppPage.home => DashboardPage(controller: controller, onNavigate: (p) => navigation.value = p),
        AppPage.program => SchedulePage(controller: controller),
        AppPage.calendar => CalendarPage(controller: controller),
        AppPage.events => EventsPage(controller: controller),
        AppPage.sounds => SoundsPage(controller: controller),
        AppPage.logs => LogsPage(controller: controller),
        AppPage.settings => SettingsPage(controller: controller, windowControls: windowControls),
        AppPage.pano => const SizedBox.shrink(),
      };
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.controller, required this.current, required this.onSelect});

  final AppController controller;
  final AppPage current;
  final ValueChanged<AppPage> onSelect;

  static const _mainPages = [
    AppPage.home,
    AppPage.program,
    AppPage.calendar,
    AppPage.events,
    AppPage.sounds,
    AppPage.logs,
    AppPage.settings,
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: controller, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    // Dar pencerede yalnızca simgeler görünür.
    final compact = MediaQuery.sizeOf(context).width < 1180;
    final unsavedSchedule = controller.scheduleDraft?.dirty ?? false;
    return Container(
      width: compact ? 80 : 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.recess, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.notifications, color: AppColors.ink),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Okul Zili', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(
                          controller.config.schoolName.isEmpty ? 'Okul adı girilmedi' : controller.config.schoolName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          for (final page in _mainPages) ...[
            _NavItem(
              page: page,
              selected: page == current,
              compact: compact,
              badge: page == AppPage.program && unsavedSchedule,
              onTap: () => onSelect(page),
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          _NavItem(
            page: AppPage.pano,
            selected: false,
            compact: compact,
            outlined: true,
            label: 'Pano modunu aç',
            onTap: () => onSelect(AppPage.pano),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.page,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.outlined = false,
    this.badge = false,
    this.label,
  });

  final AppPage page;
  final bool selected;
  final bool compact;
  final bool outlined;

  /// Kaydedilmemiş değişiklik işareti.
  final bool badge;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.lessonText : (outlined ? AppColors.ink : AppColors.inkSecondary);
    final text = label ?? page.label;
    final semanticText = badge ? '$text (kaydedilmedi)' : text;
    final item = Material(
      color: selected ? AppColors.lessonTint : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: outlined ? const BorderSide(color: AppColors.line) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Badge(
                  isLabelVisible: badge,
                  smallSize: 9,
                  backgroundColor: AppColors.lunch,
                  child: Icon(selected ? page.selectedIcon : page.icon, size: 20, color: fg),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      label: compact || badge ? semanticText : null,
      child: compact ? Tooltip(message: semanticText, child: item) : item,
    );
  }
}
