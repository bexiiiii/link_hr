import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/kit.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/score.dart';

bool isManager() => Session.instance.isManager;

const _degrees = ['', 'I', 'II', 'III', 'IV'];

/// Team discipline analysis for managers: lateness, missed work and absences
/// shown as SIP-A / SIP-B / SIP-C scales per employee.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<DisciplineEntry>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (isManager()) _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await Discipline.load(_month);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isManager()) {
      return AppPage(
        header: const ScreenHeader(title: 'Анализ'),
        body: PageScroll(children: const [
          EmptyState(
            icon: CupertinoIcons.lock,
            title: 'Раздел для руководителей',
            message: 'Анализ доступен руководителям и отделу кадров.',
          ),
        ]),
      );
    }
    final s = Session.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFD9DADE),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _load),
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 200,
                child: Stack(children: [
                  Positioned(
                    left: 16,
                    bottom: 18,
                    child: CircleButton(
                      icon: CupertinoIcons.arrow_left,
                      label: 'Назад',
                      size: 52,
                      iconSize: 22,
                      background: AppColors.surface,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(children: [
                        Reveal(scale: true, child: AppAvatar(name: s.fullName, imageUrl: s.image, size: 96)),
                        Transform.translate(
                          offset: const Offset(0, -12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.greenDeep,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text((s.company.isEmpty ? 'Link' : s.company).toUpperCase(),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Colors.white)),
                              const SizedBox(width: 4),
                              const Icon(CupertinoIcons.chevron_right, size: 12, color: Colors.white),
                            ]),
                          ),
                        ),
                        Text(s.fullName, style: AppText.cardTitle),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Анализ', style: AppText.title),
                const SizedBox(height: 8),
                Text(
                  'Нарушения одного сотрудника быстро становятся нормой для команды. Замечайте их на ранней стадии и разбирайтесь с причинами.',
                  style: AppText.label.copyWith(color: AppColors.ink3),
                ),
                const SizedBox(height: 14),
                MonthYearPicker(
                  month: _month,
                  onChanged: (m) {
                    setState(() => _month = m);
                    _load();
                  },
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  ErrorState(error: _error!, onRetry: _load)
                else if (_items == null)
                  const SkeletonCards(count: 2, height: 300)
                else if (_items!.isEmpty)
                  const EmptyState(
                    icon: CupertinoIcons.person_3,
                    title: 'Сотрудников нет',
                    message: 'Анализ появится, когда у сотрудников будут учётные записи.',
                  )
                else
                  for (final (i, e) in _items!.indexed) ...[
                    if (i > 0) const Divider(height: 40),
                    Reveal(index: i.clamp(0, 8), child: _EntryCard(entry: e)),
                  ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final DisciplineEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = entry.person;
    final badge = entry.score >= 80 ? AppColors.greenDeep : (entry.score >= 60 ? AppColors.amber : AppColors.red);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          AppAvatar(name: p.name, imageUrl: p.image, size: 64, border: false),
          Positioned(
            left: 0,
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(CupertinoIcons.circle_fill, size: 7, color: Colors.white),
                const SizedBox(width: 3),
                Text('${entry.score}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: AppText.bodyStrong.copyWith(fontSize: 15)),
            if (p.designation.isNotEmpty) Text(p.designation, style: AppText.label.copyWith(color: AppColors.ink3)),
            if (p.department.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.charcoal, borderRadius: BorderRadius.circular(4)),
                child: Text(p.department.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ]),
        ),
      ]),
      const SizedBox(height: 18),
      _Scale(code: 'SIP-A', topic: 'По опозданиям', degree: entry.lateDegree),
      _Scale(code: 'SIP-B', topic: 'За невыполнение чеклистов и задач', degree: entry.taskDegree),
      _Scale(code: 'SIP-C', topic: 'По пропускам', degree: entry.absenceDegree),
      const SizedBox(height: 4),
      Text(entry.findings.join('\n'), style: AppText.body.copyWith(height: 1.5)),
    ]);
  }
}

class _Scale extends StatelessWidget {
  const _Scale({required this.code, required this.topic, required this.degree});

  final String code;
  final String topic;
  final int degree;

  static const _stops = [AppColors.green, Color(0xFFC6D84F), Color(0xFFF2B63C), AppColors.red];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          degree == 0 ? 'Болезнь $code: не выявлена - $topic' : 'Болезнь $code: ${_degrees[degree]} степени - $topic',
          style: AppText.body,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          const dot = 26.0;
          final w = c.maxWidth;
          final step = (w - dot) / 3;
          return SizedBox(
            height: dot,
            child: Stack(alignment: Alignment.centerLeft, children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: dot / 2),
                height: 10,
                decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(5)),
              ),
              if (degree > 1)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: step * (degree - 1)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutQuart,
                  builder: (_, v, _) => Container(
                    margin: const EdgeInsets.only(left: dot / 2),
                    width: v,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: LinearGradient(colors: _stops.sublist(0, degree)),
                    ),
                  ),
                ),
              for (var k = 0; k < 4; k++)
                Positioned(
                  left: step * k,
                  child: Container(
                    width: dot,
                    height: dot,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: k < degree ? _stops[k] : AppColors.chip,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: k < degree
                        ? Text(_degrees[k + 1],
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white))
                        : null,
                  ),
                ),
            ]),
          );
        }),
      ]),
    );
  }
}
