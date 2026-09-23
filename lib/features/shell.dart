import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_icons.dart';
import '../core/app_language.dart';

import '../core/premium.dart';
import '../core/motion.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'attendance/attendance_home.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'services/services_screen.dart';
import 'tasks/board_screen.dart';

class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.goTo, required super.child});

  final ValueChanged<int> goTo;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

abstract final class ShellTab {
  static const home = 0;
  static const attendance = 1;
  static const tasks = 2;
  static const services = 3;
  static const profile = 4;
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;
  final _visited = <int>{0};

  static const _icons = [
    (AppIcons.house, AppIcons.houseFill),
    (AppIcons.clock, AppIcons.clockFill),
    (AppIcons.squareList, AppIcons.squareListFill),
    (AppIcons.folder, AppIcons.folderFill),
    (AppIcons.gear, AppIcons.gearSolid),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      Session.instance.notifyDataChanged();
  }

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  Widget _tab(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    return switch (i) {
      ShellTab.home => const HomeScreen(),
      ShellTab.attendance => const AttendanceScreen(),
      ShellTab.tasks => const PremiumGate(
        feature: 'tasks',
        title: 'Задачи',
        showBack: false,
        child: BoardScreen(),
      ),
      ShellTab.services => const ServicesScreen(),
      _ => const ProfileScreen(showBack: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      goTo: _go,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            for (var i = 0; i < _icons.length; i++)
              Offstage(
                offstage: i != _index,
                child: TickerMode(
                  enabled: i == _index,
                  child: AnimatedOpacity(
                    opacity: i == _index ? 1 : 0,
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: _tab(i),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _NavPill(items: _icons, index: _index, onTap: _go),
            ),
          ],
        ),
      ),
    );
  }
}

/// A clear, full-width iOS bottom bar. Icons and labels stay together so users
/// never have to memorise five unlabeled symbols.
class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<(IconData, IconData)> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset > 0 ? bottomInset : 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: _label(i),
                child: Pressable(
                  onTap: () => onTap(i),
                  scale: 0.9,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutQuart,
                    padding: const EdgeInsets.only(top: 0, bottom: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: i == index ? 28 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Icon(
                          i == index ? items[i].$2 : items[i].$1,
                          size: 22,
                          color: i == index ? AppColors.ink : AppColors.ink3,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          switch (i) {
                            0 => tx('Главная', 'Басты'),
                            1 => tx('Часы', 'Уақыт'),
                            2 => tx('Задачи', 'Тапсырма'),
                            3 => tx('Ещё', 'Тағы'),
                            _ => tx('Профиль', 'Профиль'),
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            fontSize: 10,
                            color: i == index ? AppColors.ink : AppColors.ink3,
                            fontWeight: i == index
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(int i) => switch (i) {
    0 => tx('Главная', 'Басты'),
    1 => tx('Посещаемость', 'Қатысу'),
    2 => tx('Задачи', 'Тапсырмалар'),
    3 => tx('Сервисы', 'Қызметтер'),
    _ => tx('Профиль и настройки', 'Профиль және баптаулар'),
  };
}
