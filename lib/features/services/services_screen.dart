import 'package:flutter/cupertino.dart';

import '../../core/premium.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../achievements/achievements_screens.dart';
import '../analysis/analysis_screen.dart';
import '../attendance/checkin_history_screen.dart';
import '../checklists/checklists_screens.dart';
import '../documents/documents_screen.dart';
import '../finance/finance_screen.dart';
import '../finance/salary_slips_screen.dart';
import '../leave/leave_screen.dart';
import '../notices/notices_screens.dart';
import '../payroll/payroll_screens.dart';
import '../requests/requests_screen.dart';
import '../search/search_screen.dart';
import '../shell.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String?, VoidCallback)>[
      (
        CupertinoIcons.square_split_2x2_fill,
        'Доска',
        null,
        () => ShellScope.maybeOf(context)?.goTo(ShellTab.tasks),
      ),
      (
        CupertinoIcons.list_bullet_indent,
        'Чеклисты',
        null,
        () => pushPage(
          context,
          const PremiumGate(
            feature: 'checklists',
            title: 'Чеклисты',
            child: ChecklistsScreen(),
          ),
        ),
      ),
      (
        CupertinoIcons.alarm,
        'Link Time',
        'История приходов и уходов',
        () => pushPage(context, const CheckinHistoryScreen()),
      ),
      (
        CupertinoIcons.money_dollar_circle,
        isManager() ? 'Подсчёт ЗП' : 'Подсчёт',
        isManager()
            ? 'Зарплата сотрудников за месяц'
            : 'Расчётные листки и налоги',
        () => pushPage(
          context,
          isManager()
              ? const PremiumGate(
                  feature: 'payroll_calc',
                  title: 'Подсчёт ЗП',
                  child: PayrollScreen(),
                )
              : const SalarySlipsScreen(),
        ),
      ),
      (
        CupertinoIcons.folder,
        'Документы',
        isManager() ? 'Договоры, приказы и подписи' : 'Мои договоры и приказы',
        () => pushPage(context, const DocumentsScreen()),
      ),
      if (isManager())
        (
          CupertinoIcons.speaker_2,
          'Оповещение',
          null,
          () => pushPage(
            context,
            const PremiumGate(
              feature: 'notices',
              title: 'Оповещение',
              child: NoticeFormScreen(),
            ),
          ),
        ),
      if (isManager())
        (
          CupertinoIcons.chart_pie,
          'Анализ',
          'Дисциплина сотрудников',
          () => pushPage(
            context,
            const PremiumGate(
              feature: 'analysis',
              title: 'Анализ',
              child: AnalysisScreen(),
            ),
          ),
        ),
      (
        CupertinoIcons.rosette,
        'Достижения',
        null,
        () => pushPage(
          context,
          const PremiumGate(
            feature: 'achievements',
            title: 'Достижения',
            child: AchievementsScreen(),
          ),
        ),
      ),
      (
        CupertinoIcons.airplane,
        'Отпуска',
        null,
        () => pushPage(context, const LeaveScreen(showBack: true)),
      ),
      (
        CupertinoIcons.tray_arrow_up,
        'Запросы',
        'Отпуск, смены, отметки',
        () => pushPage(context, const RequestsScreen()),
      ),
      (
        CupertinoIcons.creditcard,
        'Расходы и авансы',
        null,
        () => pushPage(context, const FinanceScreen(showBack: true)),
      ),
    ];
    return AppPage(
      header: ScreenHeader(
        title: 'Сервисы',
        showBack: false,
        actions: [
          CircleButton(
            icon: CupertinoIcons.search,
            label: 'Поиск',
            onTap: () => pushPage(context, const SearchScreen()),
          ),
        ],
      ),
      body: PageScroll(
        children: [
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divided(
              children: [
                for (final (icon, title, subtitle, onTap) in items)
                  _ServiceRow(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    onTap: onTap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.blue),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.bodyStrong),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.ink4,
            ),
          ],
        ),
      ),
    );
  }
}
