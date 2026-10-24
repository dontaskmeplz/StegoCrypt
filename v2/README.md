# StegoCrypt Lab (V2)

A separate Flutter build of the StegoCrypt graduation project. The original project is kept untouched. Android package ID: `com.stegocrypt.lab`, so this build can be installed alongside the original app.

## What is new in V2

- **Two embedding profiles:** Classic sequential RGB LSB and edge-adaptive RGB LSB. The adaptive profile places payload bits only in interior pixels whose four-neighbour luminance gradient reaches the implementation threshold (64), leaving smoother regions unused.
- **Capacity estimate:** The selected image and profile determine the available message size before embedding.
- **Image quality report:** PSNR is calculated over all RGB samples. SSIM is calculated over non-overlapping 8×8 grayscale windows and averaged. The result screen reports both after embedding.
- **Protocol v2:** The envelope records the embedding profile. The extractor still recognizes v1 envelopes as Classic LSB.
- Existing authenticated ciphers and password KDF choices remain available: AES-256-GCM or ChaCha20-Poly1305, with Argon2id or PBKDF2-HMAC-SHA256.

## Project contribution

The research contribution should be presented as a **mobile comparative evaluation and measurement workflow**, not as the invention of adaptive LSB. The app lets a user select between two spatial embedding policies, see the capacity trade-off, and measure distortion on the actual carrier image. A graduation report can evaluate both profiles across a fixed image set and payload sizes, then compare capacity, PSNR, SSIM, and extraction success. Results will depend on image content and payload size; the adaptive profile is not guaranteed to improve every metric.

LSB is fragile when a sharing service recompresses or resizes the image. A transform-domain method such as DCT is a sensible future comparison if robustness to JPEG is a research objective; it is a different trade-off from spatial LSB.

## Research background

- [Content-adaptive steganography using a distortion function](https://ieeexplore.ieee.org/abstract/document/7289422)
- [Inverted pattern approach for adaptive LSB image steganography](https://www.sciencedirect.com/science/article/pii/S131915782030625X)
- [2024 comparison of LSB and DCT methods](https://ieeexplore.ieee.org/document/10543932/)
- [Study of LSB and DCT robustness under JPEG/DCT processing](https://ieeexplore.ieee.org/document/9622143/)

## Build

Requires Flutter and Android SDK.

```shell
flutter pub get
flutter analyze
flutter build apk --debug
flutter build apk --release --target-platform android-arm64
```

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`.
ARM64 release APK: `build/app/outputs/flutter-apk/app-release.apk`.
