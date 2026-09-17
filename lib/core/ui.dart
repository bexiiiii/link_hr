import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'fmt.dart';
import 'theme.dart';

Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(CupertinoPageRoute(builder: (_) => page));

String errorText(Object error) =>
    error is ApiException ? error.message : 'Что-то пошло не так. Попробуйте ещё раз.';

void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  if (error) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.lightImpact();
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.charcoal,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: Duration(milliseconds: error ? 4200 : 2600),
      content: Row(children: [
        Icon(error ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.checkmark_circle_fill,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ]),
    ));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (c) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Padding(padding: const EdgeInsets.only(top: 6), child: Text(message)),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class SheetAction {
  const SheetAction(this.value, this.label, {this.destructive = false});
  final String value;
  final String label;
  final bool destructive;
}

Future<String?> pickAction(BuildContext context, {String? title, required List<SheetAction> actions}) {
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (c) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      actions: [
        for (final a in actions)
          CupertinoActionSheetAction(
            isDestructiveAction: a.destructive,
            onPressed: () => Navigator.pop(c, a.value),
            child: Text(a.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(c),
        child: const Text('Отмена'),
      ),
    ),
  );
}

/// Press feedback shared by every tappable surface: a short, ease-out scale.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return Semantics(label: widget.semanticLabel, child: widget.child);
    }
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutQuart,
          child: widget.child,
        ),
      ),
    );
  }
}

class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.badge = false,
    this.size = 40,
    this.background = AppColors.surface,
    this.foreground = AppColors.ink,
    this.iconSize = 19,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool badge;
  final double size;
  final Color background;
  final Color foreground;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      semanticLabel: label,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                boxShadow: background == AppColors.surface ? AppShadow.card : null,
              ),
              child: Icon(icon, size: iconSize, color: foreground),
            ),
          ),
          if (badge)
            Positioned(
              top: size * 0.24,
              right: size * 0.26,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: background, width: 1.5),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.card,
    this.color = AppColors.surface,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: color == AppColors.surface ? AppShadow.card : null,
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.985, child: card);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label, this.tone});

  final String? status;
  final String? label;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? toneForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        label ?? statusLabel(status),
        maxLines: 1,
        style: TextStyle(fontFamily: kFont, fontSize: 12, height: 1.2, fontWeight: FontWeight.w500, color: t.ink),
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label, this.bold = false});

  final Color color;
  final String label;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: AppText.caption.copyWith(
            color: bold ? AppColors.ink : AppColors.ink3,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          )),
    ]);
  }
}

/// Filter pill with a leading count bubble, as in the reference's
/// "(2) Completed / (5) In Progress / (8) On Hold" row.
class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.tone = Tone.green,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: '$label, $count',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutQuart,
        height: 38,
        padding: const EdgeInsets.only(left: 6, right: 14),
        decoration: BoxDecoration(
          color: selected ? tone.solid : AppColors.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : AppColors.chipDot,
              shape: BoxShape.circle,
            ),
            child: Text('$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? tone.solid : Colors.white,
                )),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.ink3,
              )),
        ]),
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.imageUrl, this.size = 36, this.border = true});

  final String name;
  final String? imageUrl;
  final double size;
  final bool border;

  static const _palette = [Color(0xFFEFF0F2)];

  static String initials(String name) {
    final base = name.contains('@') ? name.split('@').first.replaceAll(RegExp(r'[._-]'), ' ') : name;
    final parts = base.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
    return letters;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _palette[name.hashCode.abs() % _palette.length];
    final fallback = Center(
      child: Text(initials(name),
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w500,
            color: AppColors.ink3,
            letterSpacing: 0.2,
          )),
    );
    final url = Api.instance.fileUrl(imageUrl);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: border ? Border.all(color: Colors.white, width: 2) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              headers: Api.instance.authHeaders,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class Person {
  const Person(this.name, [this.image]);
  final String name;
  final String? image;
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.people, this.max = 3, this.size = 30});

  final List<Person> people;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final shown = people.take(max).toList();
    final step = size * 0.66;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: size + step * (shown.length - 1),
        height: size,
        child: Stack(children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(left: step * i, child: AppAvatar(name: shown[i].name, imageUrl: shown[i].image, size: size)),
        ]),
      ),
      if (people.length > max) ...[
        const SizedBox(width: 8),
        Text('${people.length - max}+', style: AppText.bodyStrong.copyWith(color: AppColors.ink2)),
      ],
    ]);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.topGap = 22});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 10),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.heading)),
        if (actionLabel != null)
          Pressable(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(actionLabel!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.violet)),
            ),
          ),
      ]),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.showBack = true, this.actions = const []});

  final String title;
  final bool showBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (!showBack) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Row(children: [
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 26))),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ]),
      );
    }
    final side = actions.length <= 1 ? 64.0 : 16.0 + 52.0 * actions.length;
    return SizedBox(
      height: 64,
      child: Row(children: [
        SizedBox(
          width: side,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CircleButton(
                icon: CupertinoIcons.chevron_left,
                label: 'Назад',
                size: 44,
                iconSize: 18,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.heading.copyWith(fontWeight: FontWeight.w500, fontSize: 19)),
        ),
        SizedBox(
          width: side,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            for (final a in actions) Padding(padding: const EdgeInsets.only(right: 16), child: a),
          ]),
        ),
      ]),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({super.key, this.header, required this.body, this.bottom});

  final Widget? header;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: bottom == null,
        child: Column(children: [
          ?header,
          Expanded(child: body),
        ]),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : Container(
              color: AppColors.bg,
              child: SafeArea(
                top: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 12), child: bottom),
              ),
            ),
    );
  }
}

class PageScroll extends StatelessWidget {
  const PageScroll({
    super.key,
    required this.children,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 120),
    this.controller,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
        SliverPadding(padding: padding, sliver: SliverList(delegate: SliverChildListDelegate(children))),
      ],
    );
  }
}

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width = double.infinity, required this.height, this.radius = 14});

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(widget.radius)),
    );
    if (MediaQuery.of(context).disableAnimations) return box;
    return FadeTransition(opacity: Tween(begin: 0.45, end: 1.0).animate(_c), child: box);
  }
}

class SkeletonCards extends StatelessWidget {
  const SkeletonCards({super.key, this.count = 3, this.height = 104});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < count; i++) ...[
        Skeleton(height: height, radius: AppRadius.card),
        if (i < count - 1) const SizedBox(height: 12),
      ],
    ]);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(children: [
        Icon(icon, color: AppColors.ink4, size: 34),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: AppText.cardTitle),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center, style: AppText.label.copyWith(color: AppColors.ink3)),
        if (actionLabel != null) ...[
          const SizedBox(height: 18),
          PrimaryButton(label: actionLabel!, onTap: onAction, height: 44, expand: false, kind: ButtonKind.outline),
        ],
      ]),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: CupertinoIcons.wifi_exclamationmark,
      title: 'Не удалось загрузить',
      message: errorText(error),
      actionLabel: 'Повторить',
      onAction: onRetry,
    );
  }
}

enum ButtonKind { dark, violet, green, danger, soft, outline }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.kind = ButtonKind.dark,
    this.loading = false,
    this.height = 48,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final ButtonKind kind;
  final bool loading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      ButtonKind.dark => (AppColors.green, Colors.white),
      ButtonKind.violet => (AppColors.green, Colors.white),
      ButtonKind.green => (AppColors.green, Colors.white),
      ButtonKind.danger => (AppColors.redSoft, const Color(0xFFB83636)),
      ButtonKind.soft => (AppColors.greenSoft, AppColors.greenDeep),
      ButtonKind.outline => (AppColors.surface, AppColors.green),
    };
    final disabled = onTap == null && !loading;
    return Pressable(
      onTap: loading ? null : onTap,
      semanticLabel: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: disabled ? 0.45 : 1,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: kind == ButtonKind.outline ? Border.all(color: AppColors.green, width: 1.2) : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                CupertinoActivityIndicator(color: fg)
              else ...[
                if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: kFont, fontSize: height >= 46 ? 15 : 14, fontWeight: FontWeight.w500, color: fg)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, this.value, this.child, this.trailing, this.onTap});

  final String label;
  final String? value;
  final Widget? child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 5),
            child ?? Text(value ?? '—', style: AppText.bodyStrong),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ]),
    );
    return onTap == null ? row : Pressable(onTap: onTap, scale: 0.99, child: row);
  }
}

class Divided extends StatelessWidget {
  const Divided({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[
        children[i],
        if (i < children.length - 1) const Divider(height: 1),
      ],
    ]);
  }
}

class FieldRows extends StatelessWidget {
  const FieldRows({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.$2.trim().isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Divided(children: [
        for (final r in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: Text(r.$1, style: AppText.label.copyWith(color: AppColors.ink3))),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Text(r.$2, textAlign: TextAlign.right, style: AppText.bodyStrong),
              ),
            ]),
          ),
      ]),
    );
  }
}

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({super.key, required this.name, required this.meta, this.onTap, this.onDelete});

  final String name;
  final String meta;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot + 1).toUpperCase() : 'FILE';
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: 'Открыть $name',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.violet, shape: BoxShape.circle),
            child: Text(ext.length > 4 ? ext.substring(0, 4) : ext,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
              const SizedBox(height: 2),
              Text(meta, style: AppText.caption),
            ]),
          ),
          if (onDelete != null)
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(40, 40),
              onPressed: onDelete,
              child: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.ink4, size: 22),
            ),
        ]),
      ),
    );
  }
}

class SegmentTabs extends StatelessWidget {
  const SegmentTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: index,
        backgroundColor: AppColors.chip,
        thumbColor: AppColors.surface,
        padding: const EdgeInsets.all(4),
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
        children: {
          for (var i = 0; i < labels.length; i++)
            i: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                    color: i == index ? AppColors.ink : AppColors.ink3,
                  )),
            ),
        },
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.tone = Tone.neutral, this.size = 38});

  final IconData icon;
  final Tone tone;
  final double size;

  /// Plain line icon in a fixed box. Coloured only when the tone carries
  /// meaning (success, danger, warning); decorative pastel circles are gone.
  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      Tone.green => AppColors.greenDeep,
      Tone.red => AppColors.red,
      Tone.amber => AppColors.amber,
      _ => AppColors.ink,
    };
    return SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.6, color: color));
  }
}

class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(CupertinoIcons.exclamationmark_circle_fill, color: AppColors.red, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFA9362D))),
        ),
      ]),
    );
  }
}

/// Diagonal hatching used for calendar cells outside the current month.
class HatchedCircle extends StatelessWidget {
  const HatchedCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _HatchPainter());
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFFF1F1F4));
    final line = Paint()
      ..color = const Color(0xFFDADAE2)
      ..strokeWidth = 1.2;
    for (double x = -size.width; x < size.width * 2; x += 5) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SemicircleGauge extends StatelessWidget {
  const SemicircleGauge({super.key, required this.value, required this.color, this.size = 96});

  final double value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutQuart,
      builder: (_, v, _) => CustomPaint(size: Size(size, size / 2 + 6), painter: _GaugePainter(v, color)),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value, this.color);

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.width - stroke);
    final track = Paint()
      ..color = AppColors.chip
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, track);
    if (value > 0) {
      canvas.drawArc(rect, math.pi, math.pi * value, false, track..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value || old.color != color;
}

class MonthDaysLabel extends StatelessWidget {
  const MonthDaysLabel({super.key, required this.from, required this.to});

  final Object? from;
  final Object? to;

  @override
  Widget build(BuildContext context) => Text(Fmt.range(from, to), style: AppText.caption);
}
