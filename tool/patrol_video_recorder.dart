import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef EmulatorCommand =
    Future<String> Function(List<String> arguments, {Duration timeout});

/// Records the selected emulator from before instrumentation through teardown.
/// Uses an unlimited recording rather than silently truncating at 180 seconds.
class PatrolVideoRecorder {
  PatrolVideoRecorder({
    required this.adb,
    required this.device,
    required this.runId,
    required this.output,
    required this.onDevice,
  }) {
    if (!RegExp(r'^emulator-\d+$').hasMatch(device) ||
        !RegExp(r'^\d+$').hasMatch(runId)) {
      throw ArgumentError('Expected an emulator serial and numeric run ID.');
    }
  }

  final String adb;
  final String device;
  final String runId;
  final Directory output;
  final EmulatorCommand onDevice;

  String get _remote => '/sdcard/Download/remindme_patrol_$runId.mp4';
  File get video => File('${output.path}/test.mp4');
  final _diagnostics = StringBuffer();
  Process? _process;
  Future<int>? _exit;
  Future<void>? _streamsDone;
  int? _exitCode;
  String? _pid;
  bool _ready = false;

  /// Read-only preflight; does not start recording.
  static Future<void> verifySupport(EmulatorCommand onDevice) async {
    if ((await onDevice(['shell', 'getprop', 'ro.kernel.qemu'])).trim() !=
        '1') {
      throw StateError('Video recording is restricted to Android emulators.');
    }
    final help = await onDevice(['shell', 'screenrecord', '--help']);
    if (!RegExp(
      r'Set to 0\s+to remove the time limit',
      caseSensitive: false,
    ).hasMatch(help)) {
      throw StateError(
        'This emulator cannot record the entire test without a '
        'three-minute cap. Use the current Google Play Pixel emulator with '
        'screenrecord --time-limit 0 support.',
      );
    }
  }

  Future<void> start() async {
    await verifySupport(onDevice);
    final size = await onDevice(['shell', 'wm', 'size']);
    final matches = RegExp(r'(\d+)x(\d+)').allMatches(size).toList();
    if (matches.isEmpty) {
      throw StateError('Cannot determine emulator display size.');
    }
    // Use the override size when present, preserving the display aspect ratio.
    final width = int.parse(matches.last.group(1)!);
    final height = int.parse(matches.last.group(2)!);
    if (width < 2 || height < 2) {
      throw StateError('Invalid emulator display size.');
    }
    final scale = width > 720 ? 720 / width : 1.0;
    final videoWidth = (width * scale / 2).floor() * 2;
    final videoHeight = (height * scale / 2).floor() * 2;
    _process = await Process.start(adb, [
      '-s',
      device,
      'shell',
      'screenrecord',
      '--time-limit',
      '0',
      '--size',
      '${videoWidth}x$videoHeight',
      '--bit-rate',
      '4000000',
      _remote,
    ], runInShell: false);
    final process = _process!;
    _exit = process.exitCode.then((code) {
      _exitCode = code;
      return code;
    });
    _streamsDone = Future.wait([
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(_diagnostics.write),
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(_diagnostics.write),
    ]).then((_) {});

    final clock = Stopwatch()..start();
    while (clock.elapsed < const Duration(seconds: 15)) {
      if (_exitCode != null) {
        throw StateError(
          'Recording exited before the test started: '
          '$_exitCode\n$_diagnostics',
        );
      }
      _pid = await _findOwnProcess();
      if (_pid != null) {
        try {
          final bytes = int.tryParse(
            (await onDevice(['shell', 'stat', '-c', '%s', _remote])).trim(),
          );
          if (bytes != null && bytes > 0 && _exitCode == null) {
            _ready = true;
            return;
          }
        } on StateError {
          // The encoder can exist before it creates its output file.
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError(
      'Recording did not become ready; no test was started. '
      '$_diagnostics',
    );
  }

  Future<String?> _findOwnProcess() async {
    final processes = await onDevice(['shell', 'ps', '-A', '-o', 'PID,NAME']);
    for (final line in const LineSplitter().convert(processes)) {
      final match = RegExp(r'^\s*(\d+)\s+screenrecord\s*$').firstMatch(line);
      if (match != null) {
        final pid = match.group(1)!;
        try {
          final arguments = (await onDevice([
            'shell',
            'cat',
            '/proc/$pid/cmdline',
          ])).split('\u0000');
          if (arguments.contains(_remote)) return pid;
        } on StateError {
          // The process may have exited between ps and the cmdline read.
        }
      }
    }
    return null;
  }

  /// SIGINT flushes the MP4 index. Only our exact recording PID is signalled.
  /// A partial recording is still pulled for review if the test failed.
  Future<void> stopAndCollect() async {
    if (_process == null) return;
    Object? failure;
    if (_ready && _exitCode != null) {
      failure = StateError(
        'Video recording ended before the test finished '
        '(exit $_exitCode). The video is incomplete.',
      );
    }
    try {
      if (_exitCode == null) {
        final livePid = await _findOwnProcess();
        if (livePid == null || (_pid != null && livePid != _pid)) {
          throw StateError('Cannot identify this run\'s recording process.');
        }
        _pid = livePid;
        await onDevice(['shell', 'kill', '-2', livePid]);
      }
      final code = await _exit!.timeout(const Duration(seconds: 15));
      await _streamsDone!.timeout(const Duration(seconds: 5));
      if (code != 0) {
        failure ??= StateError('Recording exited $code: $_diagnostics');
      }
    } catch (error) {
      failure ??= error;
      // Do not leave an indefinite recording running if graceful shutdown fails.
      try {
        final livePid = await _findOwnProcess();
        if (livePid != null && (_pid == null || livePid == _pid)) {
          await onDevice(['shell', 'kill', '-15', livePid]);
        }
      } catch (_) {
        // Keep the original error and the remote artifact path in diagnostics.
      }
      _process?.kill();
    }
    try {
      await onDevice(['pull', _remote, video.absolute.path]);
      await _validateMp4(video);
      // Delete only the exact temporary recording after a valid local copy exists.
      await onDevice(['shell', 'rm', '--', _remote]);
    } catch (error) {
      failure ??= error;
    } finally {
      File('${output.path}/recording.txt').writeAsStringSync(
        'Device: $device\nRemote recording: $_remote\n'
        'Ready before instrumentation: $_ready\n'
        'Encoder exit: $_exitCode\n$_diagnostics\n'
        '${failure ?? 'Recording finalized and collected.'}\n',
      );
    }
    if (failure != null) throw failure;
  }
}

/// Detect empty or unfinalized MP4 files without requiring ffmpeg/ffprobe.
Future<void> _validateMp4(File file) async {
  final input = await file.open();
  try {
    final length = await input.length();
    final boxes = <String>{};
    var offset = 0;
    while (offset + 8 <= length) {
      await input.setPosition(offset);
      final header = await input.read(8);
      var size = ByteData.sublistView(header).getUint32(0);
      final type = latin1.decode(header.sublist(4, 8));
      var headerSize = 8;
      if (size == 1) {
        final largeSize = await input.read(8);
        if (largeSize.length != 8) throw StateError('Truncated MP4 box: $type');
        size = ByteData.sublistView(largeSize).getUint64(0);
        headerSize = 16;
      } else if (size == 0) {
        size = length - offset;
      }
      if (size < headerSize || offset + size > length) {
        throw StateError('Invalid or truncated MP4 box: $type');
      }
      if (size > headerSize) boxes.add(type);
      offset += size;
    }
    if (offset != length || !boxes.containsAll({'ftyp', 'moov', 'mdat'})) {
      throw StateError(
        'Video is empty or its MP4 index was not finalized: ${file.path}',
      );
    }
  } finally {
    await input.close();
  }
}
