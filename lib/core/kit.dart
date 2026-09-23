import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_icons.dart';

import 'forms.dart';
import 'fmt.dart';
import 'theme.dart';
import 'ui.dart';

/// Uppercase text tabs with a graphite underline under the active label.
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < labels.length; i++)
              Pressable(
                onTap: () => onChanged(i),
                scale: 0.96,
                semanticLabel: labels[i],
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == labels.length - 1 ? 0 : 24,
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 0.2,
                              fontWeight: FontWeight.w500,
                              color: i == index
                                  ? AppColors.ink
                                  : AppColors.ink3,
                            ),
                            child: Text(labels[i].toUpperCase()),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutQuart,
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == index
                                ? AppColors.charcoal
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small outlined pill with a chevron, the reference's "February ▾".
class DropdownPill extends StatelessWidget {
  const DropdownPill({
    super.key,
    required this.label,
    required this.onTap,
    this.prefix,
  });

  final String label;
  final String? prefix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix != null) ...[
          Text(prefix!, style: AppText.label),
          const SizedBox(width: 8),
        ],
        Pressable(
          onTap: onTap,
          semanticLabel: '${prefix ?? ''} $label',
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  AppIcons.chevronDown,
                  size: 13,
                  color: AppColors.ink2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MonthYearPicker extends StatelessWidget {
  const MonthYearPicker({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownPill(
          prefix: 'Год',
          label: '${month.year}',
          onTap: () async {
            final picked = await showSelectSheet(
              context,
              title: 'Год',
              options: [
                for (var y = now.year; y >= now.year - 4; y--)
                  SelectOption('$y', '$y'),
              ],
              selected: '${month.year}',
            );
            if (picked == null) return;
            final y = int.parse(picked);
            var m = month.month;
            if (y == now.year && m > now.month) m = now.month;
            onChanged(DateTime(y, m));
          },
        ),
        DropdownPill(
          prefix: 'Месяц',
          label: Fmt.month(month),
          onTap: () async {
            final last = month.year == now.year ? now.month : 12;
            final picked = await showSelectSheet(
              context,
              title: 'Месяц',
              options: [
                for (var m = last; m >= 1; m--)
                  SelectOption('$m', Fmt.month(DateTime(month.year, m))),
              ],
              selected: '${month.month}',
            );
            if (picked != null)
              onChanged(DateTime(month.year, int.parse(picked)));
          },
        ),
      ],
    );
  }
}

/// Outlined status chip with a leading icon, used for legends and filters.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tone == Tone.neutral ? AppColors.ink2 : tone.ink;
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.charcoal : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? chip
        : Pressable(onTap: onTap, semanticLabel: label, child: chip);
  }
}

/// Three figures split by hairlines: "Присутствие | Отсутствие | Опоздание".
class KpiStrip extends StatelessWidget {
  const KpiStrip({super.key, required this.items, this.loading = false});

  final List<(String, String)> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.line,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(i == 0 ? 4 : 16, 4, 6, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].$1,
                      style: AppText.label.copyWith(color: AppColors.ink3),
                    ),
                    const SizedBox(height: 4),
                    loading
                        ? const Skeleton(height: 22, width: 44, radius: 8)
                        : Text(
                            items[i].$2,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w400,
                              color: AppColors.ink,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = Tone.violet,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Tone tone;
  final VoidCallback onTap;
  final Widget? trailing;

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
            IconBadge(icon: icon, tone: tone, size: 36),
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
            ?trailing,
            const SizedBox(width: 6),
            const Icon(AppIcons.chevronRight, size: 16, color: AppColors.ink4),
          ],
        ),
      ),
    );
  }
}

class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
    child: Text(text, style: AppText.sectionTitle),
  );
}
