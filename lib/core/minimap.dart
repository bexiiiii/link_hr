import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'app_icons.dart';
import 'theme.dart';
import 'ui.dart';

/// A current team position from Employee Checkin. The server decides whether
/// the active HR role can read these entries.
class TeamMapMarker {
  const TeamMapMarker({
    required this.latitude,
    required this.longitude,
    required this.name,
    this.imageUrl,
  });

  final double latitude;
  final double longitude;
  final String name;
  final String? imageUrl;
}

/// Interactive OpenStreetMap view supporting:
/// - User live location (Apple-style blue pulsing dot + accuracy halo)
/// - Office location marker + geofence boundary circle (violet tint)
/// - Auto-fitting zoom and center based on both points
/// - Quick GPS refresh button
class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    this.latitude,
    this.longitude,
    this.userLat,
    this.userLon,
    this.userAccuracy,
    this.officeLat,
    this.officeLon,
    this.officeRadius,
    this.officeName,
    this.height = 240,
    this.onRefresh,
    this.isLocating = false,
    this.team = const [],
  });

  /// Backward-compatible alias for user location
  final double? latitude;
  final double? longitude;
  final double? userLat;
  final double? userLon;
  final double? userAccuracy;

  /// Office location parameters
  final double? officeLat;
  final double? officeLon;
  final double? officeRadius;
  final String? officeName;

  final double height;
  final VoidCallback? onRefresh;
  final bool isLocating;
  final List<TeamMapMarker> team;

  @override
  Widget build(BuildContext context) {
    final uLat = userLat ?? latitude;
    final uLon = userLon ?? longitude;
    final hasUser = uLat != null && uLon != null;
    final hasOffice =
        officeLat != null &&
        officeLon != null &&
        (officeLat != 0 || officeLon != 0);

    double centerLat = 51.089;
    double centerLon = 71.425;
    int zoom = 16;

    if (hasUser && hasOffice) {
      final d = Geolocator.distanceBetween(uLat, uLon, officeLat!, officeLon!);
      centerLat = (uLat + officeLat!) / 2;
      centerLon = (uLon + officeLon!) / 2;
      if (d > 2500) {
        zoom = 13;
      } else if (d > 1000) {
        zoom = 14;
      } else if (d > 400) {
        zoom = 15;
      } else {
        zoom = 16;
      }
    } else if (hasUser) {
      centerLat = uLat;
      centerLon = uLon;
      zoom = 16;
    } else if (hasOffice) {
      centerLat = officeLat!;
      centerLon = officeLon!;
      zoom = 16;
    } else {
      zoom = 13;
    }

    // Adjust zoom if office radius is very large
    if (hasOffice && (officeRadius ?? 0) > 0) {
      if (officeRadius! > 350 && zoom > 15) {
        zoom = 15;
      }
      if (officeRadius! > 800 && zoom > 14) {
        zoom = 14;
      }
    }

    final n = math.pow(2, zoom).toInt();
    const tile = 256.0;
    final centerX = (centerLon + 180) / 360 * n;
    final centerLatRad = centerLat * math.pi / 180;
    final centerY =
        (1 -
            math.log(math.tan(centerLatRad) + 1 / math.cos(centerLatRad)) /
                math.pi) /
        2 *
        n;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final left = centerX * tile - w / 2;
          final top = centerY * tile - height / 2;

          Offset toScreen(double lat, double lon) {
            final px = ((lon + 180) / 360 * n) * tile - left;
            final r = lat * math.pi / 180;
            final py =
                ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) /
                        2 *
                        n) *
                    tile -
                top;
            return Offset(px, py);
          }

          final metersPerPx =
              40075016.686 * math.cos(centerLatRad) / (n * tile);

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

          Widget? officeCircle;
          Widget? officeMarker;
          if (hasOffice) {
            final oPos = toScreen(officeLat!, officeLon!);
            final rad = officeRadius ?? 0;
            if (rad > 0) {
              final radiusPx = rad / metersPerPx;
              officeCircle = Positioned(
                left: oPos.dx - radiusPx,
                top: oPos.dy - radiusPx,
                width: radiusPx * 2,
                height: radiusPx * 2,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.violet.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.violet.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              );
            }
            officeMarker = Positioned(
              left: oPos.dx - 32,
              top: oPos.dy - 34,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.violet,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            AppIcons.building2Fill,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            officeName ?? 'Офис',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      size: const Size(8, 5),
                      painter: _TrianglePainter(color: AppColors.violet),
                    ),
                  ],
                ),
              ),
            );
          }

          Widget? userMarker;
          if (hasUser) {
            final uPos = toScreen(uLat, uLon);
            final accPx = ((userAccuracy ?? 15) / metersPerPx).clamp(
              10.0,
              48.0,
            );
            userMarker = Stack(
              children: [
                Positioned(
                  left: uPos.dx - accPx,
                  top: uPos.dy - accPx,
                  width: accPx * 2,
                  height: accPx * 2,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF007AFF).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: uPos.dx - 9,
                  top: uPos.dy - 9,
                  child: IgnorePointer(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF007AFF),
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final teamMarkers = <Widget>[
            for (final person in team)
              Positioned(
                left: toScreen(person.latitude, person.longitude).dx - 18,
                top: toScreen(person.latitude, person.longitude).dy - 18,
                child: IgnorePointer(
                  child: Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: AppAvatar(
                      name: person.name,
                      imageUrl: person.imageUrl,
                      size: 32,
                      border: false,
                    ),
                  ),
                ),
              ),
          ];

          Widget? statusChip;
          if (hasUser && hasOffice) {
            final d = Geolocator.distanceBetween(
              uLat,
              uLon,
              officeLat!,
              officeLon!,
            );
            final inZone =
                (officeRadius ?? 0) > 0 &&
                d <= (officeRadius! + (userAccuracy ?? 0));
            statusChip = Positioned(
              left: 12,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: inZone
                      ? const Color(0xE6E8F5E9)
                      : const Color(0xE6FFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: inZone
                        ? AppColors.green.withValues(alpha: 0.5)
                        : AppColors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      inZone
                          ? AppIcons.checkmarkCircleFill
                          : AppIcons.exclamationmarkCircle,
                      size: 13,
                      color: inZone ? AppColors.green : AppColors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      inZone
                          ? 'В зоне офиса · ${d.round()} м'
                          : '${d.round()} м до офиса',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: inZone
                            ? AppColors.green
                            : const Color(0xFFB76E00),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ClipRect(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFFDCE8F0)),
                ),
                ...tiles,
                if (officeCircle != null) officeCircle,
                if (officeMarker != null) officeMarker,
                if (userMarker != null) userMarker,
                ...teamMarkers,
                if (!hasUser && !hasOffice)
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, -16),
                      child: const Icon(
                        AppIcons.location,
                        size: 36,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                if (statusChip != null) statusChip,
                if (onRefresh != null)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: GestureDetector(
                      onTap: isLocating ? null : onRefresh,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isLocating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppColors.violet,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  CupertinoIcons.arrow_clockwise,
                                  size: 18,
                                  color: AppColors.ink,
                                ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCCFFFFFF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap',
                      style: TextStyle(fontSize: 9, color: AppColors.ink3),
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

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
