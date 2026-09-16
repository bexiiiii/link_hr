import 'package:flutter/cupertino.dart';

import '../../core/checkin_photo.dart';
import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import 'attendance_screen.dart';

class CheckinHistoryScreen extends StatefulWidget {
  const CheckinHistoryScreen({super.key});

  @override
  State<CheckinHistoryScreen> createState() => _CheckinHistoryScreenState();
}

class _CheckinHistoryScreenState extends State<CheckinHistoryScreen> {
  static const _page = 40;
  final List<Json> _logs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;
  final Map<String, String> _photos = {};

  Future<void> _loadPhotos(List<Json> rows) async {
    try {
      final map = await Hr.checkinPhotos([for (final r in rows) if (r['log_type'] == 'IN') r['name'].toString()]);
      if (mounted) setState(() => _photos.addAll(map));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final rows = await Hr.checkins(limit: _page);
      if (!mounted) return;
      setState(() {
        _logs
          ..clear()
          ..addAll(rows);
        _hasMore = rows.length == _page;
        _loading = false;
        _error = null;
      });
      _loadPhotos(rows);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _more() async {
    setState(() => _loadingMore = true);
    try {
      final rows = await Hr.checkins(limit: _page, start: _logs.length);
      if (!mounted) return;
      setState(() {
        _logs.addAll(rows);
        _hasMore = rows.length == _page;
      });
      _loadPhotos(rows);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Json>>{};
    for (final l in _logs) {
      groups.putIfAbsent(Fmt.iso(Fmt.parse(l['time']) ?? DateTime.now()), () => []).add(l);
    }
    return AppPage(
      header: const ScreenHeader(title: 'История отметок'),
      body: PageScroll(onRefresh: _refresh, children: [
        if (_loading)
          const SkeletonCards(count: 3, height: 150)
        else if (_error != null)
          ErrorState(error: _error!, onRetry: _refresh)
        else if (_logs.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.location,
            title: 'Отметок пока нет',
            message: 'Отметьте приход на главном экране, и история появится здесь.',
          )
        else ...[
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
              child: Text(Fmt.todayLine(DateTime.parse(entry.key)), style: AppText.label),
            ),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Divided(children: [for (final l in entry.value) CheckinRow(
                    log: l,
                    showDate: false,
                    photo: _photos[l['name']],
                    onAddPhoto: () async {
                      final url = await addCheckinPhoto(context, l['name'].toString());
                      if (url != null && mounted) setState(() => _photos[l['name'].toString()] = url);
                    },
                  )]),
            ),
          ],
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: PrimaryButton(
                label: 'Показать ещё',
                kind: ButtonKind.outline,
                height: 48,
                loading: _loadingMore,
                onTap: _more,
              ),
            ),
        ],
      ]),
    );
  }
}
