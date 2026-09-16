import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/hr.dart';
import 'api.dart';
import 'media.dart';
import 'session.dart';
import 'theme.dart';
import 'ui.dart';

/// Private image from the server, sent with the session cookie.
class ServerImage extends StatelessWidget {
  const ServerImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.network(
    Api.instance.fileUrl(url),
    headers: Api.instance.authHeaders,
    fit: fit,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: AppColors.chip,
      child: Center(child: Icon(CupertinoIcons.photo, color: AppColors.ink3)),
    ),
  );
}

void showPhoto(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: InteractiveViewer(
        child: Center(child: ServerImage(url, fit: BoxFit.contain)),
      ),
    ),
  );
}

/// Picks a photo and attaches it to a check-in. Returns the file URL.
Future<String?> addCheckinPhoto(BuildContext context, String checkin) async {
  final f = await pickAttachment(context);
  if (f == null) return null;
  try {
    final url = await Hr.attachCheckinPhoto(checkin, f.bytes, f.name);
    if (context.mounted) showToast(context, 'Фото прикреплено');
    Session.instance.notifyDataChanged();
    return url;
  } catch (e) {
    if (context.mounted) showToast(context, errorText(e), error: true);
    return null;
  }
}

class CheckinThumb extends StatelessWidget {
  const CheckinThumb({super.key, required this.url, this.size = 44});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => showPhoto(context, url),
    semanticLabel: 'Открыть фото',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: ServerImage(url)),
    ),
  );
}
