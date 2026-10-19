import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/app_info.dart';
import '../features/announcements/announcements_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/events/events_page.dart';
import '../features/logs/logs_page.dart';
import '../features/notices/notices_page.dart';
import '../features/pano/pano_page.dart';
import '../features/schedule/schedule_page.dart';
import '../features/settings/settings_page.dart';
import '../features/sounds/sounds_page.dart';
import 'about_dialog.dart';
import 'lock_dialog.dart';
import 'navigation.dart';
import 'theme.dart';

class AppShell extends StatefulWidget {
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
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppController get controller => widget.controller;
  ValueNotifier<AppPage> get navigation => widget.navigation;
  WindowControls get windowControls => widget.windowControls;

  bool _snackQueued = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onController);
    navigation.addListener(_onNavigation);
  }

  @override
  void dispose() {
    controller.removeListener(_onController);
    navigation.removeListener(_onNavigation);
    super.dispose();
  }

  /// Pano modu açılınca oturum kilitlenir (kilit yoksa etkisizdir).
  void _onNavigation() {
    if (navigation.value == AppPage.pano) controller.lock();
  }

  /// Reddedilen ayar değişikliği bildirilir.
  void _onController() {
    if (!controller.lockRefused || _snackQueued) return;
    _snackQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snackQueued = false;
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Ayarlar kilitli; değişiklik kaydedilmedi.')),
      );
      controller.clearLockRefused();
    });
  }

  /// Kilit koruyan sayfalar; Ana ekran, Kayıtlar ve Pano her zaman serbesttir.
  static const _gated = {
    AppPage.program,
    AppPage.calendar,
    AppPage.events,
    AppPage.sounds,
    AppPage.announcements,
    AppPage.notices,
    AppPage.settings,
  };

  Future<void> _go(AppPage page) async {
    if (_gated.contains(page) && controller.isLockEnabled && controller.isLocked) {
      if (!await askUnlock(context, controller)) return;
      if (!mounted) return;
    }
    navigation.value = page;
  }

  void _lockNow() {
    controller.lock();
    navigation.value = AppPage.home;
  }

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
                gated: _gated,
                onSelect: _go,
                onLock: _lockNow,
              ),
              Expanded(
                // Sayfa değişince kısa, yumuşak bir belirme (eski sayfa ağaçta tutulmaz).
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(page),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: 0.35 + 0.65 * t,
                    child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
                  ),
                  child: _page(page),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _page(AppPage page) => switch (page) {
        AppPage.home => DashboardPage(controller: controller, onNavigate: _go),
        AppPage.program => SchedulePage(controller: controller),
        AppPage.calendar => CalendarPage(controller: controller),
        AppPage.events => EventsPage(controller: controller),
        AppPage.sounds => SoundsPage(controller: controller),
        AppPage.announcements => AnnouncementsPage(controller: controller),
        AppPage.notices => NoticesPage(controller: controller),
        AppPage.logs => LogsPage(controller: controller),
        AppPage.settings => SettingsPage(controller: controller, windowControls: windowControls),
        AppPage.pano => const SizedBox.shrink(),
      };
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.controller,
    required this.current,
    required this.gated,
    required this.onSelect,
    required this.onLock,
  });

  final AppController controller;
  final AppPage current;
  final Set<AppPage> gated;
  final ValueChanged<AppPage> onSelect;
  final VoidCallback onLock;

  static const _mainPages = [
    AppPage.home,
    AppPage.program,
    AppPage.calendar,
    AppPage.events,
    AppPage.sounds,
    AppPage.announcements,
    AppPage.notices,
    AppPage.logs,
    AppPage.settings,
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: controller, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    // Dar pencerede yalnızca simgeler görünür.
    final compact = MediaQuery.sizeOf(context).width < 1180;
    final unsavedSchedule = controller.scheduleDraft?.dirty ?? false;
    final locked = controller.isLockEnabled && controller.isLocked;
    return Container(
      width: compact ? 80 : 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.lineSoft)),
        boxShadow: [BoxShadow(color: Color(0x0814213D), blurRadius: 16, offset: Offset(2, 0))],
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 24),
      // Kısa pencerede (ör. 640 px, kilit düğmesi de varken) menü taşmasın: sığmazsa kayar,
      // sığarsa alt düğmeler en alta yaslanır.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: _items(context, compact, unsavedSchedule, locked)),
          ),
        ),
      ),
    );
  }

  Widget _items(BuildContext context, bool compact, bool unsavedSchedule, bool locked) {
    return Column(
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
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF9D66A), AppColors.recess],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x40F2C230), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: const Icon(Icons.notifications_rounded, color: AppColors.ink),
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
            locked: locked && gated.contains(page),
            onTap: () => onSelect(page),
          ),
          const SizedBox(height: 4),
        ],
        const Spacer(),
        if (controller.isLockEnabled && !locked) ...[
          _NavItem(
            page: AppPage.home,
            selected: false,
            compact: compact,
            outlined: true,
            label: 'Kilitle',
            icon: Icons.lock_outline,
            onTap: onLock,
          ),
          const SizedBox(height: 4),
        ],
        _NavItem(
          page: AppPage.pano,
          selected: false,
          compact: compact,
          outlined: true,
          label: 'Pano modunu aç',
          onTap: () => onSelect(AppPage.pano),
        ),
        const SizedBox(height: 8),
        // Şifre kilidinden bağımsız: geliştirici ve lisans bilgisi her zaman görülebilir.
        Tooltip(
          message: 'Hakkında',
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.inkSecondary, minimumSize: const Size(0, 36)),
            onPressed: () => showAboutAppDialog(context),
            child: compact
                ? const Icon(Icons.info_outline, size: 20)
                : const Text('Sürüm ${AppInfo.version} · Hakkında', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
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
    this.locked = false,
    this.label,
    this.icon,
  });

  final AppPage page;
  final bool selected;
  final bool compact;
  final bool outlined;

  /// Kaydedilmemiş değişiklik işareti.
  final bool badge;

  /// Şifre kilidi yüzünden önce şifre sorulacak.
  final bool locked;
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.lesson : (outlined ? AppColors.ink : AppColors.inkSecondary);
    final text = label ?? page.label;
    final semanticText = locked ? '$text (kilitli)' : (badge ? '$text (kaydedilmedi)' : text);
    final item = Material(
      color: selected ? AppColors.lessonTint : (outlined ? AppColors.ground : Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.ground,
        onTap: onTap,
        child: Container(
          height: 44,
          // Seçili sayfada solda vurgu çubuğu.
          decoration: selected && !compact
              ? const BoxDecoration(border: Border(left: BorderSide(color: AppColors.lesson, width: 3)))
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Badge(
                  isLabelVisible: badge && !locked,
                  smallSize: 9,
                  backgroundColor: AppColors.lunch,
                  child: Icon(icon ?? (selected ? page.selectedIcon : page.icon), size: 20, color: fg),
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
                if (locked) ...[
                  if (!compact) const SizedBox(width: 6),
                  Icon(Icons.lock, size: compact ? 12 : 15, color: AppColors.inkSecondary),
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
      label: compact || badge || locked ? semanticText : null,
      child: compact ? Tooltip(message: semanticText, child: item) : item,
    );
  }
}
