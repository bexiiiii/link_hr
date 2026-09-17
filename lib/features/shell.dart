import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const _items = [
    (CupertinoIcons.house, CupertinoIcons.house_fill, 'Главная'),
    (CupertinoIcons.clock, CupertinoIcons.clock_fill, 'Посещаемость'),
    (CupertinoIcons.square_list, CupertinoIcons.square_list_fill, 'Задачи'),
    (CupertinoIcons.folder, CupertinoIcons.folder_fill, 'Сервисы'),
    (CupertinoIcons.gear, CupertinoIcons.gear_solid, 'Профиль и настройки'),
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ShellScope(
      goTo: _go,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            for (var i = 0; i < _items.length; i++)
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
              bottom: bottomInset > 0 ? bottomInset - 6 : 14,
              child: Center(
                child: _NavPill(items: _items, index: _index, onTap: _go),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating white pill with round icon buttons; the active tab is a filled green circle.
class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<(IconData, IconData, String)> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadow.float,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
              child: Semantics(
                button: true,
                selected: i == index,
                label: items[i].$3,
                child: Pressable(
                  onTap: () => onTap(i),
                  scale: 0.9,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutQuart,
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == index ? AppColors.blue : Colors.transparent,
                    ),
                    child: Icon(
                      i == index ? items[i].$2 : items[i].$1,
                      size: 23,
                      color: i == index ? Colors.white : AppColors.ink3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
