import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api.dart';
import 'files.dart';
import 'fmt.dart';
import 'theme.dart';
import 'ui.dart';

/// A file chosen on the device, not yet uploaded.
class PendingFile {
  PendingFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;

  String get meta {
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot + 1).toUpperCase() : '';
    return [Fmt.bytes(bytes.length), if (ext.isNotEmpty) ext].join(' • ');
  }

  Future<Attachment> upload(String doctype, String docname) async {
    final json = await Api.instance.uploadFile(bytes: bytes, fileName: name, doctype: doctype, docname: docname);
    json['file_size'] ??= bytes.length;
    return Attachment.fromJson(json);
  }
}

/// Camera, photo library or Files, the choices behind "Файл или фото".
Future<PendingFile?> pickAttachment(BuildContext context) async {
  final choice = await pickAction(context, title: 'Прикрепить', actions: const [
    SheetAction('camera', 'Сделать фото'),
    SheetAction('gallery', 'Выбрать из галереи'),
    SheetAction('file', 'Выбрать файл'),
  ]);
  if (choice == null) return null;
  try {
    if (choice == 'file') {
      final f = await FilePicker.pickFile();
      if (f == null) return null;
      return PendingFile(f.name, await f.readAsBytes());
    }
    final x = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 2400,
    );
    if (x == null) return null;
    return PendingFile(x.name, await x.readAsBytes());
  } catch (_) {
    if (context.mounted) {
      showToast(context, 'Нет доступа к камере или файлам. Разрешите доступ в настройках iPhone.', error: true);
    }
    return null;
  }
}

class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.child, this.onTap, this.height = 88, this.radius = AppRadius.field});

  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: CustomPaint(
        painter: _DashPainter(radius),
        child: SizedBox(height: height, width: double.infinity, child: Center(child: child)),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = AppColors.chipDot
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => false;
}

// Voice ---------------------------------------------------------------------

class VoiceClip {
  VoiceClip({required this.path, required this.duration, required this.wave});

  final String path;
  final Duration duration;
  final List<double> wave;

  Future<PendingFile> toPending() async =>
      PendingFile('voice_${DateTime.now().millisecondsSinceEpoch}.m4a', await File(path).readAsBytes());
}

String clockOf(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

List<double> fakeWave(String seed, [int count = 44]) {
  final r = math.Random(seed.hashCode);
  return List.generate(count, (_) => 0.2 + r.nextDouble() * 0.8);
}

class VoiceRecorder {
  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amp;
  final List<double> samples = [];
  DateTime? _startedAt;
  bool recording = false;
  VoidCallback? onTick;

  Duration get elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(numChannels: 1, bitRate: 64000), path: path);
    samples.clear();
    _startedAt = DateTime.now();
    recording = true;
    _amp = _recorder.onAmplitudeChanged(const Duration(milliseconds: 110)).listen((a) {
      samples.add(((a.current + 45) / 45).clamp(0.08, 1.0));
      onTick?.call();
    });
    return true;
  }

  Future<VoiceClip?> stop() async {
    await _amp?.cancel();
    final duration = elapsed;
    final path = await _recorder.stop();
    recording = false;
    if (path == null || duration.inMilliseconds < 700) return null;
    return VoiceClip(path: path, duration: duration, wave: _downsample(samples, 44));
  }

  Future<void> cancel() async {
    await _amp?.cancel();
    recording = false;
    await _recorder.cancel();
  }

  void dispose() {
    _amp?.cancel();
    _recorder.dispose();
  }

  static List<double> _downsample(List<double> src, int n) {
    if (src.isEmpty) return List.filled(n, 0.2);
    return List.generate(n, (i) {
      final start = (i * src.length / n).floor();
      final end = math.max(start + 1, ((i + 1) * src.length / n).floor());
      final slice = src.sublist(start, math.min(end, src.length));
      return slice.isEmpty ? 0.2 : slice.reduce(math.max);
    });
  }
}

class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.values, this.progress = 0, this.height = 30});

  final List<double> values;
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(double.infinity, height), painter: _WavePainter(values, progress));
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.values, this.progress);

  final List<double> values;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final step = size.width / values.length;
    final played = Paint()
      ..color = AppColors.ink
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.min(3, step * 0.55);
    final rest = Paint()
      ..color = AppColors.ink4
      ..strokeCap = StrokeCap.round
      ..strokeWidth = played.strokeWidth;
    for (var i = 0; i < values.length; i++) {
      final x = step * i + step / 2;
      final h = math.max(3.0, values[i] * size.height);
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2),
          i / values.length <= progress ? played : rest);
    }
    final dotX = (size.width * progress).clamp(4.0, size.width - 4);
    canvas.drawCircle(Offset(dotX, size.height / 2), 5, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.progress != progress || old.values != values;
}

/// Play button + waveform + "00:00:08", for local recordings or attachments.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, this.localPath, this.remote, this.wave, this.duration, this.onDelete});

  final String? localPath;
  final Attachment? remote;
  final List<double>? wave;
  final Duration? duration;
  final VoidCallback? onDelete;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];
  String? _path;
  Duration _position = Duration.zero;
  late Duration _duration = widget.duration ?? Duration.zero;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _path = widget.localPath;
    _subs
      ..add(_player.onPositionChanged.listen((p) => setState(() => _position = p)))
      ..add(_player.onDurationChanged.listen((d) => setState(() => _duration = d)))
      ..add(_player.onPlayerComplete.listen((_) => setState(() {
            _playing = false;
            _position = Duration.zero;
          })));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    try {
      if (_path == null && widget.remote != null) {
        setState(() => _loading = true);
        final bytes = await Api.instance.download(widget.remote!.url);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.remote!.name}_${widget.remote!.fileName}');
        await file.writeAsBytes(bytes, flush: true);
        _path = file.path;
      }
      if (_path == null) return;
      await _player.play(DeviceFileSource(_path!), position: _position);
      if (mounted) setState(() => _playing = true);
    } catch (e) {
      if (mounted) showToast(context, 'Не удалось воспроизвести запись', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wave = widget.wave ?? fakeWave(widget.remote?.name ?? widget.localPath ?? 'voice');
    final progress = _duration.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / _duration.inMilliseconds;
    return Row(children: [
      Pressable(
        onTap: _toggle,
        scale: 0.9,
        semanticLabel: _playing ? 'Пауза' : 'Воспроизвести голосовое описание',
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 2)),
          child: _loading
              ? const CupertinoActivityIndicator()
              : Icon(_playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, size: 20, color: AppColors.ink),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Waveform(values: wave, progress: progress.clamp(0, 1)),
          const SizedBox(height: 2),
          Text(clockOf(_playing || _position > Duration.zero ? _position : _duration),
              style: AppText.caption.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
      if (widget.onDelete != null)
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(40, 40),
          onPressed: widget.onDelete,
          child: const Icon(CupertinoIcons.trash, size: 20, color: AppColors.red),
        ),
    ]);
  }
}

/// Record-or-play control used in the task form.
class VoiceField extends StatefulWidget {
  const VoiceField({super.key, required this.clip, required this.onChanged, this.remote});

  final VoiceClip? clip;
  final Attachment? remote;
  final ValueChanged<VoiceClip?> onChanged;

  @override
  State<VoiceField> createState() => _VoiceFieldState();
}

class _VoiceFieldState extends State<VoiceField> {
  final _recorder = VoiceRecorder();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _recorder.onTick = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    final ok = await _recorder.start();
    if (!ok) {
      if (mounted) showToast(context, 'Разрешите доступ к микрофону в настройках iPhone', error: true);
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final clip = await _recorder.stop();
    if (!mounted) return;
    setState(() {});
    if (clip == null) {
      showToast(context, 'Запись слишком короткая', error: true);
    } else {
      widget.onChanged(clip);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recorder.recording) {
      final live = _recorder.samples.length > 44
          ? _recorder.samples.sublist(_recorder.samples.length - 44)
          : [..._recorder.samples, ...List.filled(44 - _recorder.samples.length, 0.08)];
      return Row(children: [
        Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(clockOf(_recorder.elapsed), style: AppText.number),
        const SizedBox(width: 12),
        Expanded(child: Waveform(values: live, progress: 1, height: 26)),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onPressed: () async {
            _timer?.cancel();
            await _recorder.cancel();
            if (mounted) setState(() {});
          },
          child: const Text('Отмена', style: TextStyle(fontSize: 14, color: AppColors.ink3)),
        ),
        CircleButton(
          icon: CupertinoIcons.stop_fill,
          label: 'Остановить запись',
          background: AppColors.charcoal,
          foreground: Colors.white,
          size: 44,
          iconSize: 18,
          onTap: _stop,
        ),
      ]);
    }
    if (widget.clip != null) {
      return VoicePlayer(
        key: ValueKey(widget.clip!.path),
        localPath: widget.clip!.path,
        wave: widget.clip!.wave,
        duration: widget.clip!.duration,
        onDelete: () => widget.onChanged(null),
      );
    }
    if (widget.remote != null) {
      return VoicePlayer(key: ValueKey(widget.remote!.name), remote: widget.remote);
    }
    return Pressable(
      onTap: _start,
      semanticLabel: 'Записать голосовое описание',
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(color: AppColors.charcoal, shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.mic_fill, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Записать голосом', style: AppText.bodyStrong),
            Text('Нажмите и опишите задачу своими словами', style: AppText.caption),
          ]),
        ),
      ]),
    );
  }
}
