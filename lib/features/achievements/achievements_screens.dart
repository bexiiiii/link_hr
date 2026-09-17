import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_icons.dart';

import '../../core/fmt.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/checklists.dart';
import '../../data/score.dart';
import '../../data/tasks.dart';
import '../../data/timesheet.dart';

IconData achievementIcon(String id) => switch (id) {
  'first_step' => AppIcons.flagFill,
  'time_manager' => AppIcons.alarmFill,
  'early_bird' => AppIcons.sunriseFill,
  'task_closer' => AppIcons.checkmarkSealFill,
  'checklist_master' => AppIcons.listBulletIndent,
  'clean_month' => AppIcons.starFill,
  _ => AppIcons.rosette,
};

const _cardViolet = AppColors.blueSoft;

class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    this.compact = false,
  });

  final Achievement achievement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return SurfaceCard(
      radius: AppRadius.tile,
      color: a.unlocked ? _cardViolet : AppColors.surface,
      padding: const EdgeInsets.all(14),
      onTap: () => pushPage(context, AchievementDetailScreen(achievement: a)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Medal(id: a.id, unlocked: a.unlocked, size: compact ? 46 : 54),
          const SizedBox(height: 12),
          Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong.copyWith(fontSize: 13),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: a.ratio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutQuart,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: a.unlocked ? Colors.white : AppColors.chip,
                valueColor: const AlwaysStoppedAnimation(AppColors.plum),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            a.unlocked
                ? 'Получено ${Fmt.date(a.unlockedAt)}'
                : '${a.progress} из ${a.target}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.id, required this.unlocked, this.size = 54});

  final String id;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? Colors.white : AppColors.bg,
        border: Border.all(
          color: unlocked ? AppColors.plum : AppColors.chip,
          width: size * 0.07,
        ),
      ),
      child: Icon(
        achievementIcon(id),
        size: size * 0.44,
        color: unlocked ? AppColors.plum : AppColors.ink4,
      ),
    );
  }
}

Future<void> showAchievementDialog(BuildContext context, Achievement a) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (_, anim, _, child) {
      final t = CurvedAnimation(parent: anim, curve: Curves.easeOutQuart);
      return FadeTransition(
        opacity: t,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(t),
          child: child,
        ),
      );
    },
    pageBuilder: (c, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned.fill(child: Confetti()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(c),
                        icon: const Icon(AppIcons.xmark, color: AppColors.ink3),
                      ),
                    ),
                    Center(
                      child: Reveal(
                        scale: true,
                        child: SizedBox(
                          height: 170,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events_rounded,
                                size: 170,
                                color: AppColors.amber.withValues(alpha: 0.22),
                              ),
                              _Medal(id: a.id, unlocked: true, size: 104),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('${Fmt.date(a.unlockedAt)}', style: AppText.caption),
                    const SizedBox(height: 4),
                    Text(
                      'Достижение «${a.title}» получено',
                      style: AppText.title,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Поздравляем! ${a.description}',
                      style: AppText.body.copyWith(color: AppColors.ink2),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Ознакомлен',
                      onTap: () => Navigator.pop(c),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, this.initial});

  final List<Achievement>? initial;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late List<Achievement>? _items =
      widget.initial == null || widget.initial!.isEmpty ? null : widget.initial;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (_items == null) _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final me = Session.instance.userId;
      final r = await Future.wait<Object>([
        MonthSheet.loadRange(
          DateTime(now.year, 1),
          DateTime(now.year, now.month),
        ),
        Tasks.list(),
        Checklists.runs(from: DateTime(now.year, 1, 1), to: now, user: me),
      ]);
      if (mounted) {
        setState(
          () => _items = Achievements.compute(
            sheets: r[0] as List<MonthSheet>,
            tasks: r[1] as List<TaskItem>,
            runs: r[2] as List<ChecklistRun>,
            me: me,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final unlocked = items?.where((a) => a.unlocked).length ?? 0;
    return AppPage(
      header: const ScreenHeader(title: 'Мои достижения'),
      body: _error != null
          ? PageScroll(
              children: [ErrorState(error: _error!, onRetry: _load)],
            )
          : items == null
          ? PageScroll(children: const [SkeletonCards(count: 3, height: 180)])
          : CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _load),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Получено $unlocked из ${items.length}',
                      style: AppText.label.copyWith(color: AppColors.ink3),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 190,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => Reveal(
                      index: i,
                      scale: true,
                      child: AchievementCard(achievement: items[i]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class AchievementDetailScreen extends StatelessWidget {
  const AchievementDetailScreen({super.key, required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final percent = (a.ratio * 100).round();
    return AppPage(
      header: const ScreenHeader(title: 'Мои достижения'),
      body: Stack(
        children: [
          PageScroll(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Reveal(
                  scale: true,
                  child: Container(
                    width: 230,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                    decoration: BoxDecoration(
                      color: a.unlocked ? _cardViolet : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: a.unlocked
                            ? AppColors.plum.withValues(alpha: 0.4)
                            : AppColors.line,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          a.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppColors.plum,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _Medal(id: a.id, unlocked: a.unlocked, size: 96),
                        const SizedBox(height: 22),
                        AnimatedNumber(
                          value: percent,
                          suffix: '%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.plum,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: a.ratio),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutQuart,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 5,
                              backgroundColor: Colors.white,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.plum,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              if (a.unlocked)
                Text(
                  Fmt.long(a.unlockedAt),
                  textAlign: TextAlign.center,
                  style: AppText.label.copyWith(color: AppColors.ink3),
                ),
              const SizedBox(height: 6),
              Text(
                a.unlocked
                    ? 'Достижение разблокировано'
                    : 'Осталось ${a.target - a.progress} до цели',
                textAlign: TextAlign.center,
                style: AppText.display.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 10),
              Text(
                a.description,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: 20),
              if (a.unlocked)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleButton(
                      icon: AppIcons.share,
                      label: 'Поделиться достижением',
                      onTap: () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Я получил(а) достижение «${a.title}» в Link: ${a.description}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleButton(
                      icon: AppIcons.cameraCircle,
                      label: 'Поделиться в сторис',
                      foreground: AppColors.blue,
                      onTap: () => SharePlus.instance.share(
                        ShareParams(text: 'Достижение «${a.title}» в Link'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (a.unlocked) const Positioned.fill(child: Confetti(count: 80)),
        ],
      ),
    );
  }
}
