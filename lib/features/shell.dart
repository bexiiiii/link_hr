import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/premium.dart';
import '../core/motion.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/notices.dart';
import 'home/home_screen.dart';
import 'notices/notices_screens.dart';
import 'profile/profile_screen.dart';
import 'services/services_screen.dart';
import 'tasks/board_screen.dart';

class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.goTo, required super.child});

  final ValueChanged<int> goTo;

  static ShellScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

abstract final class ShellTab {
  static const home = 0;
  static const tasks = 1;
  static const services = 2;
  static const inbox = 3;
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
  int _unread = 0;

  static const _items = [
    (CupertinoIcons.house_fill, 'Главная'),
    (CupertinoIcons.square_split_2x2_fill, 'Доска'),
    (CupertinoIcons.circle_grid_hex_fill, 'Сервисы'),
    (CupertinoIcons.chat_bubble_text_fill, 'Оповещения'),
    (CupertinoIcons.person_fill, 'Профиль'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Session.instance.dataVersion.addListener(_countUnread);
    _countUnread();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Session.instance.dataVersion.removeListener(_countUnread);
    super.dispose();
  }

  Future<void> _countUnread() async {
    try {
      final n = (await Notices.mine(unreadOnly: true)).length;
      if (mounted) setState(() => _unread = n);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Session.instance.notifyDataChanged();
  }

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  Widget _tab(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    return switch (i) {
      ShellTab.home => const HomeScreen(),
      ShellTab.tasks => const PremiumGate(feature: 'tasks', title: 'Доска', showBack: false, child: BoardScreen()),
      ShellTab.services => const ServicesScreen(),
      ShellTab.inbox => const NoticesScreen(showBack: false),
      _ => const ProfileScreen(showBack: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return ShellScope(
      goTo: _go,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(children: [
          for (var i = 0; i < _items.length; i++)
            Offstage(
              offstage: i != _index,
              child: TickerMode(
                enabled: i == _index,
                child: AnimatedOpacity(
                  opacity: i == _index ? 1 : 0,
                  duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 180),
                  child: _tab(i),
                ),
              ),
            ),
        ]),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: Pressable(
                      onTap: () => _go(i),
                      scale: 0.88,
                      semanticLabel: _items[i].$2,
                      child: Center(
                        heightFactor: 1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutQuart,
                          width: 52,
                          height: 38,
                          decoration: BoxDecoration(
                            color: i == _index ? AppColors.bg : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(alignment: Alignment.center, children: [
                            if (i == ShellTab.profile)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: i == _index ? AppColors.charcoal : Colors.transparent, width: 1.5),
                                ),
                                child: AppAvatar(name: s.fullName, imageUrl: s.image, size: 26, border: false),
                              )
                            else
                              AnimatedScale(
                                scale: i == _index ? 1.08 : 1,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutQuart,
                                child: Icon(_items[i].$1, size: 22, color: i == _index ? AppColors.charcoal : AppColors.ink3),
                              ),
                            if (i == ShellTab.inbox && _unread > 0)
                              Positioned(
                                top: 7,
                                right: 13,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: AppColors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.surface, width: 1.5),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
