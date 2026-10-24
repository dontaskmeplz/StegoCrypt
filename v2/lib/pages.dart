import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'stego/crypto_service.dart';
import 'stego/image_metrics.dart';
import 'stego/lsb_service.dart';

class StegoCryptApp extends StatefulWidget {
  const StegoCryptApp({super.key});
  @override
  State<StegoCryptApp> createState() => _StegoCryptAppState();
}

class _StegoCryptAppState extends State<StegoCryptApp> {
  bool dark = false;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    SharedPreferencesAsync().getBool('stealth_mode').then((value) {
      if (mounted) setState(() => dark = value ?? false);
    });
  }
  Future<void> setDark(bool value) async {
    setState(() => dark = value);
    await SharedPreferencesAsync().setBool('stealth_mode', value);
  }
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: green, brightness: dark ? Brightness.dark : Brightness.light, surface: dark ? const Color(0xFF191B1F) : Colors.white);
    return MaterialApp(
      title: 'StegoCrypt', debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, colorScheme: scheme,
        scaffoldBackgroundColor: dark ? const Color(0xFF101114) : canvas,
        appBarTheme: AppBarTheme(backgroundColor: dark ? const Color(0xFF101114) : canvas, foregroundColor: dark ? Colors.white : ink, elevation: 0, centerTitle: true),
        cardTheme: CardThemeData(color: dark ? const Color(0xFF1C1E22) : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE7E9EC)))),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: dark ? const Color(0xFF282A2F) : const Color(0xFFF0F1F3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
      ),
      home: Scaffold(
        body: SafeArea(child: IndexedStack(index: tab, children: [
          HomePage(onTab: (value) => setState(() => tab = value)),
          const HistoryPage(),
          SettingsPage(dark: dark, onDarkChanged: setDark),
        ])),
        bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ]),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onTab});
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
    Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.lock_outline, color: Colors.white)), const SizedBox(width: 10), const Text('StegoCrypt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: () => onTab(2), icon: const Icon(Icons.tune_rounded))]),
    const SizedBox(height: 25),
    const Text('Secure Hub', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.6)),
    const SizedBox(height: 6), Text('Select an operation to begin secure processing.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
    const SizedBox(height: 21),
    _ActionCard(title: 'Embed', description: 'Conceal encrypted data within an image.', icon: Icons.lock_outline, dark: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmbedPage()))),
    const SizedBox(height: 13),
    _ActionCard(title: 'Extract', description: 'Recover and decrypt data from an image.', icon: Icons.key_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExtractPage()))),
    const SizedBox(height: 18),
    Card(color: blue.withValues(alpha: .08), child: const Padding(padding: EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.auto_graph, color: blue), SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('STEGO LAB', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)), SizedBox(height: 5), Text('Compare classic and edge-adaptive embedding, with image capacity and quality measurements.', style: TextStyle(fontSize: 12, height: 1.4))]))]))),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: green.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.verified_user_outlined, color: green)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('SECURITY ENGINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)), SizedBox(height: 5), Text('AES-GCM • ChaCha20 • LSB', style: TextStyle(color: green, fontSize: 12, fontWeight: FontWeight.w700))])), const Icon(Icons.circle, color: green, size: 9)]))),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline, size: 18, color: blue), const SizedBox(width: 10), Expanded(child: Text('Use PNG for the carrier image. Apps that resize or recompress shared images can damage hidden data.', style: TextStyle(color: Theme.of(context).hintColor, height: 1.4, fontSize: 12)))]))),
  ]);
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.description, required this.icon, required this.onTap, this.dark = false});
  final String title, description;
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Material(color: dark ? ink : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(21), child: InkWell(borderRadius: BorderRadius.circular(21), onTap: onTap, child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(21), border: dark ? null : Border.all(color: const Color(0xFFE7E9EC))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: dark ? Colors.white12 : const Color(0xFFF0F1F3), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg)), const Spacer(), Icon(Icons.arrow_forward_rounded, color: fg)]), const SizedBox(height: 14), Text(title, style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(description, style: TextStyle(color: dark ? Colors.white70 : Theme.of(context).hintColor, fontSize: 12))]))));
  }
}

class EmbedPage extends StatefulWidget {
  const EmbedPage({super.key});
  @override
  State<EmbedPage> createState() => _EmbedPageState();
}

class _EmbedPageState extends State<EmbedPage> {
  final picker = ImagePicker();
  final message = TextEditingController();
  final password = TextEditingController();
  Uint8List? imageBytes;
  String imageName = '';
  int capacity = 0;
  CipherChoice cipher = CipherChoice.aesGcm;
  KdfChoice kdf = KdfChoice.argon2id;
  StegoMode mode = StegoMode.classicLsb;
  bool showPassword = false, busy = false;
  @override
  void dispose() { message.dispose(); password.dispose(); super.dispose(); }

  Future<void> chooseImage() async {
    try {
      final selected = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      final available = await LsbService.capacityBytes(bytes, mode: mode);
      if (!mounted) return;
      setState(() { imageBytes = bytes; imageName = selected.name; capacity = available; });
    } catch (e) { if (mounted) _toast(context, 'Could not open image: $e'); }
  }

  Future<void> changeMode(StegoMode value) async {
    setState(() { mode = value; capacity = 0; });
    final bytes = imageBytes;
    if (bytes == null) return;
    final available = await LsbService.capacityBytes(bytes, mode: value);
    if (mounted && mode == value) setState(() => capacity = available);
  }

  Future<void> embed() async {
    if (imageBytes == null || message.text.trim().isEmpty || password.text.isEmpty) {
      _toast(context, 'Select an image and enter a message and password.'); return;
    }
    if (utf8.encode(message.text).length > capacity) {
      _toast(context, 'Message is too large for this image and selected mode. Try a larger image or Classic LSB.'); return;
    }
    setState(() => busy = true);
    try {
      final envelope = await CryptoService.encrypt(message: message.text, password: password.text, cipher: cipher, kdf: kdf, mode: mode);
      final png = await LsbService.embed(imageBytes!, envelope);
      final quality = await ImageMetrics.compare(imageBytes!, png);
      final dir = await getApplicationDocumentsDirectory();
      final safeName = 'stegocrypt_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(png, flush: true);
      await _record('embed', imageName, '${cipher.label} • ${mode.label}');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultPage(file: file, embedded: true, algorithm: cipher.label, mode: mode.label, quality: quality)));
    } catch (e) { if (mounted) _toast(context, 'Embedding failed: ${_friendlyError(e)}'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)), title: const Text('EMBED DATA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1))),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 18), children: [
      const Text('Protocol Setup', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5), Text('Choose a carrier image, message, and encryption settings.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
      const SizedBox(height: 14),
      _SectionCard(title: '1  •  SOURCE IMAGE', subtitle: 'The final output is PNG so LSB data survives.', child: _ImageChooser(bytes: imageBytes, name: imageName, onTap: chooseImage, label: 'Pick image')),
      _SectionCard(title: '2  •  SECRET MESSAGE', subtitle: 'Your text is encrypted before embedding.', child: TextField(controller: message, minLines: 4, maxLines: 7, maxLength: capacity > 0 ? capacity : 2000, decoration: const InputDecoration(hintText: 'Enter your secret message…', alignLabelWithHint: true))),
      _SectionCard(title: '3  •  PASSWORD', subtitle: 'A key is derived from this password for encryption.', child: TextField(controller: password, obscureText: !showPassword, decoration: InputDecoration(hintText: 'Password phrase', suffixIcon: IconButton(onPressed: () => setState(() => showPassword = !showPassword), icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility))))),
      _SectionCard(title: '4  •  STEGO LAB PROFILE', subtitle: mode.description, child: DropdownButtonFormField<StegoMode>(initialValue: mode, decoration: const InputDecoration(labelText: 'Embedding strategy'), items: StegoMode.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (value) { if (value != null) changeMode(value); })),
      _SectionCard(title: '5  •  CRYPTOGRAPHIC OPTIONS', subtitle: 'Algorithms are stored in the hidden protocol header.', child: Column(children: [
        DropdownButtonFormField<CipherChoice>(initialValue: cipher, decoration: const InputDecoration(labelText: 'Message encryption'), items: CipherChoice.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (v) { if (v != null) setState(() => cipher = v); }),
        const SizedBox(height: 10),
        DropdownButtonFormField<KdfChoice>(initialValue: kdf, decoration: const InputDecoration(labelText: 'Password key derivation'), items: KdfChoice.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (v) { if (v != null) setState(() => kdf = v); }),
      ])),
      if (imageBytes != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Available message capacity: ${_formatBytes(capacity)}', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
      FilledButton.icon(onPressed: busy ? null : embed, style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)), icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome), label: Text(busy ? 'Securing message…' : 'Initialize Embedding', style: const TextStyle(fontWeight: FontWeight.w700))),
      const SizedBox(height: 8), Center(child: Text('IMAGE, MESSAGE AND PASSWORD REQUIRED', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 9, letterSpacing: .8))),
    ]),
  );
}

class ExtractPage extends StatefulWidget {
  const ExtractPage({super.key});
  @override
  State<ExtractPage> createState() => _ExtractPageState();
}

class _ExtractPageState extends State<ExtractPage> {
  final picker = ImagePicker();
  final password = TextEditingController();
  Uint8List? imageBytes;
  String imageName = '';
  bool busy = false, showPassword = false;
  @override
  void dispose() { password.dispose(); super.dispose(); }
  Future<void> chooseImage() async {
    try {
      final selected = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (selected == null) return;
      if (!mounted) return;
      setState(() { imageBytes = null; imageName = selected.name; });
      final bytes = await selected.readAsBytes();
      if (mounted) setState(() => imageBytes = bytes);
    } catch (e) { if (mounted) _toast(context, 'Could not open image: $e'); }
  }
  Future<void> extract() async {
    if (imageBytes == null || password.text.isEmpty) { _toast(context, 'Select an image and enter its password.'); return; }
    setState(() => busy = true);
    try {
      final envelope = await LsbService.extract(imageBytes!);
      final text = await CryptoService.decrypt(envelope: envelope, password: password.text);
      final algorithm = CipherChoice.values[envelope[5] - 1].label;
      final mode = CryptoService.modeFromEnvelope(envelope).label;
      await _record('extract', imageName, '$algorithm • $mode');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultPage(embedded: false, message: text, algorithm: algorithm, mode: mode)));
    } catch (e) {
      if (mounted) _errorDialog(context, _friendlyError(e));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)), title: const Text('EXTRACT DATA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1))),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      const Text('Decryption Setup', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5), Text('Provide the StegoCrypt image and original password.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
      const SizedBox(height: 14),
      _SectionCard(title: '1  •  STEGO IMAGE', subtitle: 'Choose the original PNG output. Recompressed images may fail.', child: _ImageChooser(bytes: imageBytes, name: imageName, onTap: chooseImage, label: 'Upload image')),
      _SectionCard(title: '2  •  SECURITY KEY', subtitle: 'The protocol selects the matching algorithms automatically.', child: TextField(controller: password, obscureText: !showPassword, decoration: InputDecoration(hintText: 'Password phrase', suffixIcon: IconButton(onPressed: () => setState(() => showPassword = !showPassword), icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility))))),
      Card(color: blue.withValues(alpha: .08), child: const Padding(padding: EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_outline, color: blue), SizedBox(width: 10), Expanded(child: Text('If verification fails, the password may be incorrect or the image may have been altered.', style: TextStyle(fontSize: 12, height: 1.4)))]))),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: busy ? null : extract, style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)), icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_open), label: Text(busy ? 'Verifying…' : 'Verify & Extract', style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );
}

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.embedded, required this.algorithm, required this.mode, this.file, this.message, this.quality});
  final bool embedded;
  final String algorithm;
  final String mode;
  final File? file;
  final String? message;
  final ImageQuality? quality;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(embedded ? 'EMBED COMPLETE' : 'DECRYPTION COMPLETE', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('DONE'))]),
    body: ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 24), children: [
      Center(child: Container(width: 58, height: 58, decoration: const BoxDecoration(color: green, shape: BoxShape.circle), child: Icon(embedded ? Icons.check : Icons.visibility, color: Colors.white, size: 28))),
      const SizedBox(height: 18),
      Center(child: Text(embedded ? 'Data Secured' : 'Payload Revealed', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
      const SizedBox(height: 6),
      Center(child: Text(embedded ? 'The encrypted message is embedded in your PNG image.' : 'The message was extracted and authenticated.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13))),
      const SizedBox(height: 21),
      if (embedded && file != null) ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(file!, height: 240, fit: BoxFit.cover)),
      if (embedded && quality != null) Padding(padding: const EdgeInsets.only(top: 14), child: Row(children: [Expanded(child: _MetricCard(label: 'PSNR', value: quality!.psnr.isInfinite ? '∞ dB' : '${quality!.psnr.toStringAsFixed(2)} dB', icon: Icons.high_quality_outlined)), const SizedBox(width: 10), Expanded(child: _MetricCard(label: 'SSIM', value: quality!.ssim.toStringAsFixed(5), icon: Icons.compare_outlined))])),
      if (!embedded) Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RECOVERED CONTENT', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8)), const SizedBox(height: 12), SelectableText(message ?? '', style: const TextStyle(fontSize: 14, height: 1.5))]))),
      const SizedBox(height: 15),
      if (embedded) Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _saveToGallery(context, file!), icon: const Icon(Icons.download), label: const Text('Save to Photos'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => _shareFile(context, file!), icon: const Icon(Icons.share), label: const Text('Share')))])
      else OutlinedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: message ?? '')); if (context.mounted) _toast(context, 'Message copied.'); }, icon: const Icon(Icons.copy), label: const Text('Copy Text')),
      const SizedBox(height: 13),
      Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [const Icon(Icons.verified_outlined, color: green), const SizedBox(width: 10), Expanded(child: Text('$mode • $algorithm${embedded ? '' : ' • Authenticated'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))), const Icon(Icons.check_circle, size: 16, color: green)]))),
      const SizedBox(height: 20),
      OutlinedButton(onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), child: const Text('Initialize New Operation')),
    ]),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 11), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .5)), const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11, height: 1.3)), const SizedBox(height: 12), child])));
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 15, color: blue),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6)),
              ]),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _ImageChooser extends StatelessWidget {
  const _ImageChooser({required this.bytes, required this.name, required this.onTap, required this.label});
  final Uint8List? bytes;
  final String name, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final preview = bytes == null
        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.image_outlined, size: 23),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 3),
            const Text('PNG, JPG or WebP', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ])
        : Row(children: [
            ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)), child: Image.memory(bytes!, width: 100, height: 112, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 5),
              Text('${_formatBytes(bytes!.length)} • Tap to change', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10)),
            ])),
            const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.check_circle, color: green)),
          ]);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 112),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDADDE1))),
        child: preview,
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}
class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> items = [];
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final data = await SharedPreferencesAsync().getStringList('activity_log') ?? [];
    if (mounted) setState(() => items = data.map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map)).toList());
  }
  Future<void> clear() async { await SharedPreferencesAsync().remove('activity_log'); if (mounted) setState(() => items = []); }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), children: [
    const Text('Activity Log', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)), const SizedBox(height: 5),
    Text('ENCRYPTION & DECRYPTION EVENTS', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)), const SizedBox(height: 18),
    if (items.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [Icon(Icons.history, size: 30, color: Theme.of(context).hintColor), const SizedBox(height: 10), const Text('No activity yet'), const SizedBox(height: 4), Text('Completed operations will appear here.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))]))),
    for (final item in items) Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: green.withValues(alpha: .1), child: Icon(item['type'] == 'embed' ? Icons.lock_outline : Icons.key_outlined, color: green)), title: Text(item['type'] == 'embed' ? 'Message Embedded' : 'Data Extracted', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), subtitle: Text('${item['file']} • ${item['algorithm']}', maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Text(_time(item['time'] as String?), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10)))),
    if (items.isNotEmpty) TextButton.icon(onPressed: clear, icon: const Icon(Icons.delete_outline), label: const Text('Clear activity log'), style: TextButton.styleFrom(foregroundColor: Colors.redAccent)),
  ]);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.dark, required this.onDarkChanged});
  final bool dark;
  final ValueChanged<bool> onDarkChanged;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), children: [
    const Text('System Console', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)), const SizedBox(height: 5),
    Text('APPLICATION CONFIGURATION', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)), const SizedBox(height: 18),
    Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.shield_outlined)), title: const Text('Security profile', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('StegoCrypt Lab • Protocol v2'), trailing: const Icon(Icons.chevron_right))),
    const SizedBox(height: 15), _settingsHeader(context, 'GENERAL PREFERENCES'),
    Card(child: SwitchListTile(value: dark, onChanged: onDarkChanged, secondary: const Icon(Icons.nights_stay_outlined), title: const Text('Stealth mode'), subtitle: const Text('Use a darker app appearance'))),
    const SizedBox(height: 15), _settingsHeader(context, 'STEGO LAB'),
    const Card(child: Column(children: [ListTile(leading: Icon(Icons.grid_3x3), title: Text('Embedding strategies'), subtitle: Text('Classic LSB and edge-adaptive LSB')), Divider(height: 1, indent: 54), ListTile(leading: Icon(Icons.auto_graph), title: Text('Image quality report'), subtitle: Text('PSNR and SSIM measured after embedding'))])),
    const SizedBox(height: 15), _settingsHeader(context, 'CRYPTOGRAPHIC OPTIONS'),
    const Card(child: Column(children: [ListTile(leading: Icon(Icons.lock_outline), title: Text('Message encryption'), subtitle: Text('AES-256-GCM or ChaCha20-Poly1305')), Divider(height: 1, indent: 54), ListTile(leading: Icon(Icons.password), title: Text('Key derivation'), subtitle: Text('Argon2id or PBKDF2-HMAC-SHA256')), Divider(height: 1, indent: 54), ListTile(leading: Icon(Icons.verified_outlined), title: Text('Authentication tag'), subtitle: Text('128 bits • checked before revealing text'))])),
    const SizedBox(height: 15), _settingsHeader(context, 'PRIVACY'),
    Card(child: ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: const Text('Purge activity log', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right), onTap: () async { await SharedPreferencesAsync().remove('activity_log'); if (context.mounted) _toast(context, 'Activity log cleared.'); })),
    const SizedBox(height: 24), Center(child: Text('STEGOCRYPT • GRADUATION PROJECT', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10, letterSpacing: .8))),
  ]);
}

Widget _settingsHeader(BuildContext context, String title) => Padding(padding: const EdgeInsets.only(left: 3, bottom: 8), child: Text(title, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)));

Future<void> _record(String type, String file, String algorithm) async {
  final prefs = SharedPreferencesAsync();
  final items = await prefs.getStringList('activity_log') ?? [];
  items.insert(0, jsonEncode({'type': type, 'file': file, 'algorithm': algorithm, 'time': DateTime.now().toIso8601String()}));
  await prefs.setStringList('activity_log', items.take(60).toList());
}

Future<void> _saveToGallery(BuildContext context, File file) async {
  try { await Gal.putImage(file.path, album: 'StegoCrypt'); if (context.mounted) _toast(context, 'Saved to Photos.'); }
  catch (e) { if (context.mounted) _toast(context, 'Could not save image: $e'); }
}
Future<void> _shareFile(BuildContext context, File file) async {
  try { await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], title: 'StegoCrypt image')); }
  catch (e) { if (context.mounted) _toast(context, 'Could not share image: $e'); }
}
void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
String _friendlyError(Object error) {
  final value = error.toString().toLowerCase();
  if (value.contains('mac') || value.contains('authentication') || value.contains('secretbox')) return 'Verification failed. The password may be incorrect, or the image may have changed.';
  if (error is FormatException) return error.message;
  return 'The image or password could not be verified. Check the original PNG and try again.';
}
Future<void> _errorDialog(BuildContext context, String message) => showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Verification Error'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
String _formatBytes(int value) => value < 1024 ? '$value B' : value < 1024 * 1024 ? '${(value / 1024).toStringAsFixed(1)} KB' : '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
String _time(String? value) { final t = DateTime.tryParse(value ?? '')?.toLocal(); return t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'; }
