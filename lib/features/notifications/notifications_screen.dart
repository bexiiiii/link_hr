import 'package:flutter/cupertino.dart';
import '../../core/app_icons.dart';

import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../requests/request_detail_screen.dart';
import '../requests/request_kind.dart';
import '../tasks/task_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _page = 20;
  final List<Json> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final rows = await Hr.notifications(limit: _page);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(rows);
        _hasMore = rows.length == _page;
        _loading = false;
        _error = null;
      });
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
      final rows = await Hr.notifications(start: _items.length, limit: _page);
      if (mounted) {
        setState(() {
          _items.addAll(rows);
          _hasMore = rows.length == _page;
        });
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await Hr.markAllNotificationsRead();
      await _refresh();
      Session.instance.notifyDataChanged();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _open(Json n) async {
    if (n['read'] != 1) {
      setState(() => n['read'] = 1);
      Hr.markNotificationRead(n['name'].toString()).catchError((_) {});
    }
    final type = n['reference_document_type']?.toString();
    final name = n['reference_document_name']?.toString();
    if (name == null || name.isEmpty) return;
    final kind = RequestKind.fromDoctype(type);
    if (kind != null) {
      await pushPage(context, RequestDetailScreen(kind: kind, name: name));
    } else if (type == 'ToDo') {
      await pushPage(context, TaskDetailScreen(name: name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => n['read'] != 1).length;
    return AppPage(
      header: ScreenHeader(
        title: 'Уведомления',
        actions: [
          if (unread > 0)
            CircleButton(
              icon: AppIcons.checkmarkAlt,
              label: 'Прочитать все',
              onTap: _markAll,
            ),
        ],
      ),
      body: PageScroll(
        onRefresh: _refresh,
        children: [
          if (_loading)
            const SkeletonCards(count: 5, height: 72)
          else if (_error != null)
            ErrorState(error: _error!, onRetry: _refresh)
          else if (_items.isEmpty)
            const EmptyState(
              icon: AppIcons.bell,
              title: 'Уведомлений нет',
              message:
                  'Здесь появятся ответы по вашим заявкам и новые заявки на согласование.',
            )
          else ...[
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Divided(
                children: [
                  for (final n in _items)
                    Pressable(
                      onTap: () => _open(n),
                      scale: 0.99,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppAvatar(
                              name: n['from_user']?.toString() ?? 'Link',
                              size: 40,
                              border: false,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stripHtml(n['message']?.toString()),
                                    style: AppText.body.copyWith(
                                      fontWeight: n['read'] == 1
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                      color: n['read'] == 1
                                          ? AppColors.ink2
                                          : AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Fmt.relative(n['creation']),
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                            if (n['read'] != 1)
                              Container(
                                margin: const EdgeInsets.only(left: 8, top: 6),
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: AppColors.violet,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
        ],
      ),
    );
  }
}
