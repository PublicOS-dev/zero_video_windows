/// Windows backend for package:video_player.
///
/// The official `video_player` declares implementations for android, ios, macos
/// and web only. On Windows `VideoPlayerPlatform.instance` stays at the
/// placeholder that throws, so a `VideoPlayerController` compiles and then dies
/// on `initialize()`. Calling [ZeroVideoWindows.ensureInitialized] from `main()`
/// installs a libmpv-backed implementation instead.
///
/// Nothing above the platform interface changes: `zero_cached_video`,
/// `PublicOSVideo` and every widget built on `VideoPlayerController` keep
/// working untouched, on every platform.
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   ZeroVideoWindows.ensureInitialized();
///   runApp(const MyApp());
/// }
/// ```
library;

import 'dart:io';

import 'package:media_kit/media_kit.dart';

import 'package:zero_video_windows/src/zero_video_player.dart';

export 'package:zero_video_windows/src/zero_video_player.dart'
    show ZeroVideoPlayer;

/// Installs the libmpv-backed [VideoPlayerPlatform] on Windows.
abstract final class ZeroVideoWindows {
  static bool _initialized = false;

  /// Registers the Windows backend. No-op off Windows, and no-op if already
  /// registered, so it is safe to call from anywhere during startup.
  ///
  /// Call before the first `VideoPlayerController` is constructed.
  static void ensureInitialized() {
    if (_initialized || !Platform.isWindows) return;

    MediaKit.ensureInitialized();
    ZeroVideoPlayer.registerWith();

    _initialized = true;
  }
}
