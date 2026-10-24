import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

enum CipherChoice { aesGcm, chacha20Poly1305 }

enum KdfChoice { argon2id, pbkdf2 }

extension CipherChoiceLabel on CipherChoice {
  String get label => switch (this) {
        CipherChoice.aesGcm => 'AES-256-GCM',
        CipherChoice.chacha20Poly1305 => 'ChaCha20-Poly1305',
      };
}

extension KdfChoiceLabel on KdfChoice {
  String get label => switch (this) {
        KdfChoice.argon2id => 'Argon2id',
        KdfChoice.pbkdf2 => 'PBKDF2-HMAC-SHA256',
      };
}

/// Versioned envelope stored in the image's RGB least-significant bits.
///
/// Header layout (47 bytes): magic(4), version(1), cipher(1), KDF(1),
/// salt(16), nonce(12), KDF iterations(4), KDF memory KiB(4),
/// ciphertext + authentication tag length(4), all integers big-endian.
class CryptoService {
  static const int headerLength = 47;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _tagLength = 16;
  static const int _pbkdf2Iterations = 210000;
  static const int _argonIterations = 2;
  static const int _argonMemoryKiB = 19456;
  static const int _argonParallelism = 1;
  static const List<int> _magic = [0x53, 0x54, 0x47, 0x43]; // STGC

  static Future<Uint8List> encrypt({
    required String message,
    required String password,
    required CipherChoice cipher,
    required KdfChoice kdf,
  }) async {
    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final nonce = List<int>.generate(_nonceLength, (_) => random.nextInt(256));
    final iterations = kdf == KdfChoice.argon2id
        ? _argonIterations
        : _pbkdf2Iterations;
    final memoryKiB = kdf == KdfChoice.argon2id ? _argonMemoryKiB : 0;
    final key = await _deriveKey(password, salt, kdf, iterations, memoryKiB);
    final cipherAlgorithm = _cipher(cipher);
    final box = await cipherAlgorithm.encrypt(
      utf8.encode(message),
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final encryptedData = <int>[...box.cipherText, ...box.mac.bytes];

    final header = Uint8List(headerLength);
    header.setRange(0, 4, _magic);
    header[4] = 1;
    header[5] = cipher.index + 1;
    header[6] = kdf.index + 1;
    header.setRange(7, 7 + _saltLength, salt);
    header.setRange(23, 23 + _nonceLength, nonce);
    final view = ByteData.sublistView(header);
    view.setUint32(35, iterations, Endian.big);
    view.setUint32(39, memoryKiB, Endian.big);
    view.setUint32(43, encryptedData.length, Endian.big);
    return Uint8List.fromList([...header, ...encryptedData]);
  }

  static Future<String> decrypt({
    required Uint8List envelope,
    required String password,
  }) async {
    if (envelope.length < headerLength + _tagLength) {
      throw const FormatException('The hidden payload is incomplete.');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (envelope[i] != _magic[i]) {
        throw const FormatException('No StegoCrypt payload was found.');
      }
    }
    if (envelope[4] != 1) {
      throw const FormatException('This payload version is not supported.');
    }
    final cipherId = envelope[5];
    final kdfId = envelope[6];
    if (cipherId < 1 || cipherId > CipherChoice.values.length ||
        kdfId < 1 || kdfId > KdfChoice.values.length) {
      throw const FormatException('The payload uses an unknown algorithm.');
    }
    final cipher = CipherChoice.values[cipherId - 1];
    final kdf = KdfChoice.values[kdfId - 1];
    final salt = envelope.sublist(7, 23);
    final nonce = envelope.sublist(23, 35);
    final view = ByteData.sublistView(envelope);
    final iterations = view.getUint32(35, Endian.big);
    final memoryKiB = view.getUint32(39, Endian.big);
    final dataLength = view.getUint32(43, Endian.big);
    if (dataLength < _tagLength || dataLength != envelope.length - headerLength) {
      throw const FormatException('The hidden payload length is invalid.');
    }
    if (kdf == KdfChoice.pbkdf2 &&
        (iterations < 10000 || iterations > 2000000 || memoryKiB != 0)) {
      throw const FormatException('The PBKDF2 settings are invalid.');
    }
    if (kdf == KdfChoice.argon2id &&
        (iterations < 1 || iterations > 10 || memoryKiB < 8192 || memoryKiB > 65536)) {
      throw const FormatException('The Argon2id settings are invalid.');
    }
    final key = await _deriveKey(password, salt, kdf, iterations, memoryKiB);
    final encryptedData = envelope.sublist(headerLength);
    final box = SecretBox(
      encryptedData.sublist(0, encryptedData.length - _tagLength),
      nonce: nonce,
      mac: Mac(encryptedData.sublist(encryptedData.length - _tagLength)),
    );
    final clear = await _cipher(cipher).decrypt(box, secretKey: SecretKey(key));
    return utf8.decode(clear, allowMalformed: false);
  }

  static Cipher _cipher(CipherChoice choice) => switch (choice) {
        CipherChoice.aesGcm => AesGcm.with256bits(),
        CipherChoice.chacha20Poly1305 => Chacha20.poly1305Aead(),
      };

  static Future<List<int>> _deriveKey(
    String password,
    List<int> salt,
    KdfChoice kdf,
    int iterations,
    int memoryKiB,
  ) async {
    final SecretKey key;
    if (kdf == KdfChoice.argon2id) {
      key = await Argon2id(
        parallelism: _argonParallelism,
        memory: memoryKiB,
        iterations: iterations,
        hashLength: 32,
      ).deriveKeyFromPassword(password: password, nonce: salt);
    } else {
      key = await Pbkdf2.hmacSha256(
        iterations: iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);
    }
    return key.extractBytes();
  }
}
