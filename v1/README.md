# StegoCrypt

Flutter mobile graduation project for hiding encrypted text inside images.

## Run the app

```powershell
flutter pub get
flutter run
```

To create an Android debug APK:

```powershell
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## App flow

1. Choose a carrier image and enter a message and password.
2. Select AES-256-GCM or ChaCha20-Poly1305.
3. Select Argon2id or PBKDF2-HMAC-SHA256 for deriving a 256-bit key from the password.
4. The encrypted envelope is embedded into the RGB least-significant bits and exported as PNG.
5. During extraction, the app reads the protocol header, selects the matching algorithms, verifies the authentication tag, and only then displays the plaintext.

The version 1 envelope contains a 47-byte header: magic bytes, version, cipher and KDF identifiers, random salt, nonce, KDF parameters, and encrypted-data length. The ciphertext and 128-bit authentication tag follow. Argon2id uses 19,456 KiB memory, two iterations, and one lane; PBKDF2 uses 210,000 HMAC-SHA256 iterations.

The activity log stores only the operation type, image name, algorithm, and timestamp. It does not store messages or passwords.

## Image notes

The output is a lossless PNG. JPEG re-encoding, image resizing, social-media compression, or other pixel changes can corrupt LSB data. The app can decode common source image formats, then writes the result as PNG. LSB hides data in pixel values; it does not make the carrier image resistant to editing or compression.

## Project structure

- `lib/pages.dart` — home, embed, extract, result, history, and settings screens.
- `lib/stego/crypto_service.dart` — AES-GCM / ChaCha20-Poly1305 and password-derived keys.
- `lib/stego/lsb_service.dart` — PNG carrier encoding and LSB extraction.
- `android/` and `ios/` — Flutter mobile platform projects.
