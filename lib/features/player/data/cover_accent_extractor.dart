import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class CoverAccentExtractor {
  const CoverAccentExtractor();

  Future<Color?> extract(Uint8List? coverArt) async {
    if (coverArt == null || coverArt.isEmpty) {
      return null;
    }

    try {
      final image = await _decodeImage(coverArt);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (byteData == null) {
        return null;
      }

      return _dominantColorFromPixels(
        byteData.buffer.asUint8List(),
        image.width,
        image.height,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    return ui.instantiateImageCodec(
      bytes,
      targetWidth: 72,
      targetHeight: 72,
    ).then((codec) async {
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    });
  }

  Color? _dominantColorFromPixels(Uint8List pixels, int width, int height) {
    final buckets = <int, _ColorBucket>{};
    final totalPixels = width * height;
    final stride = max(1, totalPixels ~/ 12000);

    for (var pixelIndex = 0; pixelIndex < totalPixels; pixelIndex += stride) {
      final offset = pixelIndex * 4;
      if (offset + 3 >= pixels.length) {
        break;
      }

      final alpha = pixels[offset + 3];
      if (alpha < 180) {
        continue;
      }

      final red = pixels[offset];
      final green = pixels[offset + 1];
      final blue = pixels[offset + 2];
      final color = Color.fromARGB(255, red, green, blue);
      final hsl = HSLColor.fromColor(color);

      if (hsl.lightness < 0.12 ||
          hsl.lightness > 0.9 ||
          hsl.saturation < 0.18) {
        continue;
      }

      final key = ((red ~/ 32) << 10) | ((green ~/ 32) << 5) | (blue ~/ 32);
      final weight = 1 +
          (hsl.saturation * 2.4) +
          ((1 - (hsl.lightness - 0.55).abs()) * 0.8);
      buckets.update(
        key,
        (bucket) => bucket.add(red, green, blue, weight),
        ifAbsent: () => _ColorBucket(red, green, blue, weight),
      );
    }

    if (buckets.isEmpty) {
      return null;
    }

    final best = buckets.values.reduce((a, b) => a.score >= b.score ? a : b);
    final color = best.color;
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.42, 0.82))
        .withLightness(hsl.lightness.clamp(0.38, 0.62))
        .toColor();
  }
}

class _ColorBucket {
  _ColorBucket(int red, int green, int blue, double weight) {
    add(red, green, blue, weight);
  }

  double red = 0;
  double green = 0;
  double blue = 0;
  double weight = 0;
  double score = 0;

  _ColorBucket add(int r, int g, int b, double w) {
    red += r * w;
    green += g * w;
    blue += b * w;
    weight += w;
    score += w;
    return this;
  }

  Color get color {
    return Color.fromARGB(
      255,
      (red / weight).round().clamp(0, 255),
      (green / weight).round().clamp(0, 255),
      (blue / weight).round().clamp(0, 255),
    );
  }
}
