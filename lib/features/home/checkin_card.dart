import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/media.dart';
import '../../core/minimap.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../attendance/checkin_history_screen.dart';

class CheckinCard extends StatefulWidget {
  const CheckinCard({super.key, required this.lastLog, required this.loading});

  final Json? lastLog;
  final bool loading;

  @override
  State<CheckinCard> createState() => _CheckinCardState();
}

class _CheckinCardState extends State<CheckinCard> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  bool get _onShift => widget.lastLog?['log_type'] == 'IN';

  Future<void> _start() async {
    final logType = _onShift ? 'OUT' : 'IN';
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _CheckinSheet(logType: logType),
    );
    if (done == true && mounted) {
      showToast(context, logType == 'IN' ? 'Приход отмечен' : 'Уход отмечен');
      Session.instance.notifyDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.lastLog;
    final (statusText, tone) = switch (last?['log_type']) {
      'IN' => ('На смене с ${Fmt.time(last!['time'])}', Tone.green),
      'OUT' => ('Смена закрыта в ${Fmt.time(last!['time'])}', Tone.dark),
      _ => ('Смена ещё не начата', Tone.neutral),
    };
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Сейчас', style: AppText.caption),
              const SizedBox(height: 2),
              Text(Fmt.clock(_now),
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                    color: AppColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
            ]),
          ),
          CircleButton(
            icon: CupertinoIcons.clock,
            label: 'История отметок',
            background: AppColors.bg,
            onTap: () => pushPage(context, const CheckinHistoryScreen()),
          ),
        ]),
        const SizedBox(height: 10),
        widget.loading && last == null
            ? const Skeleton(height: 16, width: 160)
            : Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tone == Tone.neutral ? AppColors.ink4 : tone.solid,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(statusText, style: AppText.label),
              ]),
        const SizedBox(height: 18),
        PrimaryButton(
          label: _onShift ? 'Отметить уход' : 'Отметить приход',
          icon: _onShift ? CupertinoIcons.square_arrow_left : CupertinoIcons.square_arrow_right,
          kind: _onShift ? ButtonKind.dark : ButtonKind.green,
          onTap: widget.loading ? null : _start,
        ),
      ]),
    );
  }
}

class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet({required this.logType});

  final String logType;

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  final DateTime _time = DateTime.now();
  Position? _position;
  String _locationText = 'Определяем местоположение…';
  bool _locating = true;
  bool _busy = false;
  String? _error;
  ShiftLocation? _office;
  String? _checkinName;
  PendingFile? _photo;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _locate();
    Hr.shiftLocation().then((o) {
      if (mounted) setState(() => _office = o);
    }).catchError((_) {});
  }

  double? get _distance {
    final o = _office, p = _position;
    if (o == null || p == null || !o.hasPoint) return null;
    return Geolocator.distanceBetween(p.latitude, p.longitude, o.latitude, o.longitude);
  }

  bool get _outside {
    final d = _distance;
    return Session.instance.geolocationTracking && d != null && _office!.radius > 0 && d > _office!.radius;
  }

  String _meters(double m) => m < 1000 ? '${m.round()} м' : '${(m / 1000).toStringAsFixed(1)} км';

  Future<void> _addPhoto() async {
    final f = await pickAttachment(context);
    if (f == null || _checkinName == null) return;
    setState(() {
      _photo = f;
      _uploading = true;
      _error = null;
    });
    try {
      await Hr.attachCheckinPhoto(_checkinName!, f.bytes, f.name);
      Session.instance.notifyDataChanged();
    } catch (e) {
      if (mounted) setState(() {
        _photo = null;
        _error = errorText(e);
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _finishLocate(null, 'Службы геолокации выключены');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _finishLocate(null, 'Нет доступа к геолокации');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      _finishLocate(p, 'Местоположение определено');
    } catch (_) {
      _finishLocate(null, 'Не удалось определить местоположение');
    }
  }

  void _finishLocate(Position? p, String text) {
    if (!mounted) return;
    setState(() {
      _position = p;
      _locationText = text;
      _locating = false;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final doc = await Hr.checkin(widget.logType, latitude: _position?.latitude, longitude: _position?.longitude);
      Session.instance.notifyDataChanged();
      if (mounted) setState(() => _checkinName = doc['name']?.toString());
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.logType == 'IN';
    final s = Session.instance;
    final done = _checkinName != null;
    final d = _distance;
    final title = done
        ? (isIn ? 'Вы отметили приход в ${Fmt.time(_time)}' : 'Вы отметили уход в ${Fmt.time(_time)}')
        : _locating
            ? 'Проверяем ваше местоположение'
            : _position == null
                ? 'Местоположение не определено'
                : _outside
                    ? 'Вы далеко от офиса'
                    : 'Местоположение подтверждено';
    final subtitle = done
        ? 'Прикрепите фото с рабочего места, если его требует руководитель.'
        : _locating
            ? 'Подождите, проверяем ваше местоположение…'
            : _position == null
                ? _locationText
                : d == null
                    ? 'Точность до ${_position!.accuracy.round()} м'
                    : _outside
                        ? 'До «${_office!.name}» ${_meters(d)}. Отметиться можно в радиусе ${_meters(_office!.radius)}.'
                        : 'До «${_office!.name}» ${_meters(d)}, точность ${_position!.accuracy.round()} м';
    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: MiniMap(
              key: ValueKey(_position == null),
              latitude: _position?.latitude,
              longitude: _position?.longitude,
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: CircleButton(
              icon: CupertinoIcons.arrow_left,
              label: 'Закрыть',
              size: 44,
              background: AppColors.surface,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(title, key: ValueKey(title), style: AppText.heading),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: AppText.label),
            if (_locating)
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: _Dots()))
            else
              const SizedBox(height: 18),
            if (_error != null) ...[InlineError(_error!), const SizedBox(height: 12)],
            if (done) ...[
              if (isIn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DashedBox(
                    height: 72,
                    onTap: _uploading || _photo != null ? null : _addPhoto,
                    child: _uploading
                        ? const CupertinoActivityIndicator()
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_photo == null ? CupertinoIcons.camera : CupertinoIcons.checkmark_alt,
                                size: 20, color: _photo == null ? AppColors.ink3 : AppColors.greenDeep),
                            const SizedBox(width: 8),
                            Text(_photo == null ? 'Прикрепить фото' : 'Фото прикреплено',
                                style: AppText.body.copyWith(color: _photo == null ? AppColors.ink3 : AppColors.greenDeep)),
                          ]),
                  ),
                ),
              PrimaryButton(label: 'Готово', onTap: _uploading ? null : () => Navigator.pop(context, true)),
            ] else
              PrimaryButton(
                label: isIn ? 'Я на работе' : 'Завершить рабочий день',
                loading: _busy,
                onTap: (_locating && s.geolocationTracking) || _outside ? null : _submit,
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ink3.withValues(alpha: (_c.value * 3).floor() % 3 == i ? 0.9 : 0.3),
            ),
          ),
      ]),
    );
  }
}

/// Opens the check-in / check-out confirmation sheet. Returns true when saved.
Future<bool> showCheckinSheet(BuildContext context, String logType) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (_) => _CheckinSheet(logType: logType),
  );
  if (done == true && context.mounted) {
    showToast(context, logType == 'IN' ? 'Рабочий день начат' : 'Рабочий день завершён');
  }
  return done == true;
}
