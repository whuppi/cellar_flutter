// cellar example — every capability, one file.
//
// ONE file on purpose — pub.dev renders example/lib/main.dart as the
// package's Example tab. Splitting it hides everything past main.dart
// from that page. Do not modularize.
//
// Seven tabs, one per API surface:
//   Store       — keys in, bytes out: write / read / head / list / delete
//   Stream      — writeStream with live progress, readStream, readRange
//   Partitions  — named compartments: routing, cross-copy, wipe
//   Lifecycle   — self-cleaning cache: size caps, eviction on demand
//   Encrypt     — bring-your-own-crypto seam, ciphertext at rest, tamper
//   Materialize — platform-local handles (file path / Blob URL)
//   Custom      — your own StorageBackend behind the same Cellar API
//
// The same code runs on every platform: the default constructor stores
// in real files on phones and desktops and in IndexedDB in browsers —
// the chip in the app bar shows which world you're in right now.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:cellar_flutter/cellar_flutter.dart';
import 'package:cellar/cellar_lowlevel.dart';

// ═══════════════════════════════════════════════════════════════════
// Demo FileEncryptor — the bring-your-own-crypto seam, implemented.
//
// Cellar ships NO cryptography: you hand it a FileEncryptor and it
// encrypts transparently. This one is real and complete — streaming
// chunks, per-chunk MACs, self-describing header — but DEMO-GRADE:
// the keystream is SHA-256-as-PRF in counter mode, which has not been
// audited for production use. Bring a vetted implementation (AES-GCM
// via a crypto plugin, libsodium) for real data.
//
// File format it produces:
//   [CELX][ver 2][headerLen 2][nonce 16][chunkSize 4][originalSize 8]
//   [chunk0 + mac32][chunk1 + mac32]...
// ═══════════════════════════════════════════════════════════════════

class DemoEncryptor implements FileEncryptor {
  static const _magic = [0x43, 0x45, 0x4C, 0x58]; // CELX
  static const int _headerSize = 4 + 2 + 2 + 16 + 4 + 8;

  @override
  int get headerSize => _headerSize;

  @override
  int get chunkMacSize => 32; // full HMAC-SHA256

  Uint8List _keyBytes(Object key) => key as Uint8List;

  /// Keystream block i of chunk [chunkIndex]: SHA256(key‖nonce‖chunk‖i).
  Uint8List _xor(
    Uint8List data,
    Uint8List key,
    Uint8List nonce,
    int chunkIndex,
  ) {
    final out = Uint8List(data.length);
    for (var block = 0; block * 32 < data.length; block++) {
      // dart2js has no 64-bit accessors — 32-bit halves everywhere.
      final counter = ByteData(16)
        ..setUint32(0, chunkIndex ~/ 0x100000000)
        ..setUint32(4, chunkIndex % 0x100000000)
        ..setUint32(8, block ~/ 0x100000000)
        ..setUint32(12, block % 0x100000000);
      final stream = crypto.sha256.convert([
        ...key,
        ...nonce,
        ...counter.buffer.asUint8List(),
      ]).bytes;
      final start = block * 32;
      final end = min(start + 32, data.length);
      for (var i = start; i < end; i++) {
        out[i] = data[i] ^ stream[i - start];
      }
    }
    return out;
  }

  Uint8List _mac(
    Uint8List cipher,
    Uint8List key,
    Uint8List nonce,
    int chunkIndex,
  ) {
    final counter = ByteData(8)
      ..setUint32(0, chunkIndex ~/ 0x100000000)
      ..setUint32(4, chunkIndex % 0x100000000);
    return Uint8List.fromList(
      crypto.Hmac(
        crypto.sha256,
        key,
      ).convert([...nonce, ...counter.buffer.asUint8List(), ...cipher]).bytes,
    );
  }

  Uint8List _header(Uint8List nonce, int chunkSize, int originalSize) {
    final h = ByteData(_headerSize);
    for (var i = 0; i < 4; i++) {
      h.setUint8(i, _magic[i]);
    }
    h.setUint16(4, 1); // version
    h.setUint16(6, _headerSize);
    for (var i = 0; i < 16; i++) {
      h.setUint8(8 + i, nonce[i]);
    }
    h.setUint32(24, chunkSize);
    h.setUint32(28, originalSize ~/ 0x100000000);
    h.setUint32(32, originalSize % 0x100000000);
    return h.buffer.asUint8List();
  }

  @override
  Stream<List<int>> encryptStream(
    Stream<List<int>> plaintext,
    Object key, {
    int chunkSize = FileEncryptor.defaultChunkSize,
  }) async* {
    final k = _keyBytes(key);
    final nonce = Uint8List.fromList(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    // Streaming: originalSize isn't known yet — the header carries a
    // provisional 0; cellar patches the true size into sidecar metadata
    // when the stream completes.
    yield _header(nonce, chunkSize, 0);

    var chunkIndex = 0;
    final buffer = BytesBuilder(copy: false);
    await for (final piece in plaintext) {
      buffer.add(piece);
      while (buffer.length >= chunkSize) {
        final all = buffer.takeBytes();
        final chunk = Uint8List.sublistView(all, 0, chunkSize);
        buffer.add(Uint8List.sublistView(all, chunkSize));
        final cipher = _xor(chunk, k, nonce, chunkIndex);
        yield cipher;
        yield _mac(cipher, k, nonce, chunkIndex);
        chunkIndex++;
      }
    }
    final tail = buffer.takeBytes();
    if (tail.isNotEmpty || chunkIndex == 0) {
      final cipher = _xor(tail, k, nonce, chunkIndex);
      yield cipher;
      yield _mac(cipher, k, nonce, chunkIndex);
    }
  }

  @override
  Future<Uint8List> encryptBytes(
    Uint8List plaintext,
    Object key, {
    int chunkSize = FileEncryptor.defaultChunkSize,
  }) async {
    final out = BytesBuilder(copy: false);
    await for (final piece in encryptStream(
      Stream.value(plaintext),
      key,
      chunkSize: chunkSize,
    )) {
      out.add(piece);
    }
    return out.takeBytes();
  }

  @override
  Stream<List<int>> decryptStream(
    Stream<List<int>> ciphertext,
    Object key,
  ) async* {
    final buffer = BytesBuilder(copy: false);
    ({int chunkSize, Uint8List nonce})? head;
    var chunkIndex = 0;

    await for (final piece in ciphertext) {
      buffer.add(piece);
      if (head == null) {
        if (buffer.length < _headerSize) continue;
        final all = buffer.takeBytes();
        final parsed = parseHeader(all);
        head = (chunkSize: parsed.chunkSize, nonce: parsed.nonce);
        buffer.add(Uint8List.sublistView(all, _headerSize));
      }
      final unit = head.chunkSize + chunkMacSize;
      while (buffer.length > unit) {
        final all = buffer.takeBytes();
        final one = Uint8List.sublistView(all, 0, unit);
        buffer.add(Uint8List.sublistView(all, unit));
        yield await decryptChunk(one, key, head.nonce, chunkIndex);
        chunkIndex++;
      }
    }
    final last = buffer.takeBytes();
    if (last.isNotEmpty) {
      if (head == null) throw InvalidHeaderError('', cause: 'truncated');
      yield await decryptChunk(
        Uint8List.fromList(last),
        key,
        head.nonce,
        chunkIndex,
      );
    }
  }

  @override
  Future<Uint8List> decryptChunk(
    Uint8List chunkWithMac,
    Object key,
    Uint8List nonce,
    int chunkIndex,
  ) async {
    final k = _keyBytes(key);
    final split = chunkWithMac.length - chunkMacSize;
    final cipher = Uint8List.sublistView(chunkWithMac, 0, split);
    final mac = Uint8List.sublistView(chunkWithMac, split);
    final expect = _mac(cipher, k, nonce, chunkIndex);
    for (var i = 0; i < chunkMacSize; i++) {
      if (mac[i] != expect[i]) {
        throw ChunkVerificationError('', chunkIndex);
      }
    }
    return _xor(cipher, k, nonce, chunkIndex);
  }

  @override
  Future<Uint8List> decryptBytes(Uint8List ciphertext, Object key) async {
    final out = BytesBuilder(copy: false);
    await for (final piece in decryptStream(Stream.value(ciphertext), key)) {
      out.add(piece);
    }
    return out.takeBytes();
  }

  @override
  ({
    int chunkSize,
    int originalSize,
    Uint8List nonce,
    int headerSize,
    int chunkCount,
  })
  parseHeader(Uint8List headerBytes) {
    if (!isEncrypted(headerBytes)) {
      throw InvalidHeaderError('', cause: 'bad magic');
    }
    final h = ByteData.sublistView(headerBytes);
    final chunkSize = h.getUint32(24);
    final originalSize = h.getUint32(28) * 0x100000000 + h.getUint32(32);
    return (
      chunkSize: chunkSize,
      originalSize: originalSize,
      nonce: Uint8List.sublistView(headerBytes, 8, 24),
      headerSize: _headerSize,
      chunkCount: originalSize == 0 ? 0 : (originalSize / chunkSize).ceil(),
    );
  }

  @override
  bool isEncrypted(Uint8List bytes) {
    if (bytes.length < 4) return false;
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }
}

/// Resolves every key to one fixed demo secret. A real app derives keys
/// per user / per record — that's the whole point of the interface.
class DemoKeyResolver implements EncryptionKeyResolver {
  final Uint8List _secret = Uint8List.fromList(
    utf8.encode('demo-secret-32-bytes-long-please'),
  );

  @override
  Future<Object?> resolveKey(String storageKey) async => _secret;

  @override
  void clearCache() {}
}

// ═══════════════════════════════════════════════════════════════════
// Demo custom backend — the open StorageBackend seam, implemented.
//
// Anything that can store bytes at a key can be a cellar backend:
// implement the interface, hand it to Cellar.withBackends, and the
// whole facade (partitions, tenant prefixes, lifecycle, encryption)
// works on top of it. This one keeps objects in a Map.
// ═══════════════════════════════════════════════════════════════════

class DemoMemoryBackend with DisposeGuard implements StorageBackend {
  final _data = <String, Uint8List>{};
  final _contentType = <String, String?>{};
  final _metadata = <String, Map<String, String>>{};
  final _modified = <String, DateTime>{};

  @override
  String get disposeLabel => 'DemoMemoryBackend';

  /// Demo hook: the raw stored keys — shows tenant prefixes at rest.
  List<String> get rawKeys => _data.keys.toList()..sort();

  /// Demo hook: raw stored bytes — shows ciphertext at rest.
  Uint8List? rawBytes(String key) => _data[key];

  /// Demo hook: corrupt one stored byte — drives the tamper demo.
  void flipByte(String key, int offset) {
    final b = _data[key];
    if (b != null && offset < b.length) b[offset] ^= 0xFF;
  }

  @override
  Future<void> write(
    String key,
    Uint8List bytes, [
    WriteOptions options = const WriteOptions(),
  ]) async {
    checkNotDisposed();
    _data[key] = Uint8List.fromList(bytes);
    _contentType[key] = options.contentType;
    _metadata[key] = Map.of(options.metadata);
    _modified[key] = DateTime.now().toUtc();
  }

  @override
  Future<void> writeStream(
    String key,
    Stream<List<int>> byteStream, [
    WriteOptions options = const WriteOptions(),
  ]) async {
    checkNotDisposed();
    final buffer = BytesBuilder(copy: false);
    var written = 0;
    await for (final chunk in byteStream) {
      buffer.add(chunk);
      written += chunk.length;
      options.onProgress?.call(written, null);
    }
    await write(key, buffer.takeBytes(), options);
  }

  @override
  Future<Uint8List> read(String key) async {
    checkNotDisposed();
    final b = _data[key];
    if (b == null) throw FileNotFoundError(key);
    return Uint8List.fromList(b);
  }

  @override
  Stream<List<int>> readStream(String key) async* {
    yield await read(key);
  }

  @override
  Future<Uint8List> readRange(
    String key, {
    required int start,
    required int length,
  }) async {
    final b = await read(key);
    final end = min(start + length, b.length);
    return end <= start ? Uint8List(0) : b.sublist(start, end);
  }

  @override
  Future<ObjectInfo?> head(String key) async {
    checkNotDisposed();
    final b = _data[key];
    if (b == null) return null;
    return ObjectInfo(
      key: key,
      size: b.length,
      contentType: _contentType[key],
      metadata: _metadata[key] ?? const {},
      lastModified: _modified[key]!,
    );
  }

  @override
  Future<bool> exists(String key) async {
    checkNotDisposed();
    return _data.containsKey(key);
  }

  @override
  Future<void> delete(String key) async {
    checkNotDisposed();
    _data.remove(key);
    _contentType.remove(key);
    _metadata.remove(key);
    _modified.remove(key);
  }

  @override
  Future<void> deletePrefix(String prefix) async {
    checkNotDisposed();
    for (final k in _data.keys.where((k) => k.startsWith(prefix)).toList()) {
      await delete(k);
    }
  }

  @override
  Future<List<ObjectInfo>> list(String prefix) async {
    checkNotDisposed();
    return [
      for (final k in rawKeys)
        if (k.startsWith(prefix)) (await head(k))!,
    ];
  }

  @override
  Future<void> copy(String sourceKey, String destKey) async {
    final b = await read(sourceKey);
    await write(
      destKey,
      b,
      WriteOptions(
        contentType: _contentType[sourceKey],
        metadata: _metadata[sourceKey] ?? const {},
      ),
    );
  }

  @override
  Future<void> updateMetadata(
    String key, {
    String? contentType,
    Map<String, String> metadata = const {},
  }) async {
    checkNotDisposed();
    if (!_data.containsKey(key)) throw FileNotFoundError(key);
    _contentType[key] = contentType;
    _metadata[key] = Map.of(metadata);
    _modified[key] = DateTime.now().toUtc();
  }

  @override
  Future<MaterializedFile> materialize(
    String key, {
    bool decrypt = true,
    bool exclusive = false,
  }) async {
    throw UnsupportedError(
      'DemoMemoryBackend has no filesystem or Blob store to hand out — '
      'see the Materialize tab, which uses the platform-default backend.',
    );
  }

  @override
  Future<void> dispose() async {
    markDisposed();
    _data.clear();
  }
}

// ═══════════════════════════════════════════════════════════════════
// Fixtures + helpers — the app works without picking any file.
// ═══════════════════════════════════════════════════════════════════

/// 1×1 red PNG — enough to prove a materialized handle actually serves
/// image bytes the platform can render.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Uint8List loremBytes(int size) {
  const lorem = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ';
  final unit = utf8.encode(lorem);
  final out = Uint8List(size);
  for (var i = 0; i < size; i++) {
    out[i] = unit[i % unit.length];
  }
  return out;
}

String fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}

String fmtHex(Uint8List bytes, {int take = 24}) {
  final n = min(take, bytes.length);
  final hex = [
    for (var i = 0; i < n; i++) bytes[i].toRadixString(16).padLeft(2, '0'),
  ].join(' ');
  return bytes.length > n ? '$hex …' : hex;
}

// ═══════════════════════════════════════════════════════════════════
// App shell
// ═══════════════════════════════════════════════════════════════════

void main() => runApp(const ExampleApp());

/// Root widget: opens the shared demo cellar, then shows the tabs.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'cellar example',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D4C41)),
      useMaterial3: true,
    ),
    home: const CellarGate(),
  );
}

/// Opens the app's cellar once; every tab shares it.
class CellarGate extends StatefulWidget {
  const CellarGate({super.key});

  @override
  State<CellarGate> createState() => _CellarGateState();
}

class _CellarGateState extends State<CellarGate> {
  Cellar? cellar;
  late final Future<Cellar> _opening;

  @override
  void initState() {
    super.initState();
    // One identical call on every platform — openCellar resolves the
    // storage roots (path_provider on native, none needed on web),
    // opens, and returns a ready cellar.
    _opening = openCellar(
      name: 'cellar_demo',
      partitions: {
        'main': const PartitionConfig(),
        'cache': const PartitionConfig(
          lifecycle: Lifecycle(
            maxBytes: 512 * 1024,
            runInterval: Duration(hours: 1),
          ),
        ),
        'scratch': const PartitionConfig(lifecycle: Lifecycle.scratch()),
      },
      defaultPartition: 'main',
      onEvictionError: (partition, key, error) =>
          debugPrint('eviction failed: $partition/$key — $error'),
    ).then((c) => cellar = c);
  }

  @override
  void dispose() {
    cellar?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Cellar>(
    future: _opening,
    builder: (context, snap) {
      if (snap.hasError) {
        return Scaffold(
          body: Center(child: Text('open failed: ${snap.error}')),
        );
      }
      final opened = snap.data;
      if (opened == null) {
        // Static text, not a spinner. The gate is visible <100 ms on
        // real hardware, and an indeterminate spinner is a repeat()-
        // driven ticker — the one animation class that trips Flutter's
        // long-open negative-elapsed assertion (flutter/flutter#43501)
        // when sequential widget tests launch the app repeatedly.
        return const Scaffold(body: Center(child: Text('opening cellar…')));
      }
      return HomePage(cellar: opened);
    },
  );
}

/// The seven tabs.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.cellar});

  final Cellar cellar;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 7,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('cellar'),
        actions: [
          // The one-API-everywhere proof: which warehouse did the
          // default constructor pick on THIS platform?
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                avatar: Icon(kIsWeb ? Icons.language : Icons.storage, size: 16),
                label: Text(kIsWeb ? 'IndexedDB' : 'file system'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.inventory_2, size: 20), text: 'Store'),
            Tab(icon: Icon(Icons.waves, size: 20), text: 'Stream'),
            Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Partitions'),
            Tab(icon: Icon(Icons.auto_delete, size: 20), text: 'Lifecycle'),
            Tab(icon: Icon(Icons.lock, size: 20), text: 'Encrypt'),
            Tab(icon: Icon(Icons.link, size: 20), text: 'Materialize'),
            Tab(icon: Icon(Icons.extension, size: 20), text: 'Custom'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          StoreTab(cellar: cellar),
          StreamTab(cellar: cellar),
          PartitionsTab(cellar: cellar),
          LifecycleTab(cellar: cellar),
          const EncryptTab(),
          MaterializeTab(cellar: cellar),
          const CustomTab(),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Shared widgets — op buttons, log pane, object browser
// ═══════════════════════════════════════════════════════════════════

/// One tappable operation. Errors surface in the tab's log via the
/// TabLog mixin's runner, never silently.
class OpButton extends StatelessWidget {
  const OpButton(this.label, this.onRun, {super.key, this.icon});

  final String label;
  final IconData? icon;
  final Future<void> Function() onRun;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    // Keyed so UI tests target ops by label without text ambiguity.
    key: ValueKey('op:$label'),
    icon: Icon(icon ?? Icons.play_arrow, size: 18),
    label: Text(label),
    onPressed: onRun,
  );
}

/// Scrolling log every tab appends to — the "what just happened" pane.
class LogPane extends StatelessWidget {
  const LogPane(this.lines, {super.key});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 120),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: lines.isEmpty
        ? Text(
            'Run an operation…',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          )
        : Text(
            lines.reversed.join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          ),
  );
}

/// Live listing of one partition: key · size · content-type, with a
/// per-object delete.
class ObjectBrowser extends StatelessWidget {
  const ObjectBrowser({
    super.key,
    required this.objects,
    required this.onDelete,
  });

  final List<ObjectInfo> objects;
  final Future<void> Function(String key) onDelete;

  @override
  Widget build(BuildContext context) {
    if (objects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '(empty)',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return Column(
      children: [
        for (final o in objects)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, size: 18),
            title: Text(o.key, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              '${fmtSize(o.size)}'
              '${o.contentType != null ? ' · ${o.contentType}' : ''}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => onDelete(o.key),
            ),
          ),
      ],
    );
  }
}

/// Base for tabs: a log + a runner that reports every error into the
/// log instead of swallowing it.
mixin TabLog<T extends StatefulWidget> on State<T> {
  final List<String> logLines = [];

  void say(String line) {
    if (!mounted) return;
    setState(() => logLines.add(line));
  }

  Future<void> run(String opName, Future<void> Function() op) async {
    try {
      await op();
    } on Object catch (e) {
      say('✗ $opName: $e');
    }
  }
}

/// Standard tab layout: sections in a scroll view.
class TabBody extends StatelessWidget {
  const TabBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      for (final c in children)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
    ],
  );
}

/// A titled card with a one-breath explanation + content.
class Section extends StatelessWidget {
  const Section(this.title, this.blurb, {super.key, required this.child});

  final String title;
  final String blurb;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(blurb, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Tab 1: Store — keys in, bytes out
// ═══════════════════════════════════════════════════════════════════

class StoreTab extends StatefulWidget {
  const StoreTab({super.key, required this.cellar});

  final Cellar cellar;

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab>
    with AutomaticKeepAliveClientMixin, TabLog {
  final _keyCtl = TextEditingController(text: 'notes/hello');
  final _textCtl = TextEditingController(text: 'Hello from cellar!');
  List<ObjectInfo> objects = [];

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final all = await widget.cellar.list('');
    if (mounted) setState(() => objects = all);
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabBody(
      children: [
        Section(
          'Write and read',
          'Keys are slash-paths, not file paths. The same call stores in '
              'real files on native and in IndexedDB on web.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _keyCtl,
                decoration: const InputDecoration(labelText: 'key'),
              ),
              TextField(
                controller: _textCtl,
                decoration: const InputDecoration(labelText: 'content'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OpButton('write', icon: Icons.save, () async {
                    await run('write', () async {
                      final key = _keyCtl.text;
                      await widget.cellar.write(
                        key,
                        Uint8List.fromList(utf8.encode(_textCtl.text)),
                        contentType: 'text/plain',
                        metadata: {'source': 'store-tab'},
                      );
                      say('✓ wrote $key');
                      await _refresh();
                    });
                  }),
                  OpButton('read', icon: Icons.file_open, () async {
                    await run('read', () async {
                      final key = _keyCtl.text;
                      final bytes = await widget.cellar.read(key);
                      say('✓ read $key → "${utf8.decode(bytes)}"');
                    });
                  }),
                  OpButton('head', icon: Icons.info_outline, () async {
                    await run('head', () async {
                      final key = _keyCtl.text;
                      final info = await widget.cellar.head(key);
                      say(
                        info == null
                            ? '✓ head $key → absent'
                            : '✓ head $key → ${fmtSize(info.size)}, '
                                  '${info.contentType}, meta=${info.metadata}',
                      );
                    });
                  }),
                  OpButton(
                    'read missing key',
                    icon: Icons.error_outline,
                    () async {
                      // Typed errors: pattern-match, never string-match.
                      try {
                        await widget.cellar.read('no/such/key');
                        say('✗ expected FileNotFoundError');
                      } on FileNotFoundError catch (e) {
                        say('✓ typed error caught: $e');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Section(
          'Everything in the main partition',
          'list() enumerates with metadata; delete removes one object.',
          child: ObjectBrowser(
            objects: objects,
            onDelete: (key) async {
              await widget.cellar.delete(key);
              say('✓ deleted $key');
              await _refresh();
            },
          ),
        ),
        Section('Log', 'Newest first.', child: LogPane(logLines)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 2: Stream — constant-memory large objects
// ═══════════════════════════════════════════════════════════════════

class StreamTab extends StatefulWidget {
  const StreamTab({super.key, required this.cellar});

  final Cellar cellar;

  @override
  State<StreamTab> createState() => _StreamTabState();
}

class _StreamTabState extends State<StreamTab>
    with AutomaticKeepAliveClientMixin, TabLog {
  double? progress;
  static const key = 'big/lorem';
  static const totalSize = 4 * 1024 * 1024; // 4 MiB

  @override
  bool get wantKeepAlive => true;

  /// The source pretends to be a slow network: 64 KiB pieces, yielding
  /// between them so the UI can breathe.
  Stream<List<int>> _source() async* {
    const piece = 64 * 1024;
    final data = loremBytes(totalSize);
    for (var off = 0; off < data.length; off += piece) {
      await Future<void>.delayed(Duration.zero);
      yield Uint8List.sublistView(data, off, min(off + piece, data.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabBody(
      children: [
        Section(
          'writeStream with live progress',
          'Streams never buffer the whole object — memory stays flat at '
              'chunk size whether the payload is 4 MiB or 7 GiB. '
              'onProgress reports source bytes.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (progress != null) ...[
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OpButton('stream 4 MiB in', icon: Icons.upload, () async {
                    await run('writeStream', () async {
                      await widget.cellar.writeStream(
                        key,
                        _source(),
                        contentType: 'text/plain',
                        onProgress: (written, _) {
                          if (mounted) {
                            setState(() => progress = written / totalSize);
                          }
                        },
                      );
                      setState(() => progress = null);
                      say('✓ streamed ${fmtSize(totalSize)} → $key');
                    });
                  }),
                  OpButton(
                    'stream out + count',
                    icon: Icons.download,
                    () async {
                      await run('readStream', () async {
                        var n = 0;
                        var chunks = 0;
                        await for (final c in widget.cellar.readStream(key)) {
                          n += c.length;
                          chunks++;
                        }
                        say('✓ readStream → ${fmtSize(n)} in $chunks chunks');
                      });
                    },
                  ),
                  OpButton(
                    'readRange middle 32 B',
                    icon: Icons.content_cut,
                    () async {
                      await run('readRange', () async {
                        final slice = await widget.cellar.readRange(
                          key,
                          start: totalSize ~/ 2,
                          length: 32,
                        );
                        say(
                          '✓ readRange @${fmtSize(totalSize ~/ 2)} → '
                          '"${utf8.decode(slice)}" — only the overlapping '
                          'chunks were read',
                        );
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Section('Log', 'Newest first.', child: LogPane(logLines)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 3: Partitions — named compartments
// ═══════════════════════════════════════════════════════════════════

class PartitionsTab extends StatefulWidget {
  const PartitionsTab({super.key, required this.cellar});

  final Cellar cellar;

  @override
  State<PartitionsTab> createState() => _PartitionsTabState();
}

class _PartitionsTabState extends State<PartitionsTab>
    with AutomaticKeepAliveClientMixin, TabLog {
  Map<String, List<ObjectInfo>> byPartition = {};

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final next = <String, List<ObjectInfo>>{};
    for (final p in ['main', 'cache', 'scratch']) {
      next[p] = await widget.cellar.list('', partition: p);
    }
    if (mounted) setState(() => byPartition = next);
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabBody(
      children: [
        Section(
          'Route writes by partition',
          "This cellar has three: 'main' (keep forever), 'cache' "
              "(self-cleaning — next tab), 'scratch' (wiped on every "
              'open). Omit partition: to use the default.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OpButton('write to main', () async {
                await run('write', () async {
                  await widget.cellar.write('doc/report', loremBytes(2048));
                  say('✓ doc/report → main (default)');
                  await _refresh();
                });
              }),
              OpButton('write to cache', () async {
                await run('write', () async {
                  await widget.cellar.write(
                    'thumb/report',
                    loremBytes(1024),
                    partition: 'cache',
                  );
                  say('✓ thumb/report → cache');
                  await _refresh();
                });
              }),
              OpButton('write to scratch', () async {
                await run('write', () async {
                  await widget.cellar.write(
                    'tmp/upload',
                    loremBytes(512),
                    partition: 'scratch',
                  );
                  say('✓ tmp/upload → scratch (gone next launch)');
                  await _refresh();
                });
              }),
              OpButton('copy main → cache', icon: Icons.copy, () async {
                await run('copyAcrossPartitions', () async {
                  await widget.cellar.copyAcrossPartitions(
                    fromPartition: 'main',
                    fromKey: 'doc/report',
                    toPartition: 'cache',
                    toKey: 'doc/report',
                  );
                  say('✓ copied doc/report across partitions');
                  await _refresh();
                });
              }),
              OpButton('wipe cache', icon: Icons.delete_sweep, () async {
                await run('wipePartition', () async {
                  await widget.cellar.wipePartition('cache');
                  say('✓ cache wiped — main and scratch untouched');
                  await _refresh();
                });
              }),
            ],
          ),
        ),
        for (final p in ['main', 'cache', 'scratch'])
          Section(
            "partition: '$p'",
            'Independent listing — partitions never see each other.',
            child: ObjectBrowser(
              objects: byPartition[p] ?? const [],
              onDelete: (key) async {
                await widget.cellar.delete(key, partition: p);
                await _refresh();
              },
            ),
          ),
        Section('Log', 'Newest first.', child: LogPane(logLines)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 4: Lifecycle — the self-cleaning cache
// ═══════════════════════════════════════════════════════════════════

class LifecycleTab extends StatefulWidget {
  const LifecycleTab({super.key, required this.cellar});

  final Cellar cellar;

  @override
  State<LifecycleTab> createState() => _LifecycleTabState();
}

class _LifecycleTabState extends State<LifecycleTab>
    with AutomaticKeepAliveClientMixin, TabLog {
  int used = 0;
  int count = 0;
  var _seq = 0;

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final objects = await widget.cellar.list('', partition: 'cache');
    if (mounted) {
      setState(() {
        count = objects.length;
        used = objects.fold(0, (a, o) => a + o.size);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const cap = 512 * 1024;
    return TabBody(
      children: [
        Section(
          'Fill the cache past its cap',
          "The 'cache' partition is configured with maxBytes: 512 KiB. "
              'A timer normally evicts in the background; the button runs '
              'the same evaluation on demand. Oldest objects go first.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: min(used / cap, 1),
                color: used > cap ? Colors.red : null,
              ),
              const SizedBox(height: 6),
              Text('$count objects · ${fmtSize(used)} / ${fmtSize(cap)} cap'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OpButton('add 100 KiB', icon: Icons.add, () async {
                    await run('write', () async {
                      await widget.cellar.write(
                        'junk/${_seq++}',
                        loremBytes(100 * 1024),
                        partition: 'cache',
                      );
                      await _refresh();
                      say('✓ junk added — now ${fmtSize(used)}');
                    });
                  }),
                  OpButton('evict now', icon: Icons.auto_delete, () async {
                    await run('runLifecycleNow', () async {
                      final before = count;
                      await widget.cellar.runLifecycleNow();
                      await _refresh();
                      say(
                        '✓ eviction pass: $before → $count objects '
                        '(${fmtSize(used)} ≤ cap, oldest evicted first)',
                      );
                    });
                  }),
                ],
              ),
            ],
          ),
        ),
        Section('Log', 'Newest first.', child: LogPane(logLines)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 5: Encrypt — the BYO-crypto seam, ciphertext at rest, tamper
// ═══════════════════════════════════════════════════════════════════

class EncryptTab extends StatefulWidget {
  const EncryptTab({super.key});

  @override
  State<EncryptTab> createState() => _EncryptTabState();
}

class _EncryptTabState extends State<EncryptTab>
    with AutomaticKeepAliveClientMixin, TabLog {
  // Assembled from the low-level kit so the RAW store stays visible:
  // base (memory) → EncryptedBackend → Cellar. In production the same
  // wiring is one `encryption:` argument on the main constructor.
  final base = DemoMemoryBackend();
  late final Cellar vault;
  Future<void>? _opening;
  static const key = 'diary/today';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    vault = Cellar.withBackends({
      'vault': EncryptedBackend(
        inner: base,
        encryptor: DemoEncryptor(),
        keyResolver: DemoKeyResolver(),
      ),
    }, defaultPartition: 'vault');
    _opening = vault.open();
  }

  @override
  void dispose() {
    vault.close();
    base.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabBody(
      children: [
        Section(
          'Transparent encryption',
          'Cellar ships zero cryptography — you implement two small '
              'interfaces (this file does, see DemoEncryptor) and every '
              'write is encrypted with streaming chunks + per-chunk MACs. '
              'Reads decrypt transparently; the format is self-describing.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OpButton('write secret', icon: Icons.lock, () async {
                await _opening;
                await run('write', () async {
                  await vault.write(
                    key,
                    Uint8List.fromList(
                      utf8.encode('my secret diary entry — nobody reads this'),
                    ),
                    encrypt: true,
                  );
                  say('✓ wrote $key (encrypted)');
                });
              }),
              OpButton('read back', icon: Icons.lock_open, () async {
                await run('read', () async {
                  final plain = await vault.read(key);
                  say('✓ decrypted read → "${utf8.decode(plain)}"');
                });
              }),
              OpButton(
                'peek RAW stored bytes',
                icon: Icons.visibility,
                () async {
                  await run('peek', () async {
                    final keys = base.rawKeys;
                    if (keys.isEmpty) {
                      say('✗ nothing stored yet — write the secret first');
                      return;
                    }
                    final stored = base.rawBytes(keys.first)!;
                    say(
                      '✓ at rest (key "${keys.first}"): '
                      '${fmtSize(stored.length)} of ciphertext\n'
                      '   ${fmtHex(stored)}\n'
                      '   (starts with the CELX magic — the format is '
                      'self-describing)',
                    );
                  });
                },
              ),
              OpButton(
                'tamper one byte → read',
                icon: Icons.bug_report,
                () async {
                  await run('tamper', () async {
                    final keys = base.rawKeys;
                    if (keys.isEmpty) {
                      say('✗ nothing stored yet — write the secret first');
                      return;
                    }
                    base.flipByte(keys.first, 60); // inside chunk 0's body
                    try {
                      await vault.read(key);
                      say('✗ tampered read was NOT caught');
                    } on ChunkVerificationError catch (e) {
                      say(
                        '✓ MAC verification caught the tamper: $e\n'
                        '   (write the secret again to restore)',
                      );
                    }
                  });
                },
              ),
            ],
          ),
        ),
        Section('Log', 'Newest first.', child: LogPane(logLines)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 6: Materialize — platform-local handles
// ═══════════════════════════════════════════════════════════════════

class MaterializeTab extends StatefulWidget {
  const MaterializeTab({super.key, required this.cellar});

  final Cellar cellar;

  @override
  State<MaterializeTab> createState() => _MaterializeTabState();
}

class _MaterializeTabState extends State<MaterializeTab>
    with AutomaticKeepAliveClientMixin, TabLog {
  MaterializedFile? handle;
  Uint8List? shownBytes;
  static const key = 'media/pixel';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabBody(
      children: [
        Section(
          'A handle the platform understands',
          'Non-Dart consumers (FFI, native plugins, <img> tags) need '
              'more than bytes: materialize() returns a real file path on '
              'native and a Blob URL on web. Release it when done.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OpButton(
                    'store PNG + materialize',
                    icon: Icons.image,
                    () async {
                      await run('materialize', () async {
                        await widget.cellar.write(
                          key,
                          tinyPng,
                          contentType: 'image/png',
                        );
                        final m = await widget.cellar.materialize(key);
                        final bytes = await widget.cellar.read(key);
                        setState(() {
                          handle = m;
                          shownBytes = bytes;
                        });
                        say(
                          '✓ handle: ${m.localPath}\n'
                          '   (${kIsWeb ? 'a Blob URL — usable as an <img> src' : 'a real file path — usable by FFI and native plugins'})',
                        );
                      });
                    },
                  ),
                  OpButton('release', icon: Icons.link_off, () async {
                    await run('release', () async {
                      await handle?.release();
                      setState(() {
                        handle = null;
                        shownBytes = null;
                      });
                      say('✓ released (temp cleaned / Blob URL revoked)');
                    });
                  }),
                ],
              ),
              if (handle != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Render the stored pixel scaled up — proof the bytes
                    // round-tripped as a real image the platform decodes.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: kIsWeb
                          ? Image.network(
                              handle!.localPath,
                              width: 48,
                              height: 48,
                              filterQuality: FilterQuality.none,
                            )
                          : Image.memory(
                              shownBytes!,
                              width: 48,
                              height: 48,
                              filterQuality: FilterQuality.none,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        handle!.localPath,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Section('Log', 'Newest first.', child: LogPane(logLines)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 7: Custom — your own backend + tenant scoping
// ═══════════════════════════════════════════════════════════════════

class CustomTab extends StatefulWidget {
  const CustomTab({super.key});

  @override
  State<CustomTab> createState() => _CustomTabState();
}

class _CustomTabState extends State<CustomTab>
    with AutomaticKeepAliveClientMixin, TabLog {
  // ONE custom backend, shared by two tenant-scoped cellars — the
  // keyPrefix machinery keeps them fully isolated.
  final shared = DemoMemoryBackend();
  late final Cellar alice;
  late final Cellar bob;
  Future<void>? _opening;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    alice = Cellar.withBackends(
      {'main': shared},
      defaultPartition: 'main',
      keyPrefix: 'user/alice',
    );
    bob = Cellar.withBackends(
      {'main': shared},
      defaultPartition: 'main',
      keyPrefix: 'user/bob',
    );
    _opening = Future.wait([alice.open(), bob.open()]);
  }

  @override
  void dispose() {
    alice.close();
    bob.close();
    shared.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabBody(
      children: [
        Section(
          'Bring your own backend',
          'DemoMemoryBackend implements the StorageBackend interface '
              '(in this file). Cellar.withBackends runs the whole facade '
              'on top of it — anything that stores bytes at a key can sit '
              'under cellar.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OpButton('write as alice', () async {
                await _opening;
                await run('write', () async {
                  await alice.write(
                    'photos/cat',
                    Uint8List.fromList(utf8.encode("alice's cat photo")),
                  );
                  say('✓ alice wrote photos/cat');
                });
              }),
              OpButton('list as alice', () async {
                await run('list', () async {
                  final l = await alice.list('');
                  say('✓ alice sees: ${l.map((o) => o.key).toList()}');
                });
              }),
              OpButton('list as bob', () async {
                await run('list', () async {
                  final l = await bob.list('');
                  say(
                    '✓ bob sees: ${l.map((o) => o.key).toList()} '
                    "— alice's data is invisible to him",
                  );
                });
              }),
              OpButton(
                'peek raw backend keys',
                icon: Icons.visibility,
                () async {
                  await run('peek', () async {
                    say(
                      '✓ raw keys in the shared backend: ${shared.rawKeys}\n'
                      '   (the tenant prefix is stamped on at rest — '
                      'isolation is structural, not cooperative)',
                    );
                  });
                },
              ),
            ],
          ),
        ),
        Section('Log', 'Newest first.', child: LogPane(logLines)),
      ],
    );
  }
}
