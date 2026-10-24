import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageQuality {
  const ImageQuality({required this.psnr, required this.ssim});
  final double psnr;
  final double ssim;
}

class ImageMetrics {
  static Future<ImageQuality> compare(Uint8List original, Uint8List stego) async {
    final values = await compute(_measure, [original, stego]);
    return ImageQuality(psnr: values[0], ssim: values[1]);
  }
}

List<double> _measure(List<Object> args) {
  final original = img.decodeImage(args[0] as Uint8List);
  final stego = img.decodeImage(args[1] as Uint8List);
  if (original == null || stego == null || original.width != stego.width || original.height != stego.height) {
    throw const FormatException('Could not compare the source and output images.');
  }
  final a = original.convert(format: img.Format.uint8, numChannels: 3);
  final b = stego.convert(format: img.Format.uint8, numChannels: 3);
  var squaredError = 0.0;
  final sampleCount = a.width * a.height * 3;
  for (var y = 0; y < a.height; y++) {
    for (var x = 0; x < a.width; x++) {
      final p = a.getPixel(x, y);
      final q = b.getPixel(x, y);
      squaredError += _square(p.r.toDouble() - q.r.toDouble());
      squaredError += _square(p.g.toDouble() - q.g.toDouble());
      squaredError += _square(p.b.toDouble() - q.b.toDouble());
    }
  }
  final mse = squaredError / sampleCount;
  final psnr = mse == 0 ? double.infinity : 10 * (log10(255 * 255 / mse));
  return [psnr, _ssim(a, b)];
}

double _ssim(img.Image a, img.Image b) {
  const window = 8;
  const c1 = (0.01 * 255) * (0.01 * 255);
  const c2 = (0.03 * 255) * (0.03 * 255);
  var total = 0.0;
  var windows = 0;
  for (var top = 0; top < a.height; top += window) {
    for (var left = 0; left < a.width; left += window) {
      final right = left + window < a.width ? left + window : a.width;
      final bottom = top + window < a.height ? top + window : a.height;
      final first = <double>[];
      final second = <double>[];
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          first.add(_luminance(a.getPixel(x, y)));
          second.add(_luminance(b.getPixel(x, y)));
        }
      }
      final n = first.length;
      if (n == 0) continue;
      final meanA = first.reduce((x, y) => x + y) / n;
      final meanB = second.reduce((x, y) => x + y) / n;
      var varianceA = 0.0;
      var varianceB = 0.0;
      var covariance = 0.0;
      for (var i = 0; i < n; i++) {
        final da = first[i] - meanA;
        final db = second[i] - meanB;
        varianceA += da * da;
        varianceB += db * db;
        covariance += da * db;
      }
      final divisor = n > 1 ? n - 1 : 1;
      varianceA /= divisor;
      varianceB /= divisor;
      covariance /= divisor;
      final numerator = (2 * meanA * meanB + c1) * (2 * covariance + c2);
      final denominator = (meanA * meanA + meanB * meanB + c1) * (varianceA + varianceB + c2);
      total += numerator / denominator;
      windows++;
    }
  }
  return windows == 0 ? 1 : total / windows;
}

double _luminance(img.Pixel p) => 0.299 * p.r.toDouble() + 0.587 * p.g.toDouble() + 0.114 * p.b.toDouble();
double _square(double value) => value * value;
double log10(double value) => math.log(value) / math.ln10;
