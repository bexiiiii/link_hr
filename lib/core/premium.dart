import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'session.dart';
import 'theme.dart';
import 'ui.dart';

/// Wraps a Premium-only screen. On Basic it explains the limit instead of the content.
class PremiumGate extends StatelessWidget {
  const PremiumGate({super.key, required this.feature, required this.title, required this.child, this.showBack = true});

  final String feature;
  final String title;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    if (Session.instance.hasFeature(feature)) return child;
    return AppPage(
      header: ScreenHeader(title: title, showBack: showBack),
      body: PageScroll(children: [PremiumNotice(title: title)]),
    );
  }
}

class PremiumNotice extends StatelessWidget {
  const PremiumNotice({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: CupertinoIcons.lock,
      title: '«$title» доступно в тарифе Premium',
      message: Session.instance.isManager
          ? 'Ваша компания на тарифе Basic. Чтобы открыть этот раздел, перейдите на Premium: напишите нам, и мы подключим за один день.'
          : 'Ваша компания на тарифе Basic. Чтобы открыть этот раздел, обратитесь в отдел кадров.',
    );
  }
}

/// Thin strip on the home screen when the subscription ends soon or has ended.
class PlanBanner extends StatelessWidget {
  const PlanBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final days = s.planDaysLeft;
    if (days == null || days > 14) return const SizedBox.shrink();
    final expired = s.planExpired || days < 0;
    final text = expired
        ? (s.planExpired
            ? 'Подписка компании закончилась. Данные доступны только для просмотра.'
            : 'Подписка компании закончилась. Изменения заблокируются через ${3 + days} дн.')
        : 'Подписка компании заканчивается через $days дн.';
    final color = expired ? AppColors.red : AppColors.amber;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: expired ? AppColors.redSoft : AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(children: [
        Icon(CupertinoIcons.exclamationmark_circle, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.label.copyWith(color: AppColors.ink))),
      ]),
    );
  }
}
