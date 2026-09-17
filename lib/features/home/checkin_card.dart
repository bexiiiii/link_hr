import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/minimap.dart';
import '../../core/selfie_camera.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';

class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet({required this.logType});

  final String logType;

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  Position? _position;
  String _locationText = 'Определяем местоположение…';
  bool _locating = true;
  bool _busy = false;
  String? _error;
  ShiftLocation? _office;
  String _step = '';

  @override
  void initState() {
    super.initState();
    _locate();
    Hr.shiftLocation()
        .then((o) {
          if (mounted) setState(() => _office = o);
        })
        .catchError((_) {});
  }

  double? get _distance {
    final o = _office, p = _position;
    if (o == null || p == null || !o.hasPoint) return null;
    return Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      o.latitude,
      o.longitude,
    );
  }

  bool get _outside {
    final d = _distance;
    return Session.instance.geolocationTracking &&
        d != null &&
        _office!.radius > 0 &&
        d > _office!.radius;
  }

  String _meters(double m) =>
      m < 1000 ? '${m.round()} м' : '${(m / 1000).toStringAsFixed(1)} км';

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _finishLocate(null, 'Службы геолокации выключены');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _finishLocate(null, 'Нет доступа к геолокации');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
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

  /// Selfie first, then the check-in with the photo attached. No photo means
  /// no check-in, including on devices where the camera is unavailable.
  Future<void> _submit() async {
    final isIn = widget.logType == 'IN';
    setState(() => _error = null);
    final selfie = await takeSelfie(
      context,
      actionLabel: isIn ? 'Отметить приход' : 'Отметить уход',
    );
    if (!mounted) return;
    if (selfie.outcome == SelfieOutcome.cancelled) return;
    if (selfie.outcome == SelfieOutcome.denied) {
      setState(
        () => _error =
            'Без селфи отметиться нельзя. Разрешите доступ к камере в настройках iPhone.',
      );
      return;
    }
    if (selfie.bytes == null) {
      setState(
        () => _error =
            'Не удалось сделать селфи. Проверьте доступ к фронтальной камере и повторите попытку.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _step = 'Сохраняем отметку…';
    });
    try {
      final doc = await Hr.checkin(
        widget.logType,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
      );
      final name = doc['name']?.toString();
      if (name != null) {
        if (mounted) setState(() => _step = 'Загружаем селфи…');
        try {
          await Hr.attachCheckinPhoto(name, selfie.bytes!, 'selfie.jpg');
        } catch (e) {
          if (mounted)
            showToast(
              context,
              'Отметка сохранена, но селфи не загрузилось: ${errorText(e)}',
              error: true,
            );
        }
      }
      Session.instance.notifyDataChanged();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _step = '';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.logType == 'IN';
    final s = Session.instance;
    final d = _distance;
    final title = _locating
        ? 'Проверяем ваше местоположение'
        : _position == null
        ? 'Местоположение не определено'
        : _outside
        ? 'Вы далеко от офиса'
        : 'Местоположение подтверждено';
    final subtitle = _locating
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
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
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: AppText.heading,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: AppText.label),
                if (_locating)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: _Dots()),
                  )
                else
                  const SizedBox(height: 18),
                if (_error != null) ...[
                  InlineError(_error!),
                  const SizedBox(height: 12),
                ],
                if (_busy && _step.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_step, style: AppText.label),
                  ),
                PrimaryButton(
                  label: isIn
                      ? 'Сделать селфи и отметиться'
                      : 'Сделать селфи и уйти',
                  icon: CupertinoIcons.camera,
                  loading: _busy,
                  onTap: (_locating && s.geolocationTracking) || _outside
                      ? null
                      : _submit,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Селфи сохранится вместе с отметкой.',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
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

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.ink3.withValues(
                  alpha: (_c.value * 3).floor() % 3 == i ? 0.9 : 0.3,
                ),
              ),
            ),
        ],
      ),
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CheckinSheet(logType: logType),
  );
  if (done == true && context.mounted) {
    showToast(
      context,
      logType == 'IN' ? 'Рабочий день начат' : 'Рабочий день завершён',
    );
  }
  return done == true;
}
