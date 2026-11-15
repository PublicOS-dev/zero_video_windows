// Example + smoke harness for zero_video_windows.
//
// Two panes: the live video on the left, a running log on the right. The log is
// the point — a plugin that fails does so in the platform channel, not on screen,
// so the app has to show you what the backend actually said.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zero_video_windows/zero_video_windows.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ZeroVideoWindows.ensureInitialized();
  runApp(const ExampleApp());
}

class _Case {
  const _Case(this.label, this.url, {this.expectFailure = false});
  final String label;
  final String url;
  final bool expectFailure;
}

const _cases = <_Case>[
  _Case(
    'mp4 / H.264',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ),
  // The case that decided media_kit over video_player_win: Media Foundation
  // needs a Store codec extension for VP9, libmpv decodes it out of the box.
  _Case(
    'webm / VP9',
    'https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c0/Big_Buck_Bunny_4K.webm/Big_Buck_Bunny_4K.webm.360p.vp9.webm',
  ),
  // Must fail loudly rather than hang. See README § Known defects.
  _Case(
    'dead url',
    'https://feeds.publicos.dev/this-does-not-exist.mp4',
    expectFailure: true,
  ),
];

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zero_video_windows',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  final _log = <String>[];
  final _scroll = ScrollController();

  VideoPlayerController? _controller;
  _Case? _current;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _say('platform = ${VideoPlayerPlatform.instance.runtimeType}');
    _say('---');
    // Run the whole matrix unattended, so the log is a verdict and not a chore.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final c in _cases) {
        await _run(c);
      }
      _say('done');
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _say(String line) {
    // Mirrored to stdout so the harness is scriptable, not just watchable.
    stdout.writeln('SMOKE| $line');
    if (!mounted) return;
    setState(() => _log.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _run(_Case c) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _current = c;
    });

    await _controller?.dispose();
    _controller = null;

    _say('> ${c.label}');
    final controller = VideoPlayerController.networkUrl(Uri.parse(c.url));
    final started = DateTime.now();

    try {
      await controller.initialize().timeout(const Duration(seconds: 25));
      final v = controller.value;
      final ms = DateTime.now().difference(started).inMilliseconds;

      _say('  initialized in ${ms}ms');
      _say('  size ${v.size.width.toInt()}x${v.size.height.toInt()}');
      _say('  duration ${v.duration.inSeconds}s');

      setState(() => _controller = controller);
      await controller.play();
      await Future<void>.delayed(const Duration(seconds: 2));

      final pos = await controller.position ?? Duration.zero;
      if (pos > Duration.zero) {
        _say('  PASS decoding - position advanced to ${pos.inMilliseconds}ms');
      } else {
        _say('  FAIL position never advanced (opened but not decoding)');
      }
      if (c.expectFailure) _say('  FAIL expected this to fail, but it played');
    } on TimeoutException {
      await controller.dispose();
      _say(c.expectFailure
          ? '  FAIL hung - never initialized, never errored (known defect 2)'
          : '  FAIL timeout after 25s');
    } catch (e) {
      await controller.dispose();
      _say(c.expectFailure
          ? '  PASS failed loudly: ${e.runtimeType}'
          : '  FAIL ${e.runtimeType}: $e');
    } finally {
      _say('---');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('zero_video_windows'),
        actions: [
          for (final c in _cases)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                onPressed: _busy ? null : () => _run(c),
                child: Text(c.label),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: controller != null && controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    )
                  : Text(
                      _busy
                          ? 'loading ${_current?.label ?? ''}...'
                          : 'pick a case above',
                      style: const TextStyle(color: Colors.white38),
                    ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF0B0B0F),
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _log.length,
                itemBuilder: (_, i) => Text(
                  _log[i],
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    height: 1.5,
                    color: _log[i].contains('FAIL')
                        ? const Color(0xFFFF6B6B)
                        : _log[i].contains('PASS')
                            ? const Color(0xFF4ADE80)
                            : Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
