import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'crypto_service.dart';

const int _headerLength = CryptoService.headerLength;

class LsbService {
  static Future<Uint8List> embed(Uint8List sourceBytes, Uint8List payload) {
    return compute(_embedWorker, [sourceBytes, payload]);
  }

  static Future<Uint8List> extract(Uint8List imageBytes) {
    return compute(_extractWorker, imageBytes);
  }

  static int capacityBytes(Uint8List imageBytes) {
    final source = img.decodeImage(imageBytes);
    if (source == null) return 0;
    return ((source.width * source.height * 3) ~/ 8) - _headerLength - 16;
  }
}

Uint8List _embedWorker(List<Object> args) {
  final sourceBytes = args[0] as Uint8List;
  final payload = args[1] as Uint8List;
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const FormatException('This image could not be decoded.');
  }
  final image = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final capacity = (image.width * image.height * 3) ~/ 8;
  if (payload.length > capacity) {
    throw FormatException(
      'Message is too large for this image. Maximum payload: $capacity bytes.',
    );
  }

  final totalBits = payload.length * 8;
  var bitIndex = 0;
  final pixelCount = image.width * image.height;
  for (var pixelIndex = 0; pixelIndex < pixelCount && bitIndex < totalBits; pixelIndex++) {
    final x = pixelIndex % image.width;
    final y = pixelIndex ~/ image.width;
    final pixel = image.getPixel(x, y);
    var red = pixel.r.toInt();
    var green = pixel.g.toInt();
    var blue = pixel.b.toInt();
    if (bitIndex < totalBits) {
      red = _withNextBit(red, payload, bitIndex++);
    }
    if (bitIndex < totalBits) {
      green = _withNextBit(green, payload, bitIndex++);
    }
    if (bitIndex < totalBits) {
      blue = _withNextBit(blue, payload, bitIndex++);
    }
    image.setPixelRgba(x, y, red, green, blue, pixel.a.toInt());
  }
  return Uint8List.fromList(img.encodePng(image, level: 6));
}

int _withNextBit(int channel, Uint8List bytes, int bitIndex) {
  final bit = (bytes[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1;
  return (channel & 0xFE) | bit;
}

Uint8List _extractWorker(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    throw const FormatException('This image could not be decoded.');
  }
  final image = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final capacity = (image.width * image.height * 3) ~/ 8;
  if (capacity < _headerLength) {
    throw const FormatException('Image is too small to contain a StegoCrypt payload.');
  }

  final header = _readBytes(image, _headerLength, capacity);
  if (header[0] != 0x53 || header[1] != 0x54 || header[2] != 0x47 || header[3] != 0x43) {
    throw const FormatException('No StegoCrypt payload was found in this image.');
  }
  final dataLength = ByteData.sublistView(header).getUint32(43, Endian.big);
  final totalLength = _headerLength + dataLength;
  if (dataLength < 16 || totalLength > capacity) {
    throw const FormatException('The hidden payload length is invalid.');
  }
  return _readBytes(image, totalLength, capacity);
}

Uint8List _readBytes(img.Image image, int byteCount, int capacity) {
  if (byteCount > capacity) {
    throw const FormatException('The hidden payload is incomplete.');
  }
  final result = Uint8List(byteCount);
  var bitIndex = 0;
  final totalBits = byteCount * 8;
  final pixelCount = image.width * image.height;
  for (var pixelIndex = 0; pixelIndex < pixelCount && bitIndex < totalBits; pixelIndex++) {
    final pixel = image.getPixel(pixelIndex % image.width, pixelIndex ~/ image.width);
    for (final channel in [pixel.r, pixel.g, pixel.b]) {
      if (bitIndex >= totalBits) break;
      final bit = channel.toInt() & 1;
      result[bitIndex >> 3] |= bit << (7 - (bitIndex & 7));
      bitIndex++;
    }
  }
  if (bitIndex != totalBits) {
    throw const FormatException('The hidden payload is incomplete.');
  }
  return result;
}
