import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_icons.dart';

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
  bool _calibrating = false;
  String? _error;
  ShiftLocation? _office;
  String _step = '';
  String? _userAddress;
  String? _officeAddress;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadOffice();
  }

  Future<void> _loadOffice() async {
    try {
      final o = await Hr.shiftLocation();
      if (!mounted) return;
      setState(() => _office = o);
      if (o != null && o.hasPoint) {
        Hr.reverseGeocode(o.latitude, o.longitude).then((addr) {
          if (mounted && addr != null) setState(() => _officeAddress = addr);
        });
      }
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    // 1. Immediately read last known position for instant map rendering
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _position = last;
          _locationText = 'Уточняем GPS…';
        });
        Hr.reverseGeocode(last.latitude, last.longitude).then((addr) {
          if (mounted && addr != null) setState(() => _userAddress = addr);
        });
      }
    } catch (_) {}
    // 2. Fetch fresh high-precision GPS fix
    await _locate(fresh: true);
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
    if (!Session.instance.geolocationTracking ||
        d == null ||
        _office == null ||
        _office!.radius <= 0) {
      return false;
    }
    // Take indoor GPS accuracy margin into account
    final acc = _position?.accuracy ?? 0;
    final effectiveDist = math.max(0.0, d - acc);
    return effectiveDist > _office!.radius;
  }

  String _meters(double m) =>
      m < 1000 ? '${m.round()} м' : '${(m / 1000).toStringAsFixed(1)} км';

  Future<void> _locate({bool fresh = false}) async {
    if (!mounted) return;
    setState(() {
      _locating = true;
      if (fresh) _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _finishLocate(null, 'Службы геолокации выключены на устройстве');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _finishLocate(
          null,
          'Нет доступа к геолокации. Разрешите доступ в настройках iPhone.',
        );
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      );
      _finishLocate(p, 'Местоположение определено');
      Hr.reverseGeocode(p.latitude, p.longitude).then((addr) {
        if (mounted && addr != null) setState(() => _userAddress = addr);
      });
    } catch (_) {
      // If fresh fix timed out but we have a cached position, keep it
      if (_position != null) {
        _finishLocate(_position, 'Использована последняя известная геопозиция');
      } else {
        _finishLocate(
          null,
          'Не удалось определить GPS координаты. Попробуйте еще раз.',
        );
      }
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

  Future<void> _calibrateOffice() async {
    final p = _position;
    final o = _office;
    if (p == null) return;
    final officeName = o?.name ?? 'дом офис';
    final ok = await confirmAction(
      context,
      title: 'Калибровка офиса',
      message:
          'Установить текущую геопозицию (${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}) как координаты офиса «$officeName» с радиусом 300 м?',
      confirmLabel: 'Установить',
    );
    if (!ok || !mounted) return;
    setState(() => _calibrating = true);
    try {
      await Hr.updateShiftLocation(
        name: officeName,
        latitude: p.latitude,
        longitude: p.longitude,
        radius: 300,
      );
      final updated = (o ??
              ShiftLocation(
                name: officeName,
                radius: 300,
                latitude: p.latitude,
                longitude: p.longitude,
              ))
          .copyWith(latitude: p.latitude, longitude: p.longitude, radius: 300);
      if (mounted) {
        setState(() {
          _office = updated;
          _officeAddress = _userAddress;
          _calibrating = false;
        });
        showToast(context, 'Координаты офиса успешно обновлены!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _calibrating = false);
        showToast(context, 'Ошибка обновления: ${errorText(e)}', error: true);
      }
    }
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
    final isManager = s.isManager;
    final title = _locating && _position == null
        ? 'Проверяем ваше местоположение'
        : _position == null
        ? 'Местоположение не определено'
        : _outside
        ? 'Вы далеко от офиса'
        : 'Местоположение подтверждено';
    final subtitle = _locating && _position == null
        ? 'Подождите, проверяем ваше местоположение…'
        : _position == null
        ? _locationText
        : d == null
        ? 'Офис не назначен · Точность GPS ±${_position!.accuracy.round()} м'
        : _outside
        ? 'До «${_office!.name}» ${_meters(d)}. Отметка доступна в радиусе ${_meters(_office!.radius)}.'
        : 'В зоне офиса «${_office!.name}» (до центра ${_meters(d)})';
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              MiniMap(
                key: ValueKey(
                  '${_position?.latitude}_${_position?.longitude}_${_office?.latitude}_${_office?.radius}',
                ),
                userLat: _position?.latitude,
                userLon: _position?.longitude,
                userAccuracy: _position?.accuracy,
                officeLat: _office?.latitude,
                officeLon: _office?.longitude,
                officeRadius: _office?.radius,
                officeName: _office?.name,
                onRefresh: _locating ? null : () => _locate(fresh: true),
                isLocating: _locating,
              ),
              Positioned(
                left: 12,
                top: 12,
                child: CircleButton(
                  icon: AppIcons.arrowLeft,
                  label: 'Закрыть',
                  size: 44,
                  background: AppColors.surface,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                const SizedBox(height: 4),
                Text(subtitle, style: AppText.label),
                if (_locating && _position == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: _Dots()),
                  )
                else ...[
                  const SizedBox(height: 14),
                  // Location information details card
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_userAddress != null || _position != null)
                          _InfoRow(
                            icon: AppIcons.locationSolid,
                            label: 'Ваш адрес',
                            value: _userAddress ??
                                '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                          ),
                        if (_office != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: AppIcons.building2Fill,
                            label: 'Офис',
                            value: _officeAddress != null
                                ? '«${_office!.name}» (${_officeAddress!})'
                                : '«${_office!.name}» · радиус ${_meters(_office!.radius)}',
                          ),
                        ],
                        if (_position != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                AppIcons.clock,
                                size: 14,
                                color: AppColors.ink3,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Точность GPS: ±${_position!.accuracy.round()} м',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.ink3,
                                ),
                              ),
                              if (d != null) ...[
                                const Text(
                                  ' · ',
                                  style: TextStyle(color: AppColors.ink3),
                                ),
                                Text(
                                  'До офиса: ${_meters(d)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _outside
                                        ? AppColors.amber
                                        : AppColors.green,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_error != null) ...[
                  InlineError(_error!),
                  const SizedBox(height: 12),
                ],
                if (isManager && _position != null && _office != null) ...[
                  PrimaryButton(
                    label: '📍 Установить моё местоположение как офис',
                    kind: ButtonKind.soft,
                    loading: _calibrating,
                    height: 40,
                    onTap: _calibrateOffice,
                  ),
                  const SizedBox(height: 10),
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
                  icon: AppIcons.camera,
                  loading: _busy,
                  onTap: (_locating && _position == null && s.geolocationTracking) ||
                          (_outside && !isManager)
                      ? null
                      : _submit,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Селфи и GPS координаты сохранятся вместе с отметкой.',
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: AppColors.ink3),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.ink3,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
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
