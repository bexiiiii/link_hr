import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/hr.dart';
import 'session.dart';
import 'theme.dart';
import 'ui.dart';

class PersonInfo {
  const PersonInfo({
    required this.userId,
    required this.name,
    this.employee = '',
    this.designation = '',
    this.department = '',
    this.image,
  });

  final String userId;
  final String name;
  final String employee;
  final String designation;
  final String department;
  final String? image;

  String get role => designation.isNotEmpty ? designation : department;
  String get shortName => name.split(' ').first;
}

abstract final class People {
  static Future<List<PersonInfo>> all({bool refresh = false}) async {
    final rows = await Hr.employees(refresh: refresh);
    final list = [
      for (final e in rows)
        if ((e['user_id'] ?? '').toString().isNotEmpty &&
            (e['status'] ?? 'Active') == 'Active')
          PersonInfo(
            userId: e['user_id'].toString(),
            name: (e['employee_name'] ?? e['user_id']).toString(),
            employee: e['name'].toString(),
            designation: (e['designation'] ?? '').toString(),
            department: (e['department'] ?? '').toString(),
            image: e['image']?.toString(),
          ),
    ];
    final me = Session.instance.userId;
    if (me.isNotEmpty && !list.any((p) => p.userId == me)) {
      list.add(
        PersonInfo(
          userId: me,
          name: Session.instance.fullName,
          employee: Session.instance.employeeId,
          designation: Session.instance.designation,
          department: Session.instance.department,
          image: Session.instance.image,
        ),
      );
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static Future<Map<String, PersonInfo>> byUser() async {
    try {
      return {for (final p in await all()) p.userId: p};
    } catch (_) {
      return {};
    }
  }

  static PersonInfo resolve(Map<String, PersonInfo> map, String userId) =>
      map[userId] ?? PersonInfo(userId: userId, name: userId.split('@').first);
}

/// Full-height people chooser: Отмена · title · Далее, search, frequent first.
Future<List<String>?> pickPeople(
  BuildContext context, {
  required String title,
  required bool multi,
  List<String> selected = const [],
  List<String> frequent = const [],
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => _PeopleSheet(
      title: title,
      multi: multi,
      selected: selected,
      frequent: frequent,
    ),
  );
}

class _PeopleSheet extends StatefulWidget {
  const _PeopleSheet({
    required this.title,
    required this.multi,
    required this.selected,
    required this.frequent,
  });

  final String title;
  final bool multi;
  final List<String> selected;
  final List<String> frequent;

  @override
  State<_PeopleSheet> createState() => _PeopleSheetState();
}

class _PeopleSheetState extends State<_PeopleSheet> {
  late final Set<String> _picked = {...widget.selected};
  List<PersonInfo>? _people;
  Object? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await People.all();
      if (mounted) setState(() => _people = people);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _tap(String id) {
    setState(() {
      if (widget.multi) {
        _picked.contains(id) ? _picked.remove(id) : _picked.add(id);
      } else {
        _picked
          ..clear()
          ..add(id);
      }
    });
    if (!widget.multi) Navigator.pop(context, _picked.toList());
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final people = (_people ?? const <PersonInfo>[])
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.role.toLowerCase().contains(q),
        )
        .toList();
    final frequent = [
      for (final id in widget.frequent) ...people.where((p) => p.userId == id),
    ];
    final rest = people
        .where((p) => !widget.frequent.contains(p.userId))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(color: AppColors.ink, fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppText.cardTitle,
                    ),
                  ),
                  CupertinoButton(
                    onPressed: widget.multi
                        ? () => Navigator.pop(context, _picked.toList())
                        : null,
                    child: Text(
                      widget.multi ? 'Далее' : '     ',
                      style: const TextStyle(
                        color: AppColors.violet,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: CupertinoSearchTextField(
                placeholder: 'Поиск',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: ErrorState(error: _error!, onRetry: _load),
                    )
                  : _people == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        if (frequent.isNotEmpty) ...[
                          const _Section('Часто взаимодействующие'),
                          for (final p in frequent) _row(p),
                        ],
                        const _Section('Сотрудники'),
                        if (rest.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Никого не найдено',
                              style: AppText.label.copyWith(
                                color: AppColors.ink3,
                              ),
                            ),
                          ),
                        for (final p in rest) _row(p),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(PersonInfo p) {
    final on = _picked.contains(p.userId);
    final me = p.userId == Session.instance.userId;
    return Pressable(
      onTap: () => _tap(p.userId),
      scale: 0.99,
      semanticLabel: '${p.name}, ${on ? 'выбран' : 'не выбран'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? AppColors.violet : Colors.transparent,
                border: Border.all(
                  color: on ? AppColors.violet : AppColors.chipDot,
                  width: 1.5,
                ),
              ),
              child: on
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            AppAvatar(name: p.name, imageUrl: p.image, size: 46, border: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me ? '${p.name} (вы)' : p.name,
                    style: AppText.bodyStrong,
                  ),
                  if (p.role.isNotEmpty) Text(p.role, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(text, style: AppText.label),
  );
}

class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.person,
    this.caption,
    this.trailing,
  });

  final PersonInfo person;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(
          name: person.name,
          imageUrl: person.image,
          size: 46,
          border: false,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.name, style: AppText.bodyStrong),
              Text(caption ?? person.role, style: AppText.caption),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
