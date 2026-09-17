import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/kit.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/notices.dart';
import '../analysis/analysis_screen.dart';

enum KzDoc {
  contract(
    'KZ Labor Contract',
    'Договоры',
    'Трудовой договор',
    CupertinoIcons.doc_text,
    Tone.violet,
  ),
  order(
    'KZ Personnel Order',
    'Приказы',
    'Кадровый приказ',
    CupertinoIcons.doc_checkmark,
    Tone.green,
  ),
  timesheet(
    'KZ Timesheet',
    'Табели',
    'Табель Т-13',
    CupertinoIcons.table,
    Tone.dark,
  );

  const KzDoc(this.doctype, this.plural, this.singular, this.icon, this.tone);

  final String doctype;
  final String plural;
  final String singular;
  final IconData icon;
  final Tone tone;

  bool get creatable => this != KzDoc.timesheet;

  List<String> get fields => switch (this) {
    KzDoc.contract => [
      'name',
      'title',
      'contract_number',
      'contract_date',
      'status',
      'designation',
      'employee',
      'employee_name',
      'docstatus',
      'modified',
    ],
    KzDoc.order => [
      'name',
      'title',
      'order_type',
      'order_number',
      'order_date',
      'status',
      'employee',
      'employee_name',
      'docstatus',
      'modified',
    ],
    KzDoc.timesheet => [
      'name',
      'title',
      'year',
      'month',
      'status',
      'department',
      'total_hours',
      'docstatus',
      'modified',
    ],
  };

  Future<List<Json>> fetch({required bool all}) {
    final me = Session.instance.employeeId;
    return Api.instance.list(
      doctype,
      fields: fields,
      filters: all
          ? null
          : this == KzDoc.timesheet
          ? [
              ['KZ Timesheet Detail', 'employee', '=', me],
            ]
          : {'employee': me},
      orderBy: 'modified desc',
      limit: 300,
    );
  }

  String title(Json d) => switch (this) {
    KzDoc.contract => 'Договор № ${d['contract_number'] ?? d['name']}',
    KzDoc.order => (d['title'] ?? d['order_type'] ?? d['name']).toString(),
    KzDoc.timesheet =>
      'Табель за ${Fmt.monthYear(DateTime(Fmt.number(d['year']).toInt(), Fmt.number(d['month']).toInt().clamp(1, 12))).toLowerCase()}',
  };

  String subtitle(Json d) => switch (this) {
    KzDoc.contract || KzDoc.order => [
      d['employee_name'] ?? '',
      d['designation'] ?? '',
      Fmt.date(d['contract_date'] ?? d['order_date']),
    ].where((s) => '$s'.isNotEmpty).join(' · '),
    KzDoc.timesheet =>
      '${Fmt.decimal(d['total_hours'])} ч · ${d['department'] ?? ''}',
  };
}

enum DocState {
  sign('Подпишите', CupertinoIcons.signature, Tone.violet),
  waiting('Ожидается', CupertinoIcons.clock, Tone.amber),
  draft('Черновик', CupertinoIcons.pencil, Tone.neutral),
  ready('Готово', CupertinoIcons.checkmark_circle, Tone.green),
  closed('Закрыт', CupertinoIcons.xmark_circle, Tone.dark);

  const DocState(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final Tone tone;

  static DocState of(Json d, List<SignRequest> requests) {
    final me = Session.instance.userId;
    final mine = requests.where((r) => r.docname == d['name'] && !r.signed);
    if (mine.any((r) => r.to == me)) return DocState.sign;
    if (mine.isNotEmpty) return DocState.waiting;
    return switch ((d['status'] ?? '').toString()) {
      'Черновик' || 'Draft' => DocState.draft,
      'На согласовании' => DocState.waiting,
      'Действует' || 'Подписан' || 'Утвержден' => DocState.ready,
      'Расторгнут' || 'Истек' || 'Отменен' || 'Закрыт' => DocState.closed,
      _ => switch (Fmt.number(d['docstatus']).toInt()) {
        1 => DocState.ready,
        2 => DocState.closed,
        _ => DocState.draft,
      },
    };
  }
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final Map<KzDoc, List<Json>> _data = {};
  List<SignRequest> _requests = [];
  Object? _error;
  bool _loading = true;
  KzDoc? _type;
  DocState? _state;
  String _query = '';

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
    final all = isManager();
    Object? error;
    await Future.wait([
      for (final k in KzDoc.values)
        k.fetch(all: all).then((rows) => _data[k] = rows).catchError((
          Object e,
        ) {
          error = e;
          return <Json>[];
        }),
      Notices.signRequests()
          .then((r) => _requests = r)
          .catchError((_) => <SignRequest>[]),
    ]);
    if (mounted) {
      setState(() {
        _loading = false;
        _error = _data.values.every((l) => l.isEmpty) ? error : null;
      });
    }
  }

  Future<void> _create() async {
    final picked = await pickAction(
      context,
      title: 'Новый документ',
      actions: [
        for (final k in KzDoc.values.where((k) => k.creatable))
          SheetAction(k.name, k.singular),
      ],
    );
    if (picked == null || !mounted) return;
    await pushPage(
      context,
      DocumentFormScreen(kind: KzDoc.values.byName(picked)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final rows = <(KzDoc, Json, DocState)>[
      for (final k in KzDoc.values)
        if (_type == null || _type == k)
          for (final d in _data[k] ?? const <Json>[])
            if (q.isEmpty ||
                '${k.title(d)} ${k.subtitle(d)} ${d['name']}'
                    .toLowerCase()
                    .contains(q))
              (k, d, DocState.of(d, _requests)),
    ].where((r) => _state == null || r.$3 == _state).toList();
    final counts = {for (final s in DocState.values) s: 0};
    for (final k in KzDoc.values) {
      for (final d in _data[k] ?? const <Json>[]) {
        final s = DocState.of(d, _requests);
        counts[s] = counts[s]! + 1;
      }
    }

    return AppPage(
      header: ScreenHeader(
        title: 'Документы',
        showBack: widget.showBack,
        actions: [
          if (isManager())
            CircleButton(
              icon: CupertinoIcons.add,
              label: 'Новый документ',
              onTap: _create,
            ),
        ],
      ),
      body: PageScroll(
        onRefresh: _load,
        children: [
          CupertinoSearchTextField(
            placeholder: 'Поиск документа или сотрудника',
            backgroundColor: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DropdownPill(
                label: _type?.plural ?? 'Все типы',
                onTap: () async {
                  final picked = await pickAction(
                    context,
                    title: 'Тип документа',
                    actions: [
                      const SheetAction('all', 'Все типы'),
                      for (final k in KzDoc.values)
                        SheetAction(k.name, k.plural),
                    ],
                  );
                  if (picked != null)
                    setState(
                      () => _type = picked == 'all'
                          ? null
                          : KzDoc.values.byName(picked),
                    );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final s in DocState.values)
                  if (counts[s]! > 0 || s == _state) ...[
                    TagChip(
                      label: '${s.label} · ${counts[s]}',
                      icon: s.icon,
                      tone: s.tone,
                      selected: _state == s,
                      onTap: () =>
                          setState(() => _state = _state == s ? null : s),
                    ),
                    const SizedBox(width: 8),
                  ],
              ],
            ),
          ),
          GroupLabel(isManager() ? 'Документы сотрудников' : 'Мои документы'),
          if (_loading)
            const Skeleton(height: 260, radius: AppRadius.card)
          else if (_error != null)
            ErrorState(error: _error!, onRetry: _load)
          else if (rows.isEmpty)
            EmptyState(
              icon: CupertinoIcons.doc_text_search,
              title: q.isNotEmpty || _state != null || _type != null
                  ? 'Ничего не найдено'
                  : 'Документов пока нет',
              message: q.isNotEmpty || _state != null || _type != null
                  ? 'Измените поиск или сбросьте фильтры.'
                  : 'Трудовые договоры, приказы и табели Т-13 появятся здесь после оформления отделом кадров.',
              actionLabel: isManager() && q.isEmpty && _state == null
                  ? 'Создать документ'
                  : null,
              onAction: _create,
            )
          else
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Divided(
                children: [
                  for (final (i, (k, d, s)) in rows.indexed)
                    Reveal(
                      index: i.clamp(0, 12),
                      child: _DocRow(kind: k, data: d, state: s),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.kind, required this.data, required this.state});

  final KzDoc kind;
  final Json data;
  final DocState state;

  @override
  Widget build(BuildContext context) {
    final color = state.tone == Tone.neutral ? AppColors.ink2 : state.tone.ink;
    return Pressable(
      onTap: () => pushPage(
        context,
        DocumentDetailScreen(kind: kind, name: data['name'].toString()),
      ),
      scale: 0.99,
      semanticLabel: '${kind.title(data)}, ${state.label}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              CupertinoIcons.doc_text_fill,
              color: AppColors.blue,
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind.title(data),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong,
                  ),
                  if (kind.subtitle(data).isNotEmpty)
                    Text(
                      kind.subtitle(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  Text('Тип: ${kind.singular}', style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: state.tone.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(state.icon, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text(
                    state.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PDF preview of the print format, plus the signature flow.
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.kind,
    required this.name,
  });

  final KzDoc kind;
  final String name;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Json? _doc;
  Uint8List? _pdf;
  Object? _pdfError;
  Object? _error;
  List<SignRequest> _requests = [];
  String? _employeeUser;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await Api.instance.doc(widget.kind.doctype, widget.name);
      final requests = (await Notices.signRequests().catchError(
        (_) => <SignRequest>[],
      )).where((r) => r.docname == widget.name).toList();
      String? user;
      final emp = doc['employee']?.toString();
      if (emp != null && emp.isNotEmpty) {
        final rows = await Api.instance
            .list(
              'Employee',
              fields: ['user_id'],
              filters: {'name': emp},
              limit: 1,
            )
            .catchError((_) => <Json>[]);
        user = rows.firstOrNull?['user_id']?.toString();
      }
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _requests = requests;
        _employeeUser = (user ?? '').isEmpty ? null : user;
        _error = null;
      });
      _loadPdf();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadPdf() async {
    setState(() {
      _pdf = null;
      _pdfError = null;
    });
    try {
      final bytes = await Api.instance.download(
        '/api/method/frappe.utils.print_format.download_pdf'
        '?doctype=${Uri.encodeQueryComponent(widget.kind.doctype)}&name=${Uri.encodeQueryComponent(widget.name)}',
      );
      if (mounted) setState(() => _pdf = bytes);
    } catch (e) {
      if (mounted) setState(() => _pdfError = e);
    }
  }

  Future<void> _send() async {
    final ok = await confirmAction(
      context,
      title: 'Отправить на подпись?',
      message: 'Сотрудник увидит документ со статусом «Подпишите».',
      confirmLabel: 'Отправить',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Notices.requestSignature(
        doctype: widget.kind.doctype,
        docname: widget.name,
        userId: _employeeUser!,
        title: widget.kind.title(_doc!),
      );
      Session.instance.notifyDataChanged();
      if (mounted) showToast(context, 'Документ отправлен сотруднику');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sign(SignRequest r) async {
    final ok = await confirmAction(
      context,
      title: 'Подписать документ?',
      message:
          'Подтверждаете, что ознакомились с документом и согласны с его содержанием.',
      confirmLabel: 'Подписать',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Notices.sign(r.name);
      Session.instance.notifyDataChanged();
      if (mounted) showToast(context, 'Документ подписан');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget? _bottom() {
    final d = _doc;
    if (d == null) return null;
    final me = Session.instance.userId;
    final open = _requests.where((r) => !r.signed).toList();
    final toMe = open.where((r) => r.to == me).firstOrNull;
    if (toMe != null) {
      return PrimaryButton(
        label: 'Подписать документ',
        kind: ButtonKind.green,
        loading: _busy,
        onTap: () => _sign(toMe),
      );
    }
    if (open.isNotEmpty)
      return const PrimaryButton(
        label: 'Ожидает подписи сотрудника',
        kind: ButtonKind.outline,
      );
    final signed = _requests.where((r) => r.signed).firstOrNull;
    if (signed != null) {
      return PrimaryButton(
        label: 'Подписан ${Fmt.date(signed.modified)}',
        kind: ButtonKind.outline,
        icon: CupertinoIcons.checkmark_seal,
      );
    }
    if (isManager() && _employeeUser != null && widget.kind.creatable) {
      return PrimaryButton(
        label: 'Отправить сотруднику',
        loading: _busy,
        onTap: _send,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: ScreenHeader(
        title: 'Детали документа',
        actions: [
          CircleButton(
            icon: CupertinoIcons.share,
            label: 'Поделиться PDF',
            onTap: _pdf == null
                ? null
                : () => SharePlus.instance.share(
                    ShareParams(
                      files: [
                        XFile.fromData(
                          _pdf!,
                          mimeType: 'application/pdf',
                          name: '${widget.name}.pdf',
                        ),
                      ],
                      fileNameOverrides: ['${widget.name}.pdf'],
                    ),
                  ),
          ),
        ],
      ),
      bottom: _bottom(),
      body: _error != null
          ? PageScroll(
              children: [ErrorState(error: _error!, onRetry: _load)],
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: AppColors.surface,
                  child: _pdfError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: ErrorState(
                              error: _pdfError!,
                              onRetry: _loadPdf,
                            ),
                          ),
                        )
                      : _pdf == null
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CupertinoActivityIndicator(radius: 14),
                                SizedBox(height: 12),
                                Text(
                                  'Подождите, готовим документ',
                                  style: AppText.label,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Reveal(
                          child: PdfViewer.data(_pdf!, sourceName: widget.name),
                        ),
                ),
              ),
            ),
    );
  }
}

/// "Заполните поля": builds a form from the doctype meta, saves a draft and
/// opens the PDF preview.
class DocumentFormScreen extends StatefulWidget {
  const DocumentFormScreen({super.key, required this.kind});

  final KzDoc kind;

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  static const _types = {
    'Data',
    'Int',
    'Float',
    'Currency',
    'Small Text',
    'Text',
    'Long Text',
    'Date',
    'Select',
    'Check',
    'Link',
    'Percent',
  };
  static const _skip = {
    'amended_from',
    'naming_series',
    'enbek_sync_status',
    'registration_enbek_id',
  };

  List<Json> _fields = [];
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _text = {};
  final Map<String, List<SelectOption>> _linkOptions = {};
  bool _loading = true;
  Object? _loadError;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _truthy(Object? v) => v == 1 || v == true || v == '1';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final raw = await Api.instance.call('hrms.api.get_doctype_fields', {
        'doctype': widget.kind.doctype,
      });
      final fields = (raw as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .where(
            (f) =>
                _types.contains(f['fieldtype']) &&
                !_skip.contains(f['fieldname']) &&
                !_truthy(f['hidden']) &&
                !_truthy(f['read_only']) &&
                (f['fetch_from'] ?? '').toString().isEmpty,
          )
          .toList();
      final links = fields
          .where((f) => f['fieldtype'] == 'Link')
          .map((f) => f['options'].toString())
          .toSet();
      final options = <String, List<SelectOption>>{};
      await Future.wait(
        links.map((dt) async {
          final isEmployee = dt == 'Employee';
          final rows = await Api.instance
              .list(
                dt,
                fields: ['name', if (isEmployee) 'employee_name'],
                limit: 500,
                orderBy: 'modified desc',
              )
              .catchError((_) => <Json>[]);
          options[dt] = [
            for (final r in rows)
              SelectOption(
                r['name'].toString(),
                isEmployee
                    ? '${r['employee_name'] ?? r['name']}'
                    : r['name'].toString(),
                subtitle: isEmployee ? r['name'].toString() : null,
              ),
          ];
        }),
      );
      for (final f in fields) {
        final name = f['fieldname'].toString();
        final type = f['fieldtype'];
        final def = f['default'];
        if (name == 'company') _values[name] = Session.instance.company;
        if (type == 'Date' && name.endsWith('_date') && def == 'Today')
          _values[name] = DateTime.now();
        if (type == 'Check') _values[name] = _truthy(def);
        if (type == 'Select' && def != null) _values[name] = def.toString();
        if (const {
          'Data',
          'Int',
          'Float',
          'Currency',
          'Small Text',
          'Text',
          'Long Text',
          'Percent',
        }.contains(type)) {
          _text[name] = TextEditingController(
            text: def is String && !def.startsWith('eval') ? def : '',
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _fields = fields;
        _linkOptions.addAll(options);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _submit() async {
    final doc = <String, dynamic>{'doctype': widget.kind.doctype};
    for (final f in _fields) {
      final name = f['fieldname'].toString();
      final type = f['fieldtype'];
      dynamic v;
      if (_text.containsKey(name)) {
        final s = _text[name]!.text.trim();
        v = s.isEmpty
            ? null
            : (type == 'Int'
                  ? int.tryParse(s)
                  : (const {'Float', 'Currency', 'Percent'}.contains(type)
                        ? num.tryParse(
                            s.replaceAll(',', '.').replaceAll(' ', ''),
                          )
                        : s));
      } else {
        v = _values[name];
        if (v is DateTime) v = Fmt.iso(v);
        if (v is bool) v = v ? 1 : 0;
      }
      if (_truthy(f['reqd']) && (v == null || v == '')) {
        setState(() => _error = 'Заполните поле «${f['label']}»');
        return;
      }
      if (v != null) doc[name] = v;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await Api.instance.insert(doc);
      Session.instance.notifyDataChanged();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => DocumentDetailScreen(
              kind: widget.kind,
              name: saved['name'].toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(Json f) {
    final name = f['fieldname'].toString();
    final label = (f['label'] ?? name).toString();
    final required = _truthy(f['reqd']);
    switch (f['fieldtype']) {
      case 'Date':
        return DateInput(
          label: label,
          required: required,
          value: _values[name] as DateTime?,
          clearable: !required,
          onChanged: (d) => setState(() => _values[name] = d),
        );
      case 'Check':
        return SwitchInput(
          label: label,
          value: _values[name] == true,
          onChanged: (v) => setState(() => _values[name] = v),
        );
      case 'Select':
        final opts = (f['options'] ?? '')
            .toString()
            .split('\n')
            .where((o) => o.trim().isNotEmpty)
            .map((o) => SelectOption(o, statusLabel(o)))
            .toList();
        return SelectInput(
          label: label,
          required: required,
          value: _values[name] as String?,
          options: opts,
          onChanged: (v) => setState(() => _values[name] = v),
        );
      case 'Link':
        return SelectInput(
          label: label,
          required: required,
          value: _values[name] as String?,
          options: _linkOptions[f['options']] ?? const [],
          onChanged: (v) => setState(() => _values[name] = v),
        );
      default:
        final multiline = const {
          'Small Text',
          'Text',
          'Long Text',
        }.contains(f['fieldtype']);
        final numeric = const {
          'Int',
          'Float',
          'Currency',
          'Percent',
        }.contains(f['fieldtype']);
        return AppTextField(
          label: label,
          controller: _text[name]!,
          required: required,
          maxLines: multiline ? 4 : 1,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Заполните поля',
      submitLabel: 'Предпросмотр документа',
      busy: _busy,
      loading: _loading,
      loadError: _loadError,
      onRetry: _load,
      error: _error,
      onSubmit: _submit,
      children: [
        Text(
          widget.kind.singular,
          style: AppText.display.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 18),
        for (final (i, f) in _fields.indexed) ...[
          Reveal(index: i.clamp(0, 10), child: _field(f)),
          const FormGap(),
        ],
      ],
    );
  }
}
