import 'dart:typed_data';

import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    required this.accent,
    this.coverArt,
    this.size,
    this.borderRadius = 18,
    super.key,
  });

  final Color accent;
  final Uint8List? coverArt;
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(borderRadius);
    final image = coverArt;
    final art = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: border,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            Color.lerp(accent, Colors.black, 0.48)!,
            const Color(0xFF20232B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            ClipRRect(
              borderRadius: border,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final decodeSize = _decodeSizeFor(
                    context,
                    constraints.biggest,
                  );
                  return Image.memory(
                    image,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: decodeSize,
                    cacheHeight: decodeSize,
                    filterQuality: FilterQuality.medium,
                  );
                },
              ),
            )
          else ...[
            Positioned(
              right: -28,
              top: -18,
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 150,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            const Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Icon(
                  Icons.album_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (size == null) {
      return AspectRatio(aspectRatio: 1, child: art);
    }

    return SizedBox.square(dimension: size, child: art);
  }

  int _decodeSizeFor(BuildContext context, Size constraintsSize) {
    final logicalSize = constraintsSize.shortestSide.isFinite &&
            constraintsSize.shortestSide > 0
        ? constraintsSize.shortestSide
        : (size ?? 360);
    final devicePixels = logicalSize * MediaQuery.devicePixelRatioOf(context);
    return devicePixels.clamp(160, 560).round();
  }
}
