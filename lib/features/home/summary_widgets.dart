import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Section title with an optional green "Все" link on the right.
class SummarySection extends StatelessWidget {
  const SummarySection({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllLabel = 'Все',
    this.top = 28,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.heading)),
          if (onSeeAll != null)
            Pressable(
              onTap: onSeeAll,
              semanticLabel: '$seeAllLabel: $title',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  seeAllLabel,
                  style: AppText.label.copyWith(
                    color: AppColors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// White tile: value on top, label below, a small line icon in the corner.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.unit,
    this.muted = false,
  });

  final String value;
  final String? unit;
  final String label;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: value),
                      if (unit != null)
                        TextSpan(
                          text: ' $unit',
                          style: AppText.label.copyWith(color: AppColors.ink3),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.clock.copyWith(
                    fontSize: 24,
                    color: muted ? AppColors.ink4 : AppColors.ink,
                  ),
                ),
              ),
              Icon(icon, size: 20, color: AppColors.ink3),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}

/// Two tiles per row.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                SizedBox(width: gap),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// "Приход / Уход" with the green action on the right, as in the reference summary card.
class ClockCard extends StatelessWidget {
  const ClockCard({
    super.key,
    required this.arrived,
    required this.left,
    required this.actionLabel,
    required this.onAction,
  });

  final DateTime? arrived;
  final DateTime? left;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, DateTime? t) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(color: AppColors.ink3)),
        const SizedBox(height: 4),
        Text(
          t == null ? '– –' : Fmt.time(t),
          style: AppText.clock.copyWith(fontSize: 20),
        ),
      ],
    );
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(child: cell('Приход', arrived)),
          Expanded(child: cell('Уход', left)),
          if (actionLabel != null)
            PrimaryButton(
              label: actionLabel!,
              onTap: onAction,
              height: 44,
              expand: false,
            ),
        ],
      ),
    );
  }
}

class RequestCounters extends StatelessWidget {
  const RequestCounters({
    super.key,
    required this.total,
    required this.approved,
    required this.declined,
    this.onTap,
    this.loading = false,
  });

  final int total;
  final int approved;
  final int declined;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    Widget cell(int value, String label, Color color) => Expanded(
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            loading
                ? const Skeleton(height: 24, width: 28, radius: 6)
                : Text(
                    '$value',
                    style: AppText.clock.copyWith(fontSize: 22, color: color),
                  ),
            const SizedBox(height: 4),
            Text(label, style: AppText.label.copyWith(color: AppColors.ink3)),
          ],
        ),
      ),
    );
    return Row(
      children: [
        cell(total, 'Заявок', AppColors.green),
        const SizedBox(width: 10),
        cell(approved, 'Одобрено', AppColors.green),
        const SizedBox(width: 10),
        cell(
          declined,
          'Отклонено',
          declined > 0 ? AppColors.red : AppColors.green,
        ),
      ],
    );
  }
}

/// Task / checklist card for the two-column grid.
class SummaryTaskCard extends StatelessWidget {
  const SummaryTaskCard({
    super.key,
    required this.icon,
    required this.title,
    required this.pill,
    required this.pillTone,
    this.subtitle,
    this.progress,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String pill;
  final Tone pillTone;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppColors.ink2),
              const Spacer(),
              Flexible(
                child: StatusPill(null, label: pill, tone: pillTone),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle.copyWith(fontSize: 15),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(color: AppColors.ink3),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 5,
                backgroundColor: AppColors.chip,
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
              ),
            ),
            const SizedBox(height: 6),
            Text('${(progress! * 100).round()}%', style: AppText.caption),
          ],
        ],
      ),
    );
  }
}

/// One check-in in the recent list: round icon, type and date, time on the right.
class CheckinLogTile extends StatelessWidget {
  const CheckinLogTile({super.key, required this.log, this.workStart});

  final Json log;
  final (int, int)? workStart;

  @override
  Widget build(BuildContext context) {
    final isIn = log['log_type'] == 'IN';
    final time = Fmt.parse(log['time']);
    String? note;
    Color noteColor = AppColors.ink3;
    if (isIn && time != null && workStart != null) {
      final due = DateTime(
        time.year,
        time.month,
        time.day,
        workStart!.$1,
        workStart!.$2,
      );
      final diff = time.difference(due).inMinutes;
      if (diff > 0) {
        note = 'Опоздание $diff мин';
        noteColor = AppColors.amber;
      } else {
        note = diff == 0 ? 'Вовремя' : 'Раньше на ${-diff} мин';
        noteColor = AppColors.greenDeep;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isIn ? AppColors.greenSoft : AppColors.chip,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIn ? AppIcons.arrowDownLeft : AppIcons.arrowUpRight,
              size: 19,
              color: isIn ? AppColors.greenDeep : AppColors.ink2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isIn ? 'Приход' : 'Уход', style: AppText.bodyStrong),
                Text(
                  time == null ? '' : Fmt.long(time),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time == null ? '' : Fmt.time(time),
                style: AppText.number.copyWith(fontSize: 16),
              ),
              if (note != null)
                Text(note, style: AppText.caption.copyWith(color: noteColor)),
            ],
          ),
        ],
      ),
    );
  }
}
