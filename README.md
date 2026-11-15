# zero_video_windows

Windows video playback for the `zero_*` stack.

Flutter's official `video_player` ships implementations for **android, ios, macos and web only**. On Windows, `VideoPlayerPlatform.instance` stays at the placeholder that throws — so `zero_cached_video`, `PublicOSVideo` and anything else built on `VideoPlayerController` compiles, builds, and then dies on `initialize()`. This repo supplies the missing backend, built on [media_kit](https://github.com/media-kit/media-kit) (libmpv).

Nothing above the platform interface has to change. `zero_cached_video` is untouched and stays cross-platform; the widget tree never learns which backend is registered.

## Packages

| Package | What it is |
|---|---|
| `packages/zero_video_windows` | The `VideoPlayerPlatform` implementation. Fork of `video_player_media_kit` (421 LOC). Call `ZeroVideoWindows.ensureInitialized()` from `main()`. |
| `packages/media_kit_libs_windows_video` | Hard fork of the upstream libs package. Supplies libmpv + ANGLE, **vendored in-repo and SHA-256 pinned**. |

`media_kit`, `media_kit_video` and `media_kit_native_event_loop` are consumed unforked from pub.dev — they are MIT, compile from source, and fetch nothing at build time.

## Usage

```yaml
dependencies:
  zero_video_windows:
    path: ../zero_video_windows/packages/zero_video_windows
```

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ZeroVideoWindows.ensureInitialized(); // no-op off Windows
  runApp(const MyApp());
}
```

## Why the libs package is forked

Upstream `media_kit_libs_windows_video` is 31 KB on pub.dev because it **downloads its binaries at build time**: `libmpv-2.dll` from a GitHub release, and `ANGLE.7z` from a personal repo, both pinned with **MD5**. Three problems, in order of how much they matter:

1. **The libmpv build is from 2023-09-24, and the repo that produced it was archived in October 2024.** That decoder parses untrusted video from arbitrary RSS feeds. It is the reason to own this.
2. The build reaches out to third-party GitHub releases to compile. It fails when they do.
3. MD5 is not an integrity guarantee worth the name.

This fork vendors both archives under `packages/media_kit_libs_windows_video/windows/binaries/`, verifies them with **SHA-256**, and extracts them at **configure** time (upstream extracts in an `add_custom_target` with no dependency edge to `media_kit_video`'s compile step, so the mpv headers can in principle be consumed before they exist).

**The fork keeps the upstream package name on purpose.** Flutter adds Windows plugin subdirectories in *alphabetical* order, and `media_kit_video` only finds the native libraries if the package that sets `MEDIA_KIT_LIBS_AVAILABLE` is configured first. `media_kit_libs_windows_video` < `media_kit_video`. A fork renamed to `zero_*` would sort *after* it and silently take the "libs not found" branch.

## Licensing

Verified by reading the shipped binary, not the marketing:

- **mpv v0.36.0-403-g652a1dd907, built `-Dgpl=false`** → LGPL.
- **FFmpeg `--disable-gpl --disable-nonfree --enable-version3`**; every lib self-reports *"LGPL version 3 or later"*.

So the native stack is **LGPLv3, with no GPL component**, which a proprietary app may ship: `libmpv-2.dll` is dynamically linked and sits loose next to the `.exe`, so the "user may replace the library" obligation is satisfied as-is. Ship the license texts (`THIRD_PARTY_LICENSES.md`) with the app.

The Dart in this repo is MIT, as is the upstream it forks.

## Deltas vs upstream (both are bug fixes)

The body of `zero_video_player.dart` is otherwise faithful to upstream so it stays diffable. Each change is marked `DELTA` in the source.

1. **A failed source hung instead of erroring.** Upstream's error listener awaits `completer.future`, which only completes once width, height *and* duration arrive — exactly what never happens for a source that failed to load. So the error was never delivered, `initialize()` never returned, and the UI spun forever. Reproduced against a 404, then fixed by surfacing the error before releasing the completer. **This one was going to bite the moment a feed carried a dead video URL.**
2. `_completers` entries are now removed on `dispose()`/`init()`. Upstream leaks them for the process lifetime.

## Verification

`packages/zero_video_windows/example` is the smoke harness — two panes, video left, live log right, and it runs the whole matrix unattended on launch. Observed on Windows 11:

| Case | Result |
|---|---|
| mp4 / H.264 | initialized 604ms, 1280x720, position advances — **decoding** |
| webm / VP9 | initialized 1002ms, 640x360, position advances — **decoding** |
| dead url | fails loudly with `PlatformException` (hung, before the fix) |

The VP9 row is the one that matters: it is the case Media Foundation needs a Store codec extension for, and it is why this is built on libmpv rather than `video_player_win`.

## Refreshing the native libraries

The vendored libmpv is stale (see above). To replace it:

1. Drop a new `mpv-dev-x86_64-*.7z` at `windows/binaries/libmpv.7z`.
2. Update `LIBMPV_SHA256` in `windows/CMakeLists.txt`.
3. Delete the build dir (the extract is skipped when the target dir is non-empty).

⚠ **Check the license flags of any replacement.** [shinchiro/mpv-winbuild-cmake](https://github.com/shinchiro/mpv-winbuild-cmake) publishes daily `mpv-dev` builds, but those are **standard mpv — GPL**, which would contaminate a proprietary app. A clean refresh means building mpv with `-Dgpl=false` and FFmpeg with `--disable-gpl`, i.e. standing up our own CI. Confirm with:

```bash
strings -n 4 libmpv-2.dll | grep -oE '\-Dgpl=(true|false)'
strings -n 6 libmpv-2.dll | grep -i 'libavcodec license'
```
