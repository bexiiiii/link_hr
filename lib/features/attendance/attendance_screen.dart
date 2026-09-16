import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/checkin_photo.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

String hm(Object? t) {
  final parts = (t?.toString() ?? '').split(':');
  return parts.length >= 2 ? '${parts[0].padLeft(2, '0')}:${parts[1]}' : '';
}

class CheckinRow extends StatelessWidget {
  const CheckinRow({super.key, required this.log, this.showDate = true, this.photo, this.onAddPhoto});

  final Json log;
  final bool showDate;
  final String? photo;
  final VoidCallback? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final isIn = log['log_type'] == 'IN';
    final lat = log['latitude'];
    final hasCoords = lat != null && Fmt.number(lat) != 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        IconBadge(
          icon: isIn ? CupertinoIcons.square_arrow_right : CupertinoIcons.square_arrow_left,
          tone: isIn ? Tone.green : Tone.dark,
          size: 40,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isIn ? 'Приход' : 'Уход', style: AppText.bodyStrong),
            Text(
              [
                if (showDate) Fmt.weekdayDate(log['time']),
                if (hasCoords) 'с геолокацией',
              ].join(' · '),
              style: AppText.caption,
            ),
          ]),
        ),
        if (photo != null) ...[CheckinThumb(url: photo!), const SizedBox(width: 12)]
        else if (onAddPhoto != null && isIn) ...[
          IconButton(
            tooltip: 'Прикрепить фото',
            onPressed: onAddPhoto,
            icon: const Icon(CupertinoIcons.camera, size: 20, color: AppColors.ink3),
          ),
          const SizedBox(width: 4),
        ],
        Text(Fmt.time(log['time']), style: AppText.number.copyWith(fontSize: 15)),
      ]),
    );
  }
}
