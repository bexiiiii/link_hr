import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/premium.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/media.dart';
import '../../core/motion.dart';
import '../../core/people.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/notices.dart';
import '../notifications/notifications_screen.dart';

Future<void> showNoticeDialog(BuildContext context, Notice n, Map<String, PersonInfo> people) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, a, _, child) {
      final t = CurvedAnimation(parent: a, curve: Curves.easeOutQuart);
      return FadeTransition(opacity: t, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(t), child: child));
    },
    pageBuilder: (c, _, _) => _NoticeCard(notice: n, from: People.resolve(people, n.from)),
  );
}

class _NoticeCard extends StatefulWidget {
  const _NoticeCard({required this.notice, required this.from});

  final Notice notice;
  final PersonInfo from;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const IconBadge(icon: CupertinoIcons.speaker_2_fill, tone: Tone.violet, size: 56),
                const Spacer(),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.xmark, color: AppColors.ink3),
                ),
              ]),
              const SizedBox(height: 16),
              Text('${Fmt.date(n.created)} ${Fmt.time(n.created)} · ${widget.from.name}', style: AppText.caption),
              const SizedBox(height: 6),
              Text(n.title, style: AppText.title),
              if (n.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                  child: SingleChildScrollView(child: Text(n.body, style: AppText.body.copyWith(color: AppColors.ink2))),
                ),
              ],
              const SizedBox(height: 22),
              PrimaryButton(
                label: n.read ? 'Закрыть' : 'Ознакомлен',
                loading: _busy,
                onTap: () async {
                  if (n.read) return Navigator.pop(context);
                  setState(() => _busy = true);
                  try {
                    await Notices.acknowledge(n.name);
                    n.read = true;
                    Session.instance.notifyDataChanged();
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) showToast(context, errorText(e), error: true);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List<Notice>? _items;
  Map<String, PersonInfo> _people = {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    Session.instance.dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    Session.instance.dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait<Object>([Notices.mine(), People.byUser()]);
      if (mounted) {
        setState(() {
          _items = (r[0] as List<Notice>).where((n) => n.date == null || !n.date!.isAfter(DateTime.now())).toList();
          _people = r[1] as Map<String, PersonInfo>;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: ScreenHeader(title: 'Оповещения', showBack: widget.showBack, actions: [
        if (Session.instance.isManager) CircleButton(
          icon: CupertinoIcons.add,
          label: 'Новое оповещение',
          onTap: () => pushPage(
              context, const PremiumGate(feature: 'notices', title: 'Оповещение', child: NoticeFormScreen())),
        ),
      ]),
      body: PageScroll(onRefresh: _load, children: [
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Divided(children: [
            _navRow(CupertinoIcons.bell, 'Уведомления HR', 'Согласования, заявки и статусы',
                () => pushPage(context, const NotificationsScreen())),
          ]),
        ),
        const SizedBox(height: 18),
        if (_error != null)
          ErrorState(error: _error!, onRetry: _load)
        else if (_items == null)
          const SkeletonCards(count: 3, height: 90)
        else if (_items!.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.speaker_2,
            title: 'Оповещений нет',
            message: 'Объявления руководителей и HR появятся здесь и всплывут на главном экране.',
          )
        else
          for (final (i, n) in _items!.indexed)
            Reveal(
              index: i.clamp(0, 10),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  radius: AppRadius.tile,
                  padding: const EdgeInsets.all(16),
                  onTap: () => showNoticeDialog(context, n, _people).then((_) => setState(() {})),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      const IconBadge(icon: CupertinoIcons.speaker_2_fill, tone: Tone.violet),
                      if (!n.read)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: AppText.bodyStrong.copyWith(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                        if (n.body.isNotEmpty)
                          Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.label),
                        const SizedBox(height: 4),
                        Text('${People.resolve(_people, n.from).name} · ${Fmt.relative(n.created)}', style: AppText.caption),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
      ]),
    );
  }

  Widget _navRow(IconData icon, String title, String subtitle, VoidCallback onTap) => Pressable(
        onTap: onTap,
        scale: 0.99,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            IconBadge(icon: icon, tone: Tone.dark, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.bodyStrong),
                Text(subtitle, style: AppText.caption),
              ]),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.ink4),
          ]),
        ),
      );
}

class NoticeFormScreen extends StatefulWidget {
  const NoticeFormScreen({super.key});

  @override
  State<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends State<NoticeFormScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final List<PendingFile> _files = [];
  DateTime _when = DateTime.now();
  final Set<String> _picked = {};
  final Set<String> _openDepartments = {};
  List<PersonInfo> _people = [];
  bool _loadingPeople = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    People.all().then((p) {
      if (mounted) {
        setState(() {
          _people = p.where((x) => x.userId != Session.instance.userId).toList();
          _loadingPeople = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loadingPeople = false);
    });
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    var temp = _when;
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (c) => Container(
        height: 320,
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Row(children: [
              CupertinoButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
              const Spacer(),
              CupertinoButton(
                onPressed: () => Navigator.pop(c, temp),
                child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                use24hFormat: true,
                minimumDate: DateTime.now().subtract(const Duration(minutes: 5)),
                initialDateTime: _when,
                onDateTimeChanged: (d) => temp = d,
              ),
            ),
          ]),
        ),
      ),
    );
    if (picked != null) setState(() => _when = picked);
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.length < 5 || title.length > 50) {
      setState(() => _error = 'Заголовок должен быть от 5 до 50 символов');
      return;
    }
    if (_picked.isEmpty) {
      setState(() => _error = 'Выберите получателей');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = await Notices.send(title: title, body: _body.text, recipients: _picked.toList(), when: _when, files: _files);
      Session.instance.notifyDataChanged();
      if (mounted) {
        showToast(context, 'Оповещение отправлено: $n ${Fmt.plural(n, 'получатель', 'получателя', 'получателей')}');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _people.isNotEmpty && _people.every((p) => _picked.contains(p.userId));
    final byDepartment = <String, List<PersonInfo>>{};
    for (final p in _people) {
      byDepartment.putIfAbsent(p.department.isEmpty ? 'Без отдела' : p.department, () => []).add(p);
    }
    final frequent = _people.take(6).toList();
    final len = _title.text.trim().length;

    return AppPage(
      header: const ScreenHeader(title: 'Оповещение'),
      bottom: PrimaryButton(
        label: _picked.isEmpty ? 'Отправить' : 'Отправить · ${_picked.length}',
        loading: _busy,
        onTap: _send,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PageScroll(children: [
          Text('Отправьте оповещение в виде карточки и уведомления',
              style: AppText.label.copyWith(color: AppColors.ink3)),
          const SizedBox(height: 22),
          const FieldLabel('Заголовок', required: true),
          TextField(
            controller: _title,
            maxLength: 50,
            style: AppText.body,
            decoration: fieldDecoration().copyWith(counterText: ''),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text('Ограничение от 5 до 50 символов · $len',
                style: AppText.caption.copyWith(color: len > 0 && len < 5 ? AppColors.red : AppColors.ink3)),
          ),
          const FormGap(),
          const FieldLabel('Описание'),
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 8,
            style: AppText.body,
            decoration: fieldDecoration(hint: 'Введите описание и детали оповещения'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text('Неограниченное количество символов', style: AppText.caption),
          ),
          const FormGap(),
          const FieldLabel('Прикрепить'),
          for (final f in _files) AttachmentTile(name: f.name, meta: f.meta, onDelete: () => setState(() => _files.remove(f))),
          DashedBox(
            onTap: () async {
              final f = await pickAttachment(context);
              if (f != null) setState(() => _files.add(f));
            },
            child: const Text('Файл или фото', style: TextStyle(fontSize: 15, color: AppColors.ink3)),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            radius: AppRadius.field,
            onTap: _pickWhen,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
              Expanded(child: Text('${Fmt.long(_when)}, ${Fmt.time(_when)}', style: AppText.body)),
              const Icon(CupertinoIcons.calendar, color: AppColors.ink),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Часто взаимодействующие сотрудники', style: AppText.bodyStrong),
          const SizedBox(height: 10),
          if (_loadingPeople)
            const Skeleton(height: 80, radius: 16)
          else
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final (i, p) in frequent.indexed)
                    Reveal(
                      index: i,
                      scale: true,
                      child: Pressable(
                        onTap: () => setState(() => _picked.contains(p.userId) ? _picked.remove(p.userId) : _picked.add(p.userId)),
                        semanticLabel: p.name,
                        child: SizedBox(
                          width: 78,
                          child: Column(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _picked.contains(p.userId) ? AppColors.violet : Colors.transparent, width: 2),
                              ),
                              child: AppAvatar(name: p.name, imageUrl: p.image, size: 54, border: false),
                            ),
                            const SizedBox(height: 4),
                            Text(p.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _CheckRow(
            value: all ? true : (_picked.isEmpty ? false : null),
            title: 'Всем',
            subtitle: 'Всем сотрудникам компании',
            onTap: () => setState(() => all ? _picked.clear() : _picked.addAll(_people.map((p) => p.userId))),
          ),
          for (final entry in byDepartment.entries) ...[
            _CheckRow(
              value: entry.value.every((p) => _picked.contains(p.userId))
                  ? true
                  : (entry.value.any((p) => _picked.contains(p.userId)) ? null : false),
              title: entry.key,
              subtitle: '${entry.value.length} ${Fmt.plural(entry.value.length, 'сотрудник', 'сотрудника', 'сотрудников')}',
              expanded: _openDepartments.contains(entry.key),
              onExpand: () => setState(() =>
                  _openDepartments.contains(entry.key) ? _openDepartments.remove(entry.key) : _openDepartments.add(entry.key)),
              onTap: () => setState(() {
                final allIn = entry.value.every((p) => _picked.contains(p.userId));
                for (final p in entry.value) {
                  allIn ? _picked.remove(p.userId) : _picked.add(p.userId);
                }
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutQuart,
              child: !_openDepartments.contains(entry.key)
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: Column(children: [
                        for (final p in entry.value)
                          _CheckRow(
                            value: _picked.contains(p.userId),
                            title: p.name,
                            subtitle: p.role,
                            onTap: () => setState(() => _picked.contains(p.userId) ? _picked.remove(p.userId) : _picked.add(p.userId)),
                          ),
                      ]),
                    ),
            ),
          ],
          if (_error != null) InlineError(_error!),
        ]),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.value, required this.title, this.subtitle, required this.onTap, this.expanded, this.onExpand});

  final bool? value;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool? expanded;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final on = value != false;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: on ? AppColors.violet : AppColors.surface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: on ? AppColors.violet : AppColors.chipDot, width: 1.4),
            ),
            child: value == null
                ? const Icon(Icons.remove_rounded, size: 18, color: Colors.white)
                : (value! ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.bodyStrong),
              if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: AppText.caption),
            ]),
          ),
          if (onExpand != null)
            IconButton(
              tooltip: expanded == true ? 'Свернуть' : 'Показать сотрудников',
              onPressed: onExpand,
              icon: AnimatedRotation(
                turns: expanded == true ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(CupertinoIcons.chevron_down, size: 18, color: AppColors.ink2),
              ),
            ),
        ]),
      ),
    );
  }
}
