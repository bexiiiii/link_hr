import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_icons.dart';

import 'theme.dart';
import 'ui.dart';

enum SelfieOutcome { taken, cancelled, denied, unavailable }

class SelfieResult {
  const SelfieResult(this.outcome, [this.bytes]);

  final SelfieOutcome outcome;
  final Uint8List? bytes;
}

/// Full-screen front camera with a corner frame, used right after tapping check-in.
/// Only the live camera: no gallery, no files.
Future<SelfieResult> takeSelfie(
  BuildContext context, {
  required String actionLabel,
}) async {
  final result = await Navigator.of(context, rootNavigator: true)
      .push<SelfieResult>(
        PageRouteBuilder(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, _, _) => _SelfieScreen(actionLabel: actionLabel),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
  return result ?? const SelfieResult(SelfieOutcome.cancelled);
}

class _SelfieScreen extends StatefulWidget {
  const _SelfieScreen({required this.actionLabel});

  final String actionLabel;

  @override
  State<_SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<_SelfieScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Uint8List? _shot;
  bool _capturing = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _shot == null) {
      _open();
    }
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted)
          Navigator.pop(context, const SelfieResult(SelfieOutcome.unavailable));
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _problem = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      if (e.code.contains('AccessDenied') ||
          e.code.contains('AccessRestricted')) {
        setState(() => _problem = 'denied');
      } else {
        Navigator.pop(context, const SelfieResult(SelfieOutcome.unavailable));
      }
    } catch (_) {
      if (mounted)
        Navigator.pop(context, const SelfieResult(SelfieOutcome.unavailable));
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _shot = bytes);
    } catch (e) {
      if (mounted)
        showToast(
          context,
          'Не удалось сделать снимок. Попробуйте ещё раз.',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.camera,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_shot != null)
              Image.memory(_shot!, fit: BoxFit.cover, gaplessPlayback: true)
            else if (c != null && c.value.isInitialized)
              _CoverPreview(controller: c)
            else if (_problem == null)
              const Center(
                child: CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 14,
                ),
              ),
            if (_problem == 'denied')
              _DeniedNotice(
                onClose: () => Navigator.pop(
                  context,
                  const SelfieResult(SelfieOutcome.denied),
                ),
              ),
            if (_problem == null) const _CornerFrame(),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 12,
                    child: CircleButton(
                      icon: AppIcons.chevronLeft,
                      label: 'Назад',
                      size: 48,
                      iconSize: 19,
                      onTap: () => Navigator.pop(
                        context,
                        const SelfieResult(SelfieOutcome.cancelled),
                      ),
                    ),
                  ),
                  if (_problem == null)
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 76,
                      child: Text(
                        _shot == null ? 'Селфи для отметки' : 'Проверьте фото',
                        textAlign: TextAlign.center,
                        style: AppText.heading.copyWith(color: Colors.white),
                      ),
                    ),
                  if (_problem == null)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 28,
                      child: _shot == null
                          ? Center(
                              child: Pressable(
                                onTap: _capture,
                                scale: 0.92,
                                semanticLabel: 'Сделать снимок',
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: AppColors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      width: 3,
                                    ),
                                  ),
                                  child: _capturing
                                      ? const CupertinoActivityIndicator(
                                          color: Colors.white,
                                        )
                                      : const Icon(
                                          AppIcons.viewfinder,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _GlassButton(
                                    label: 'Переснять',
                                    onTap: () => setState(() => _shot = null),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PrimaryButton(
                                    label: widget.actionLabel,
                                    onTap: () => Navigator.pop(
                                      context,
                                      SelfieResult(SelfieOutcome.taken, _shot),
                                    ),
                                  ),
                                ),
                              ],
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

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    // previewSize is reported in landscape; the phone is held in portrait.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CornerFrame extends StatelessWidget {
  const _CornerFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth - 40;
          final h = w * 1.25;
          return Center(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: CustomPaint(size: Size(w, h), painter: _CornerPainter()),
            ),
          );
        },
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 48.0;
    const r = 28.0;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    Path corner(Offset o, double dx, double dy) => Path()
      ..moveTo(o.dx, o.dy + dy * len)
      ..lineTo(o.dx, o.dy + dy * r)
      ..arcToPoint(
        Offset(o.dx + dx * r, o.dy),
        radius: const Radius.circular(r),
        clockwise: dx * dy > 0,
      )
      ..lineTo(o.dx + dx * len, o.dy);
    canvas.drawPath(corner(Offset.zero, 1, 1), paint);
    canvas.drawPath(corner(Offset(w, 0), -1, 1), paint);
    canvas.drawPath(corner(Offset(0, h), 1, -1), paint);
    canvas.drawPath(corner(Offset(w, h), -1, -1), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: AppText.bodyStrong.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _DeniedNotice extends StatelessWidget {
  const _DeniedNotice({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.camera, color: Colors.white, size: 40),
            const SizedBox(height: 16),
            Text(
              'Нет доступа к камере',
              style: AppText.heading.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Отметка сохраняется вместе с селфи. Разрешите доступ к камере: Настройки iPhone → Link HR → Камера.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            _GlassButton(label: 'Понятно', onTap: onClose),
          ],
        ),
      ),
    );
  }
}
