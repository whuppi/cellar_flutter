<!--
  Banner stays <picture> for GitHub's dark/light rendering. pub.dev strips
  <picture> when sanitizing the README and falls back to the inner <img>
  (the light variant) — which renders fine there. The heavy *-3x.png
  sources stay tracked in git; only the optimized *-web-min.webp files
  ship in the pub archive (see .pubignore). Drop the <picture> wrapper
  once pub.dev renders it. Tracking: dart-lang/pub-dev#5923.
-->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)"  srcset="assets/cellar_flutter-banner-dark-web-min.webp">
    <source media="(prefers-color-scheme: light)" srcset="assets/cellar_flutter-banner-light-web-min.webp">
    <img alt="cellar_flutter — object storage for Flutter apps"
         src="assets/cellar_flutter-banner-light-web-min.webp" width="100%">
  </picture>
</p>

<p align="center">
  <a href="https://pub.dev/packages/cellar_flutter"><img src="https://img.shields.io/pub/v/cellar_flutter.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/cellar_flutter/score"><img src="https://img.shields.io/pub/likes/cellar_flutter" alt="likes"></a>
  <a href="https://pub.dev/packages/cellar_flutter/score"><img src="https://img.shields.io/pub/points/cellar_flutter" alt="pub points"></a>
  <a href="https://github.com/whuppi/cellar_flutter"><img src="https://img.shields.io/github/stars/whuppi/cellar_flutter?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

Object storage for Flutter apps. One `openCellar()` call gives you a ready-to-use store on iOS, Android, macOS, Windows, Linux, and web — real files on native, IndexedDB in the browser, identical API everywhere.

Named partitions with self-cleaning lifecycle rules, tenant scoping, bring-your-own encryption, streaming I/O that never buffers a whole object, atomic writes, typed errors, and platform-local handles for FFI and browser APIs. No `kIsWeb`, no platform branches, no setup — anywhere in your code.

> like it? a [⭐ star](https://github.com/whuppi/cellar_flutter) or [👍 like](https://pub.dev/packages/cellar_flutter) is the entire marketing budget. [Bugs & features →](https://github.com/whuppi/cellar_flutter/issues)

---

<details>
<summary><b>👀 Peek inside</b></summary>

- [Install](#install)
- [Quick start](#quick-start)
- [Usage](#usage)
  - [Store](#store)
  - [Partitions](#partitions)
  - [Lifecycle](#lifecycle)
  - [Stream](#stream)
  - [Encrypt](#encrypt)
  - [Materialize](#materialize)
  - [Tenant scoping](#tenant-scoping)
- [Error handling](#error-handling)
- [Platform support](#platform-support)
  - [Where the data lands](#where-the-data-lands)
- [How this relates to `cellar`](#how-this-relates-to-cellar)
- [Not in the box](#not-in-the-box)
- [Example](#example)
- [Docs](#docs)

</details>

---

## Install

```yaml
dependencies:
  cellar_flutter: ^1.0.0-dev.0
```

No permissions, no manifest entries, no per-platform Dart — storage lands in your app's private area, which every OS grants for free.

---

## Quick start

One call opens the store; then it's keys in, bytes out:

```dart
import 'package:cellar_flutter/cellar_flutter.dart';

final cellar = await openCellar(name: 'my_app');

await cellar.write('notes/hello', bytes, contentType: 'text/plain');
final back = await cellar.read('notes/hello');
final exists = await cellar.exists('notes/hello');
await cellar.delete('notes/hello');

await cellar.close(); // app shutdown, profile switch, etc.
```

`openCellar` is byte-identical on all six platforms. That's the shape of every call after it: a `/`-separated key in, bytes or metadata out — `write`, `read`, `head`, `list`, `copy`, `materialize`.

<details>
<summary><b>🧩 what openCellar actually does</b></summary>

<br>

Three steps: resolve where your app's storage lives, construct the `Cellar`, `await` its `open()` — then hand it back ready.

The resolution step is the reason this package exists. The core never guesses where data lives — locations must be supplied. On native platforms `openCellar` asks path_provider for two directories: the **support** directory (persistent partitions) and the **cache** directory (partitions the OS may also evict) — the app's official locations, straight from the OS. On web there's nothing to resolve at all: storage is IndexedDB, and the ask is skipped (the path_provider code sits behind a conditional import, so web builds never even compile it).

You never see any of this — it's the machinery the one call wraps.

</details>

---

## Usage

The full API comes re-exported from [`cellar`](https://github.com/whuppi/cellar) — one import serves everything below. Highlights here; every method and full signature lives in the [API reference](https://pub.dev/documentation/cellar_flutter/latest/).

### Store

Bytes with optional content type and custom metadata; metadata reads never touch bodies:

```dart
await cellar.write(
  'docs/report',
  bytes,
  contentType: 'application/pdf',
  metadata: {'source': 'export', 'v': '2'},
);

final info = await cellar.head('docs/report');   // size, type, metadata, lastModified
final all = await cellar.list('docs/');          // ObjectInfo per key, body-free
await cellar.copy('docs/report', 'docs/report_backup');
await cellar.deletePrefix('docs/');              // bulk delete by prefix
```

Keys are a grammar, not file paths: `/`-separated segments, same rules on every platform, validated up front. Prefixes are raw string prefixes, S3-style — end with `/` to scope to a pseudo-directory.

The full facade, all the same shape: `write` / `writeStream`, `read` / `readStream` / `readRange`, `head`, `exists`, `list` / `listKeys`, `delete` / `deletePrefix`, `copy`, `move`, `copyAcrossPartitions` / `moveAcrossPartitions`, `wipePartition`, `movePartition`, `updateMetadata`, `materialize`, `totalSize`, `fileSize`.

### Partitions

Named categories of data, each with its own rules — permanent vs cache vs scratch, backed-up vs excluded:

```dart
final cellar = await openCellar(
  name: 'my_app',
  partitions: {
    'main': PartitionConfig(),                                    // permanent, backed up
    'image_cache': PartitionConfig(
      lifecycle: Lifecycle.cache(maxBytes: 100 * 1024 * 1024),    // 100 MB cap
      osBackup: false,                                            // skip iCloud / Time Machine
    ),
    'pending_uploads': PartitionConfig(lifecycle: Lifecycle.scratch()), // wipe on open
  },
  defaultPartition: 'main',
);

await cellar.write('messages/abc', bytes);                        // default partition
await cellar.write('thumb/abc', smallBytes, partition: 'image_cache');
await cellar.wipePartition('image_cache');                        // one atomic wipe
```

Cross-partition `copyAcrossPartitions` / `moveAcrossPartitions` stream through with metadata.

### Lifecycle

Self-cleaning caches. A background timer evaluates every partition's rules; `runLifecycleNow()` runs a pass on demand; eviction failures surface through `onEvictionError` and never wedge the sweep:

```dart
'image_cache': PartitionConfig(
  lifecycle: Lifecycle.cache(maxBytes: 100 * 1024 * 1024),  // oldest evicted first
),
'downloads': PartitionConfig(
  lifecycle: Lifecycle(maxAge: Duration(days: 30), runInterval: Duration(hours: 6)),
),
'scratch': PartitionConfig(lifecycle: Lifecycle.scratch()), // wiped on every open
```

`Lifecycle.cache` also opts into OS-assisted eviction (`osManaged`) — on iOS and Android the partition lives in the cache directory the OS may sweep under storage pressure. Your rules run everywhere regardless.

### Stream

For audio, video, model weights, downloads — anything that shouldn't live in memory:

```dart
// Write from a stream — only one chunk in memory at a time.
await cellar.writeStream(
  'models/llama-7b.gguf',
  downloadStream,
  onProgress: (written, total) => updateBar(written),
);

// Read as a stream — playback, processing, forwarding.
await for (final chunk in cellar.readStream('models/llama-7b.gguf')) { /* … */ }

// Read just a byte range — seeking in media, header parsing.
final slice = await cellar.readRange('audio/song.mp3', start: 44100, length: 8192);
```

Memory stays constant regardless of object size. Writes are atomic on every platform: a crash mid-write leaves the previous object fully intact, never a torn file.

### Encrypt

Cellar ships **zero cryptography**. Implement two small interfaces over the crypto of your choice and every write is encrypted transparently — streaming chunks, per-chunk MACs, tamper detection that names the exact chunk:

```dart
final cellar = await openCellar(
  name: 'my_app',
  encryption: CellarEncryption(
    encryptor: myEncryptor,        // your FileEncryptor
    keyResolver: myKeyResolver,    // your EncryptionKeyResolver
    encryptByDefault: true,
  ),
);

await cellar.write('diary/today', entryBytes);   // stored as ciphertext
final entry = await cellar.read('diary/today');  // decrypted automatically

await cellar.write('cache/thumb', data, encrypt: false);  // per-write opt-out
```

The [example app](example/) contains a complete working `FileEncryptor` — what you see there is exactly what implementing the seam takes.

### Materialize

Some consumers need a real path or URL, not Dart bytes — native libraries via FFI, plugins that take a `File`, `<img>`/`<audio>` elements:

```dart
final handle = await cellar.materialize('models/llama-7b.gguf');

nativeLib.loadModel(handle.localPath);  // native: a real filesystem path
// imgElement.src = handle.localPath;   // web: a Blob URL

await handle.release();                 // frees temps / revokes the URL
```

Decryption is transparent; deleting a key never invalidates a live handle — on any OS.

### Tenant scoping

One `keyPrefix` stamps a namespace onto every key — per-user data, test isolation:

```dart
final cellar = await openCellar(name: 'my_app', keyPrefix: 'user/$uid');

await cellar.write('photos/cat', bytes);   // stored at user/<uid>/photos/cat
final all = await cellar.list('');         // keys come back scope-relative: photos/cat
```

Results speak the same scope-relative keys you write with; the prefix exists only at rest. One cellar = one namespace — apps needing several open several cellars.

---

## Error handling

Failures are a sealed hierarchy — pattern-match the ones you can act on:

```dart
try {
  await cellar.read('missing');
} on FileNotFoundError catch (e) {
  print('missing key: ${e.key}');
} on ChunkVerificationError catch (e) {
  print('tampered chunk ${e.chunkIndex}');
} on StorageError catch (e) {
  print('storage error: $e');
}
```

`FileNotFoundError`, `EncryptionKeyMissingError` (never silent ciphertext), `CorruptedFileError`, `CorruptedMetadataError`, `ChunkVerificationError`, `InvalidHeaderError`, `InvalidKeyError`, `WriteError`. Plain `throw`s are reserved for programmer error (`StateError` on a closed cellar, `ArgumentError` on bad configuration).

---

## Platform support

| iOS | Android | macOS | Windows | Linux | Web |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ IndexedDB |

### Where the data lands

| Platform | Persistent partitions | `osManaged` partitions |
|---|---|---|
| iOS, Android, macOS, Windows, Linux | app support directory | app cache directory (OS may evict on mobile) |
| Web | IndexedDB (one database per partition) | same |

Both directories come from path_provider — app-private, no permissions, cleaned up on uninstall. Need a location outside them (Downloads, external storage)? Drop to `Cellar.atPath` with any directory you've obtained — it's re-exported here too.

---

## How this relates to `cellar`

[`cellar`](https://github.com/whuppi/cellar) is the pure-Dart core — the entire engine, with zero Flutter in it, usable from servers and CLIs. This package adds the one thing a Flutter app needs on top: storage-root resolution through path_provider (Android's directories are only knowable by asking the OS), wrapped in `openCellar`, plus a re-export of the full core API.

Rule of thumb: **Flutter app → this package. Anything else → `cellar`.** You never need both in one pubspec.

---

## Not in the box

- **Queries, key-value prefs, sync, user-visible files** — the core's [Not in the box](https://github.com/whuppi/cellar#not-in-the-box) covers what cellar deliberately isn't, with a reasoned WONT_DO row each.
- **Widgets** — this package is storage, not UI; pair `materialize` with your image/video widgets.
- **Permission flows** — cellar's locations need none on any platform.

Missing something? [Open an issue](https://github.com/whuppi/cellar_flutter/issues).

---

## Example

The [example app](example/) exercises every capability in one file — seven tabs: store, streaming with live progress, partitions, lifecycle eviction, encryption (with raw-ciphertext peek and a tamper demo), materialization, and a custom in-memory backend with two tenant-scoped cellars.

---

## Docs

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | This package's contract, tree, and test model |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | Status per capability |
| [Updating](docs/UPDATING.md) | Maintenance recipes and the pinned-behavior watchlist |
| [Contributing](CONTRIBUTING.md) | Setup, PR workflow, keeping openCellar in lockstep with the core |
| [cellar's docs](https://github.com/whuppi/cellar/tree/v1.0.0-dev.0/docs) | The engine's architecture, durability mechanics, roadmap |

---

## License

MIT. See [LICENSE](LICENSE).
