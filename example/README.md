# cellar_flutter example

A Flutter app exercising every capability of `cellar_flutter` (and,
through its re-export, the whole `cellar` core). One `openCellar()`
call opens the store; tap an operation, watch the log pane report what
happened. Everything runs on built-in fixtures — no file picker, no
setup, no account. Runs on macOS, iOS, Android, Windows, Linux, and
web; the chip in the app bar shows which warehouse this platform got
(real files on native, IndexedDB in browsers).

## Run

```bash
cd example

# native
fvm flutter run

# web
fvm flutter run -d chrome
```

## Tests

```bash
# journeys — host VM, no device needed: every tab driven end-to-end
# through the real UI on six device shapes (from the package root)
make test-example-matrix

# integration smoke — every API surface on a real platform
make test-example-macos          # or -android / -ios / -linux / -windows
make test-example-web            # via flutter drive + chromedriver
```

Journeys run the real storage stack on an in-memory disk
(`IOOverrides` + `MemoryFileSystem`) with path_provider faked at its
platform-interface seam; the smoke suite proves the real platform
path — `openCellar` asking the real path_provider on every target,
Android included.

## What's inside

Seven tabs, one per area of the API:

| Tab | API | What it covers |
|---|---|---|
| **Store** | `write` / `read` / `head` / `list` / `delete` | Keys in, bytes out: content types, custom metadata, a live object browser, and a typed `FileNotFoundError` caught by pattern-match |
| **Stream** | `writeStream` / `readStream` / `readRange` | 4 MiB streamed in with a live progress bar, streamed out chunk by chunk, and a 32-byte range read that only touches the overlapping chunks |
| **Partitions** | `partition:` routing, `copyAcrossPartitions`, `wipePartition` | Three compartments (`main` / `cache` / `scratch`), independent browsers per partition, cross-partition copy, one-tap wipe |
| **Lifecycle** | `Lifecycle`, `runLifecycleNow` | Overfill a 512 KiB-capped cache and evict on demand — oldest objects go first, live usage bar |
| **Encrypt** | `EncryptedBackend`, `FileEncryptor`, `EncryptionKeyResolver` | A complete demo encryptor (streaming chunks, per-chunk MACs, self-describing header) implemented in this file; peek the raw ciphertext at rest, flip one byte, watch MAC verification catch the tamper |
| **Materialize** | `materialize` / `MaterializedFile` | Store a PNG, get a handle the platform understands (file path on native, Blob URL on web), render it, release it |
| **Custom** | `StorageBackend`, `Cellar.withBackends`, `keyPrefix` | A Map-backed backend implemented in this file, driven by two tenant-scoped cellars sharing it — keyPrefix isolation shown at the raw-key level |

## One file on purpose

The whole app lives in `lib/main.dart` because pub.dev renders that
file as the package's Example tab — splitting it would hide
everything else from that page.

## The open seams, proven by inclusion

Cellar ships zero cryptography and treats backends as plugins. Both
seams are demonstrated by real implementations living in this file:
`DemoEncryptor` is a complete `FileEncryptor` (demo-grade keystream —
bring a vetted cipher for real data) and `DemoMemoryBackend` is a
complete `StorageBackend`. What you see is exactly what implementing
the interfaces takes.
