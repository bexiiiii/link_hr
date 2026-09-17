import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/files.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/media.dart';
import '../../core/motion.dart';
import '../../core/people.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/checklists.dart';

class ChecklistRunScreen extends StatefulWidget {
  const ChecklistRunScreen({super.key, required this.name});

  final String name;

  @override
  State<ChecklistRunScreen> createState() => _ChecklistRunScreenState();
}

class _ChecklistRunScreenState extends State<ChecklistRunScreen> {
  ChecklistRun? _run;
  final List<Attachment> _files = [];
  Object? _error;
  bool _expanded = true;
  bool _uploading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final run = await Checklists.get(widget.name);
      if (!mounted) return;
      setState(() {
        _run = run;
        _files
          ..clear()
          ..addAll(run.attachments);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _mark(ChecklistItem item, ItemState state) async {
    final previous = item.state;
    final next = previous == state ? ItemState.open : state;
    setState(() => item.state = next);
    try {
      await Checklists.setItem(item, next);
    } catch (e) {
      if (mounted) {
        setState(() => item.state = previous);
        showToast(context, errorText(e), error: true);
      }
    }
  }

  Future<void> _attach() async {
    final f = await pickAttachment(context);
    if (f == null) return;
    setState(() => _uploading = true);
    try {
      final a = await f.upload('ToDo', widget.name);
      if (mounted) setState(() => _files.add(a));
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await Checklists.complete(_run!);
      Session.instance.notifyDataChanged();
      if (mounted) {
        showToast(context, 'Чеклист завершён');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final needsPhoto =
        run != null && run.meta.photo && _files.isEmpty && !run.closed;
    final canFinish =
        run != null && !run.closed && run.allMarked && !needsPhoto;
    return AppPage(
      header: ScreenHeader(title: run?.meta.title ?? 'Чеклист'),
      bottom: run == null
          ? null
          : run.closed
          ? const PrimaryButton(
              label: 'Чеклист завершён',
              kind: ButtonKind.outline,
            )
          : PrimaryButton(
              label: 'Завершить',
              loading: _busy,
              onTap: canFinish ? _complete : null,
            ),
      body: _error != null
          ? PageScroll(
              children: [ErrorState(error: _error!, onRetry: _load)],
            )
          : run == null
          ? PageScroll(children: const [SkeletonCards(count: 2, height: 160)])
          : PageScroll(
              onRefresh: _load,
              children: [
                if (needsPhoto)
                  Reveal(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.amberSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEBD49A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            AppIcons.exclamationmarkTriangleFill,
                            color: Color(0xFFD9A21B),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Чеклист нельзя завершить без прикреплённого фото-отчёта',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: Color(0xFF6B4E00),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    children: [
                      Pressable(
                        onTap: () => setState(() => _expanded = !_expanded),
                        scale: 0.99,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                value: run.items.isEmpty
                                    ? 0
                                    : run.items
                                              .where(
                                                (i) =>
                                                    i.state != ItemState.open,
                                              )
                                              .length /
                                          run.items.length,
                                strokeWidth: 3,
                                backgroundColor: AppColors.chip,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    run.meta.title,
                                    style: AppText.bodyStrong,
                                  ),
                                  Text(run.meta.window, style: AppText.caption),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                AppIcons.chevronDown,
                                size: 18,
                                color: AppColors.ink2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutQuart,
                        child: !_expanded
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  children: [
                                    for (final (i, item) in run.items.indexed)
                                      Reveal(
                                        index: i,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              _Box(
                                                on:
                                                    item.state ==
                                                    ItemState.done,
                                                icon: Icons.check_rounded,
                                                color: AppColors.green,
                                                label: 'Выполнено',
                                                onTap: run.closed
                                                    ? null
                                                    : () => _mark(
                                                        item,
                                                        ItemState.done,
                                                      ),
                                              ),
                                              const SizedBox(width: 6),
                                              _Box(
                                                on:
                                                    item.state ==
                                                    ItemState.failed,
                                                icon: Icons.close_rounded,
                                                color: AppColors.charcoal,
                                                label: 'Не выполнено',
                                                onTap: run.closed
                                                    ? null
                                                    : () => _mark(
                                                        item,
                                                        ItemState.failed,
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: AnimatedDefaultTextStyle(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  style: AppText.body.copyWith(
                                                    color:
                                                        item.state ==
                                                            ItemState.failed
                                                        ? AppColors.ink3
                                                        : AppColors.ink,
                                                    decoration:
                                                        item.state ==
                                                            ItemState.failed
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                                  child: Text(item.title),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (run.items.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          'В чеклисте нет пунктов',
                                          style: AppText.caption,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final f in _files)
                  AttachmentTile(
                    name: f.fileName,
                    meta: f.meta,
                    onTap: () => Files.open(f).catchError((_) {}),
                  ),
                if (!run.closed)
                  DashedBox(
                    height: 56,
                    onTap: _uploading ? null : _attach,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _uploading
                            ? const CupertinoActivityIndicator()
                            : const Icon(
                                AppIcons.cloudUploadFill,
                                color: AppColors.ink3,
                              ),
                        const SizedBox(width: 8),
                        Text(
                          _uploading ? 'Загрузка…' : 'Файл или фото',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.on,
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  final bool on;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.85,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutQuart,
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: on ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? color : AppColors.line, width: 1.4),
        ),
        child: Icon(icon, size: 18, color: on ? Colors.white : AppColors.ink4),
      ),
    );
  }
}

class ChecklistsScreen extends StatefulWidget {
  const ChecklistsScreen({super.key});

  @override
  State<ChecklistsScreen> createState() => _ChecklistsScreenState();
}

class _ChecklistsScreenState extends State<ChecklistsScreen> {
  int _tab = 0;
  List<ChecklistRun>? _today;
  List<ChecklistTemplate>? _templates;
  List<ChecklistRun>? _history;
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
      final now = DateTime.now();
      final r = await Future.wait<Object>([
        Checklists.today(),
        Checklists.templates(),
        Checklists.runs(
          from: now.subtract(const Duration(days: 30)),
          to: now,
          user: Session.instance.userId,
        ),
        People.byUser(),
      ]);
      if (!mounted) return;
      setState(() {
        _today = r[0] as List<ChecklistRun>;
        _templates = r[1] as List<ChecklistTemplate>;
        _history = (r[2] as List<ChecklistRun>)
          ..sort((a, b) => (b.date ?? now).compareTo(a.date ?? now));
        _people = r[3] as Map<String, PersonInfo>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: ScreenHeader(
        title: 'Чеклисты',
        actions: [
          if (Session.instance.isManager)
            CircleButton(
              icon: AppIcons.add,
              label: 'Новый чеклист',
              onTap: () async {
                final ok = await pushPage<bool>(
                  context,
                  const ChecklistFormScreen(),
                );
                if (ok == true) _load();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SegmentTabs(
              labels: Session.instance.isManager
                  ? const ['Сегодня', 'Шаблоны', 'История']
                  : const ['Сегодня', 'История'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: PageScroll(
              onRefresh: _load,
              children: [
                if (_error != null)
                  ErrorState(error: _error!, onRetry: _load)
                else if (_today == null)
                  const SkeletonCards(count: 3, height: 76)
                else
                  ...switch (Session.instance.isManager || _tab == 0
                      ? _tab
                      : 2) {
                    0 => _runList(
                      _today!,
                      empty:
                          'На сегодня чеклистов нет. Создайте шаблон, и он будет появляться каждый день.',
                    ),
                    1 => _templateList(),
                    _ => _runList(
                      _history!,
                      empty: 'Завершённые чеклисты за 30 дней появятся здесь.',
                      dated: true,
                    ),
                  },
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _runList(
    List<ChecklistRun> runs, {
    required String empty,
    bool dated = false,
  }) {
    if (runs.isEmpty) {
      return [
        EmptyState(icon: AppIcons.listBullet, title: 'Пусто', message: empty),
      ];
    }
    return [
      SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Divided(
          children: [
            for (final (i, r) in runs.indexed)
              Reveal(
                index: i.clamp(0, 12),
                child: Pressable(
                  onTap: () =>
                      pushPage(context, ChecklistRunScreen(name: r.name)),
                  scale: 0.99,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      children: [
                        IconBadge(
                          icon: r.closed
                              ? AppIcons.checkmarkAlt
                              : AppIcons.listBullet,
                          tone: r.closed ? Tone.green : Tone.violet,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.meta.title, style: AppText.bodyStrong),
                              Text(
                                [
                                  if (dated) Fmt.weekdayDate(r.date),
                                  r.meta.window,
                                  '${r.doneCount}/${r.items.length}',
                                ].join(' · '),
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          AppIcons.chevronRight,
                          size: 16,
                          color: AppColors.ink4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _templateList() {
    final list = _templates!;
    if (list.isEmpty) {
      return [
        EmptyState(
          icon: AppIcons.docOnClipboard,
          title: 'Шаблонов нет',
          message:
              'Шаблон задаёт пункты и время. По нему у сотрудника каждый день появляется чеклист.',
          actionLabel: 'Создать шаблон',
          onAction: () => pushPage(context, const ChecklistFormScreen()),
        ),
      ];
    }
    return [
      SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Divided(
          children: [
            for (final (i, t) in list.indexed)
              Reveal(
                index: i.clamp(0, 12),
                child: Pressable(
                  onLongPress: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Архивировать шаблон?',
                      message: 'Новые чеклисты по нему перестанут появляться.',
                      confirmLabel: 'Архивировать',
                      destructive: true,
                    );
                    if (!ok) return;
                    try {
                      await Checklists.archiveTemplate(t.name);
                      _load();
                    } catch (e) {
                      if (mounted)
                        showToast(context, errorText(e), error: true);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      children: [
                        AppAvatar(
                          name: People.resolve(_people, t.allocatedTo).name,
                          imageUrl: People.resolve(
                            _people,
                            t.allocatedTo,
                          ).image,
                          size: 42,
                          border: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.meta.title, style: AppText.bodyStrong),
                              Text(
                                [
                                  People.resolve(
                                    _people,
                                    t.allocatedTo,
                                  ).shortName,
                                  t.meta.window,
                                  '${t.itemCount} пунктов',
                                  if (t.meta.photo) 'фото',
                                ].join(' · '),
                                style: AppText.caption,
                              ),
                            ],
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
    ];
  }
}

class ChecklistFormScreen extends StatefulWidget {
  const ChecklistFormScreen({super.key});

  @override
  State<ChecklistFormScreen> createState() => _ChecklistFormScreenState();
}

class _ChecklistFormScreenState extends State<ChecklistFormScreen> {
  final _title = TextEditingController();
  final List<TextEditingController> _items = [TextEditingController()];
  TimeOfDay? _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _to = const TimeOfDay(hour: 10, minute: 0);
  bool _photo = false;
  List<String> _assignees = [Session.instance.userId];
  Map<String, PersonInfo> _people = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    People.byUser().then((p) {
      if (mounted) setState(() => _people = p);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _items) {
      c.dispose();
    }
    super.dispose();
  }

  String? _fmt(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) {
    var temp = DateTime(2000, 1, 1, initial?.hour ?? 9, initial?.minute ?? 0);
    return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder: (c) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Отмена'),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(
                      c,
                      TimeOfDay(hour: temp.hour, minute: temp.minute),
                    ),
                    child: const Text(
                      'Готово',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  minuteInterval: 5,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    temp.hour,
                    temp.minute - temp.minute % 5,
                  ),
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final items = _items
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (title.isEmpty || items.isEmpty) {
      setState(() => _error = 'Укажите название и хотя бы один пункт');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Checklists.createTemplate(
        meta: ChecklistMeta(
          title: title,
          from: _fmt(_from),
          to: _fmt(_to),
          photo: _photo,
        ),
        items: items,
        assignees: _assignees,
      );
      Session.instance.notifyDataChanged();
      if (mounted) {
        showToast(context, 'Чеклист создан');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Новый чеклист',
      submitLabel: 'Создать чеклист',
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        AppTextField(
          label: 'Название',
          controller: _title,
          required: true,
          hint: 'Например, открытие смены',
        ),
        const FormGap(),
        const FieldLabel('Время выполнения'),
        Row(
          children: [
            for (final (label, value, set) in [
              ('С', _from, (TimeOfDay? t) => _from = t),
              ('До', _to, (TimeOfDay? t) => _to = t),
            ]) ...[
              Expanded(
                child: SurfaceCard(
                  radius: AppRadius.field,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  onTap: () async {
                    final t = await _pickTime(value);
                    if (t != null) setState(() => set(t));
                  },
                  child: Row(
                    children: [
                      Text(label, style: AppText.caption),
                      const Spacer(),
                      Text(
                        _fmt(value) ?? '—',
                        style: AppText.number.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              if (label == 'С') const SizedBox(width: 10),
            ],
          ],
        ),
        const FormGap(),
        SwitchInput(
          label: 'Фото-отчёт обязателен',
          subtitle: 'Без фото чеклист нельзя завершить',
          value: _photo,
          onChanged: (v) => setState(() => _photo = v),
        ),
        const FormGap(),
        const FieldLabel('Пункты', required: true),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _items[i],
              style: AppText.body,
              textInputAction: TextInputAction.next,
              onChanged: (v) {
                if (i == _items.length - 1 && v.isNotEmpty)
                  setState(() => _items.add(TextEditingController()));
              },
              decoration: fieldDecoration(hint: 'Пункт ${i + 1}'),
            ),
          ),
        const FormGap(),
        SurfaceCard(
          onTap: () async {
            final picked = await pickPeople(
              context,
              title: 'Кому назначить',
              multi: true,
              selected: _assignees,
            );
            if (picked != null && picked.isNotEmpty)
              setState(() => _assignees = picked);
          },
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Сотрудники', style: AppText.cardTitle),
                    Text(
                      _assignees
                          .map((id) => People.resolve(_people, id).shortName)
                          .join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              AvatarStack(
                people: [
                  for (final id in _assignees)
                    Person(
                      People.resolve(_people, id).name,
                      People.resolve(_people, id).image,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
