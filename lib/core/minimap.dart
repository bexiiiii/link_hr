import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_icons.dart';

import 'theme.dart';

/// Static OpenStreetMap view centred on a point, built from raster tiles.
/// Without a position it shows the region zoomed out, like a map loading.
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, this.latitude, this.longitude, this.height = 230});

  final double? latitude;
  final double? longitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    final located = latitude != null && longitude != null;
    final lat = latitude ?? 56.0;
    final lon = longitude ?? 80.0;
    final zoom = located ? 16 : 2;
    const tile = 256.0;
    final n = math.pow(2, zoom).toInt();
    final x = (lon + 180) / 360 * n;
    final latRad = lat * math.pi / 180;
    final y =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 *
        n;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final left = x * tile - w / 2;
          final top = y * tile - height / 2;
          final tiles = <Widget>[];
          for (
            var tx = (left / tile).floor();
            tx <= ((left + w) / tile).floor();
            tx++
          ) {
            for (
              var ty = (top / tile).floor();
              ty <= ((top + height) / tile).floor();
              ty++
            ) {
              if (ty < 0 || ty >= n) continue;
              final wrapped = ((tx % n) + n) % n;
              tiles.add(
                Positioned(
                  left: tx * tile - left,
                  top: ty * tile - top,
                  width: tile,
                  height: tile,
                  child: Image.network(
                    'https://tile.openstreetmap.org/$zoom/$wrapped/$ty.png',
                    headers: const {'User-Agent': 'LinkHR/1.0 (iOS)'},
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFFE3ECF2)),
                  ),
                ),
              );
            }
          }
          return ClipRect(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFFDCE8F0)),
                ),
                ...tiles,
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, -16),
                    child: Icon(
                      located ? AppIcons.locationSolid : AppIcons.location,
                      size: 36,
                      color: AppColors.red,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    color: const Color(0xCCFFFFFF),
                    child: const Text(
                      '© OpenStreetMap',
                      style: TextStyle(fontSize: 10, color: AppColors.ink2),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
