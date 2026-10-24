import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'crypto_service.dart';

const int _tagLength = 16;

class LsbService {
  static Future<Uint8List> embed(Uint8List sourceBytes, Uint8List payload) =>
      compute(_embedWorker, [sourceBytes, payload]);

  static Future<Uint8List> extract(Uint8List imageBytes) =>
      compute(_extractWorker, imageBytes);

  static Future<int> capacityBytes(Uint8List imageBytes, {required StegoMode mode}) =>
      compute(_capacityWorker, [imageBytes, mode.index]);
}

int _capacityWorker(List<Object> args) {
    final imageBytes = args[0] as Uint8List;
    final mode = StegoMode.values[args[1] as int];
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return 0;
    final image = decoded.convert(format: img.Format.uint8, numChannels: 4);
    final headerBits = CryptoService.headerLength * 8;
    final slots = image.width * image.height * 3;
    final bodySlots = mode == StegoMode.classicLsb
        ? slots - headerBits
        : _edgeSlotCount(image, skipBefore: headerBits);
    return ((bodySlots ~/ 8) - _tagLength).clamp(0, 1 << 30);
}

Uint8List _embedWorker(List<Object> args) {
  final sourceBytes = args[0] as Uint8List;
  final payload = args[1] as Uint8List;
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) throw const FormatException('This image could not be decoded.');
  final image = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final version = payload.length > 4 ? payload[4] : 0;
  final headerLength = CryptoService.headerSizeForVersion(version);
  if (payload.length < headerLength) throw const FormatException('The encrypted payload is incomplete.');
  final mode = CryptoService.modeFromEnvelope(payload);
  final headerBits = headerLength * 8;
  final bodyLength = payload.length - headerLength;
  final totalSlots = image.width * image.height * 3;
  final available = mode == StegoMode.classicLsb
      ? totalSlots - headerBits
      : _edgeSlotCount(image, skipBefore: headerBits);
  if (bodyLength * 8 > available) {
    throw const FormatException('Message is too large for this image and embedding mode. Choose a larger image or Classic LSB.');
  }

  _writeSequential(image, payload.sublist(0, headerLength), 0);
  final body = payload.sublist(headerLength);
  if (mode == StegoMode.classicLsb) {
    _writeSequential(image, body, headerBits);
  } else {
    _writeOnEdges(image, body, headerBits);
  }
  return Uint8List.fromList(img.encodePng(image, level: 6));
}

Uint8List _extractWorker(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) throw const FormatException('This image could not be decoded.');
  final image = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final slots = image.width * image.height * 3;
  if (slots < 8 * CryptoService.legacyHeaderLength) {
    throw const FormatException('Image is too small to contain a StegoCrypt payload.');
  }

  final prefix = _readSequential(image, 5, 0);
  if (prefix[0] != 0x53 || prefix[1] != 0x54 || prefix[2] != 0x47 || prefix[3] != 0x43) {
    throw const FormatException('No StegoCrypt payload was found in this image.');
  }
  final headerLength = CryptoService.headerSizeForVersion(prefix[4]);
  final headerBits = headerLength * 8;
  if (slots < headerBits) throw const FormatException('Image is too small to contain the protocol header.');
  final header = _readSequential(image, headerLength, 0);
  final bodyLength = CryptoService.encryptedLengthFromHeader(header);
  final bodySlots = CryptoService.modeFromEnvelope(header) == StegoMode.classicLsb
      ? slots - headerBits
      : _edgeSlotCount(image, skipBefore: headerBits);
  if (bodyLength < _tagLength || bodyLength * 8 > bodySlots) {
    throw const FormatException('The hidden payload is incomplete or invalid.');
  }
  final mode = CryptoService.modeFromEnvelope(header);
  final body = mode == StegoMode.classicLsb
      ? _readSequential(image, bodyLength, headerBits)
      : _readFromEdges(image, bodyLength, headerBits);
  return Uint8List.fromList([...header, ...body]);
}

void _writeSequential(img.Image image, List<int> bytes, int startSlot) {
  final endBit = bytes.length * 8;
  for (var bitIndex = 0; bitIndex < endBit; bitIndex++) {
    final bit = (bytes[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1;
    _writeBitAtSlot(image, startSlot + bitIndex, bit);
  }
}

Uint8List _readSequential(img.Image image, int byteCount, int startSlot) {
  final output = Uint8List(byteCount);
  final totalBits = byteCount * 8;
  for (var bitIndex = 0; bitIndex < totalBits; bitIndex++) {
    final bit = _readBitAtSlot(image, startSlot + bitIndex);
    output[bitIndex >> 3] |= bit << (7 - (bitIndex & 7));
  }
  return output;
}

void _writeOnEdges(img.Image image, List<int> bytes, int skipBefore) {
  final totalBits = bytes.length * 8;
  var bitIndex = 0;
  for (var pixelIndex = 0; pixelIndex < image.width * image.height && bitIndex < totalBits; pixelIndex++) {
    final firstSlot = pixelIndex * 3;
    if (firstSlot + 2 < skipBefore || !_isEdge(image, pixelIndex)) continue;
    for (var channel = 0; channel < 3 && bitIndex < totalBits; channel++) {
      final slot = firstSlot + channel;
      if (slot < skipBefore) continue;
      final bit = (bytes[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1;
      _writeBitAtSlot(image, slot, bit);
      bitIndex++;
    }
  }
  if (bitIndex != totalBits) throw const FormatException('Not enough textured pixels for this payload.');
}

Uint8List _readFromEdges(img.Image image, int byteCount, int skipBefore) {
  final output = Uint8List(byteCount);
  final totalBits = byteCount * 8;
  var bitIndex = 0;
  for (var pixelIndex = 0; pixelIndex < image.width * image.height && bitIndex < totalBits; pixelIndex++) {
    final firstSlot = pixelIndex * 3;
    if (firstSlot + 2 < skipBefore || !_isEdge(image, pixelIndex)) continue;
    for (var channel = 0; channel < 3 && bitIndex < totalBits; channel++) {
      final slot = firstSlot + channel;
      if (slot < skipBefore) continue;
      final bit = _readBitAtSlot(image, slot);
      output[bitIndex >> 3] |= bit << (7 - (bitIndex & 7));
      bitIndex++;
    }
  }
  if (bitIndex != totalBits) throw const FormatException('The hidden payload is incomplete.');
  return output;
}

int _edgeSlotCount(img.Image image, {required int skipBefore}) {
  if (image.width < 3 || image.height < 3) return 0;
  var count = 0;
  for (var pixelIndex = 0; pixelIndex < image.width * image.height; pixelIndex++) {
    final firstSlot = pixelIndex * 3;
    if (firstSlot + 2 < skipBefore || !_isEdge(image, pixelIndex)) continue;
    for (var channel = 0; channel < 3; channel++) {
      if (firstSlot + channel >= skipBefore) count++;
    }
  }
  return count;
}

bool _isEdge(img.Image image, int index) {
  final x = index % image.width;
  final y = index ~/ image.width;
  if (x == 0 || y == 0 || x == image.width - 1 || y == image.height - 1) return false;
  final center = _gray(image.getPixel(x, y));
  final score = (center - _gray(image.getPixel(x - 1, y))).abs() +
      (center - _gray(image.getPixel(x + 1, y))).abs() +
      (center - _gray(image.getPixel(x, y - 1))).abs() +
      (center - _gray(image.getPixel(x, y + 1))).abs();
  return score >= 64;
}

int _gray(img.Pixel pixel) =>
    ((299 * (pixel.r.toInt() & 0xFE) +
            587 * (pixel.g.toInt() & 0xFE) +
            114 * (pixel.b.toInt() & 0xFE)) ~/
        1000);

int _readBitAtSlot(img.Image image, int slot) {
  final pixelIndex = slot ~/ 3;
  final channel = slot % 3;
  final pixel = image.getPixel(pixelIndex % image.width, pixelIndex ~/ image.width);
  final value = channel == 0 ? pixel.r : channel == 1 ? pixel.g : pixel.b;
  return value.toInt() & 1;
}

void _writeBitAtSlot(img.Image image, int slot, int bit) {
  final pixelIndex = slot ~/ 3;
  final channel = slot % 3;
  final x = pixelIndex % image.width;
  final y = pixelIndex ~/ image.width;
  final pixel = image.getPixel(x, y);
  var red = pixel.r.toInt();
  var green = pixel.g.toInt();
  var blue = pixel.b.toInt();
  if (channel == 0) red = (red & 0xFE) | bit;
  if (channel == 1) green = (green & 0xFE) | bit;
  if (channel == 2) blue = (blue & 0xFE) | bit;
  image.setPixelRgba(x, y, red, green, blue, pixel.a.toInt());
}
