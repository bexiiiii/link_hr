import 'package:flutter/cupertino.dart';
import '../../core/app_icons.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/fmt.dart';
import 'request_kind.dart';

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key, required this.kind, this.team = false});

  final RequestKind kind;
  final bool team;

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  late int _tab = widget.team ? 1 : 0;
  List<Json> _items = [];
  bool _loading = true;
  Object? _error;
  String? _status;

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
    final tab = _tab;
    try {
      final items = await widget.kind.fetch(team: tab == 1);
      if (!mounted || tab != _tab) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || tab != _tab) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final counts = <String, int>{};
    for (final d in _items) {
      final s = kind.status(d);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final visible = _status == null
        ? _items
        : _items.where((d) => kind.status(d) == _status).toList();

    return AppPage(
      header: ScreenHeader(
        title: kind.plural,
        actions: [
          CircleButton(
            icon: AppIcons.add,
            label: 'Новая заявка',
            onTap: () => pushPage(context, kind.form()),
          ),
        ],
      ),
      body: Column(
        children: [
          if (kind.hasTeam)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SegmentTabs(
                labels: const ['Мои', 'На согласование'],
                index: _tab,
                onChanged: (i) {
                  setState(() {
                    _tab = i;
                    _loading = true;
                    _status = null;
                    _items = [];
                  });
                  _load();
                },
              ),
            ),
          if (counts.length > 1)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final e in counts.entries) ...[
                    CountChip(
                      label: statusLabel(e.key),
                      count: e.value,
                      tone: toneForStatus(e.key) == Tone.neutral
                          ? Tone.dark
                          : toneForStatus(e.key),
                      selected: _status == e.key,
                      onTap: () => setState(
                        () => _status = _status == e.key ? null : e.key,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          if (counts.length > 1) const SizedBox(height: 12),
          Expanded(
            child: PageScroll(
              onRefresh: _load,
              children: [
                if (_loading)
                  const SkeletonCards(count: 5, height: 76)
                else if (_error != null)
                  ErrorState(error: _error!, onRetry: _load)
                else if (visible.isEmpty)
                  EmptyState(
                    icon: kind.icon,
                    title: _tab == 0
                        ? 'Заявок пока нет'
                        : 'Нечего согласовывать',
                    message: _tab == 0
                        ? 'Создайте заявку кнопкой «+» вверху, она появится в этом списке.'
                        : 'Здесь появятся заявки сотрудников, где вы указаны согласующим.',
                    actionLabel: _tab == 0 ? 'Создать заявку' : null,
                    onAction: _tab == 0
                        ? () => pushPage(context, kind.form())
                        : null,
                  )
                else
                  for (final d in visible)
                    RequestTile(
                      kind: kind,
                      data: d,
                      showEmployee: _tab == 1,
                      onChanged: _load,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
