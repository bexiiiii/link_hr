import 'package:flutter/cupertino.dart';

import '../../core/api.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import 'request_kind.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  int _tab = 0;
  List<(RequestKind, Json)>? _mine;
  List<(RequestKind, Json)>? _team;

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
    final r = await Future.wait([fetchRequestFeed(team: false), fetchRequestFeed(team: true)]);
    if (mounted) {
      setState(() {
        _mine = r[0];
        _team = r[1];
      });
    }
  }

  Future<void> _create() async {
    final kind = await pickAction(context, title: 'Новый запрос', actions: [
      for (final k in RequestKind.values) SheetAction(k.name, k.singular),
    ]);
    if (kind == null || !mounted) return;
    await pushPage(context, RequestKind.values.byName(kind).form());
  }

  @override
  Widget build(BuildContext context) {
    final list = _tab == 0 ? _mine : _team;
    return AppPage(
      header: ScreenHeader(title: 'Запросы', actions: [
        CircleButton(icon: CupertinoIcons.add, label: 'Новый запрос', onTap: _create),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SegmentTabs(
            labels: ['Мои', 'На согласование${(_team?.isEmpty ?? true) ? '' : ' · ${_team!.length}'}'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(
          child: PageScroll(onRefresh: _load, children: [
            if (list == null)
              const SkeletonCards(count: 4, height: 76)
            else if (list.isEmpty)
              EmptyState(
                icon: _tab == 0 ? CupertinoIcons.doc_text : CupertinoIcons.person_2,
                title: _tab == 0 ? 'Запросов пока нет' : 'Нечего согласовывать',
                message: _tab == 0
                    ? 'Отпуск, расходы, авансы, смены и отметки появятся здесь после подачи.'
                    : 'Запросы сотрудников, где вы согласующий, появятся здесь.',
                actionLabel: _tab == 0 ? 'Создать запрос' : null,
                onAction: _create,
              )
            else
              for (final (i, (kind, data)) in list.indexed)
                Reveal(
                  index: i,
                  child: RequestTile(kind: kind, data: data, showEmployee: _tab == 1, onChanged: _load),
                ),
          ]),
        ),
      ]),
    );
  }
}
