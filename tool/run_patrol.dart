import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'patrol_video_recorder.dart';

const _package = 'chimin.remindme';
const _testClass = 'chimin.remindme.PatrolMainTest';
const _usage = '''
Run only when real Google-account E2E execution is explicitly requested.

dart run tool/run_patrol.dart --device <adb-serial> --account <test-email>
    --dart-define-from-file secrets/build.json
    [--allow-unverified-app] [--stop-after-home]

Requires an unlocked English Android 10+ emulator with Google Play services.
Physical devices are refused.
Before EVERY run, manually revoke Remind Me access from the dedicated test Google account.
The Google Tasks consent prompt is mandatory; the test fails if it is absent.
The launcher does not reset Google consent automatically.
The launcher clears ALL local Remind Me data on the selected device.
Every run replaces numbered screenshots and patrol_test/golden/test.mp4 at stable paths.
''';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.write(_usage);
    return;
  }
  try {
    final options = <String, String>{};
    const allowed = {'--device', '--account', '--dart-define-from-file'};
    for (var i = 0; i < arguments.length; i++) {
      final option = arguments[i];
      if (const {
        '--allow-unverified-app',
        '--stop-after-home',
      }.contains(option)) {
        if (options.containsKey(option)) {
          throw FormatException('Repeated option: $option');
        }
        options[option] = 'true';
        continue;
      }
      if (!allowed.contains(option) ||
          i + 1 == arguments.length ||
          arguments[i + 1].startsWith('--') ||
          options.containsKey(option)) {
        throw FormatException(
          'Unknown, repeated, or incomplete option: $option',
        );
      }
      options[option] = arguments[++i];
    }
    final device = options['--device'];
    final account = options['--account'];
    final config = options['--dart-define-from-file'] ?? 'secrets/build.json';
    final stopAfterHome = options['--stop-after-home'] == 'true';
    if (device == null ||
        !RegExp(r'^[a-zA-Z0-9_.:-]+$').hasMatch(device) ||
        account == null ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(account)) {
      throw const FormatException('Supply --device and --account.');
    }
    final root = File.fromUri(Platform.script).parent.parent;
    Directory.current = root;
    if (!File('pubspec.yaml').existsSync() || !File(config).existsSync()) {
      throw StateError(
        'Run from the project checkout with an existing $config.',
      );
    }
    final defines = jsonDecode(File(config).readAsStringSync());
    if (defines is! Map ||
        defines['GOOGLE_WEB_CLIENT_ID'] is! String ||
        (defines['GOOGLE_WEB_CLIENT_ID'] as String).trim().isEmpty) {
      throw StateError('$config must contain GOOGLE_WEB_CLIENT_ID.');
    }
    final runId = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final adb = Platform.isWindows ? 'adb.exe' : 'adb';
    Future<String> onDevice(
      List<String> args, {
      Duration timeout = const Duration(minutes: 2),
    }) => _run(adb, ['-s', device, ...args], timeout: timeout);

    if ((await onDevice(['get-state'])).trim() != 'device') {
      throw StateError(
        'The selected Android device is not connected/authorized.',
      );
    }
    // Refuse physical hardware before installing or clearing any app data.
    if (!RegExp(r'^emulator-\d+$').hasMatch(device) ||
        (await onDevice(['shell', 'getprop', 'ro.kernel.qemu'])).trim() !=
            '1') {
      throw StateError(
        'Only Android emulators are allowed; physical devices are refused.',
      );
    }
    if (!(await onDevice([
      'shell',
      'pm',
      'path',
      'com.google.android.gms',
    ])).contains('package:')) {
      throw StateError('Google Play services is not installed on this device.');
    }
    final sdk = int.tryParse(
      (await onDevice(['shell', 'getprop', 'ro.build.version.sdk'])).trim(),
    );
    if (sdk == null || sdk < 29) {
      throw StateError(
        'Use Android 10+ for native screenshots without storage permissions.',
      );
    }
    var locale = (await onDevice([
      'shell',
      'getprop',
      'persist.sys.locale',
    ])).trim();
    if (locale.isEmpty) {
      locale = (await onDevice([
        'shell',
        'getprop',
        'ro.product.locale',
      ])).trim();
    }
    if (!locale.toLowerCase().startsWith('en')) {
      throw StateError(
        'Set the selected device language to English (found $locale).',
      );
    }
    await PatrolVideoRecorder.verifySupport(onDevice);
    final power = await onDevice(['shell', 'dumpsys', 'power']);
    final policy = await onDevice(['shell', 'dumpsys', 'window', 'policy']);
    if (!power.contains('mWakefulness=Awake') ||
        RegExp(
          r'(?:mShowingLockscreen|isStatusBarKeyguard|showing|inputRestricted)=true',
        ).hasMatch(policy)) {
      throw StateError('Wake and unlock the selected device before running.');
    }

    final packageInfo = await onDevice([
      'shell',
      'dumpsys',
      'package',
      _package,
    ]);
    final version = RegExp(r'versionCode=(\d+)').firstMatch(packageInfo);
    final buildNumber = (int.tryParse(version?.group(1) ?? '') ?? 0) + 1;
    stdout.writeln(
      'Building Patrol run $runId. Fresh Google Tasks consent is required; reset it manually before each run.',
    );
    await _run(
      Platform.resolvedExecutable,
      [
        'run',
        'patrol_cli:main',
        'build',
        'android',
        '--no-label',
        '--build-number',
        '$buildNumber',
        '--target',
        'patrol_test/main_test.dart',
        '--dart-define-from-file',
        File(config).absolute.path,
        '--dart-define',
        'PATROL_TEST_ACCOUNT=$account',
        '--dart-define',
        'PATROL_RUN_ID=$runId',
        '--dart-define',
        'PATROL_ALLOW_UNVERIFIED_APP=${options['--allow-unverified-app'] == 'true'}',
        '--dart-define',
        'PATROL_STOP_AFTER_HOME=$stopAfterHome',
      ],
      timeout: const Duration(minutes: 15),
      echo: true,
    );

    const appApk = 'build/app/outputs/apk/debug/app-debug.apk';
    const testApk =
        'build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk';
    for (final apk in [appApk, testApk]) {
      if (!File(apk).existsSync()) throw StateError('Built APK missing: $apk');
      await onDevice(['install', '-r', '-t', File(apk).absolute.path]);
    }
    final instrumentation = await onDevice([
      'shell',
      'pm',
      'list',
      'instrumentation',
    ]);
    const component = '$_package.test/pl.leancode.patrol.PatrolJUnitRunner';
    if (!instrumentation.contains(
      'instrumentation:$component (target=$_package)',
    )) {
      throw StateError(
        'Patrol instrumentation is missing; refusing to launch.',
      );
    }
    stdout.writeln('Clearing all local $_package data on $device.');
    await onDevice(['shell', 'am', 'force-stop', _package]);
    final cleared = await onDevice(['shell', 'pm', 'clear', _package]);
    if (cleared.trim() != 'Success') {
      throw StateError('App data reset did not succeed: $cleared');
    }

    final output = Directory('patrol_test/golden');
    final screenshots = Directory('screenshots/e2e');
    preparePatrolArtifacts(output, screenshots: screenshots);
    final recording = PatrolVideoRecorder(
      adb: adb,
      device: device,
      runId: runId,
      output: output,
      onDevice: onDevice,
    );
    String? testOutput;
    Object? runFailure;
    try {
      // Start before native discovery launches the app, so Google UI, task
      // actions, final sign-out, and test cleanup are all part of the video.
      await recording.start();
      stdout.writeln('Recording the complete test on $device.');
      testOutput = await onDevice([
        'shell',
        'am',
        'instrument',
        '-w',
        '-r',
        '-e',
        'class',
        _testClass,
        component,
      ], timeout: const Duration(minutes: 10));
      stdout.write(testOutput);
      File('${output.path}/instrumentation.txt').writeAsStringSync(testOutput);
      if (!RegExp(r'OK \(1 test\)').hasMatch(testOutput) ||
          RegExp(
            r'FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed|shortMsg=',
          ).hasMatch(testOutput)) {
        throw StateError(
          'Patrol flow failed or did not execute exactly one test.',
        );
      }
    } catch (error) {
      runFailure = error;
      if (testOutput == null) {
        File(
          '${output.path}/instrumentation.txt',
        ).writeAsStringSync('$error\n');
      }
    } finally {
      try {
        await recording.stopAndCollect();
      } catch (error) {
        stderr.writeln('Video recording/collection failed: $error');
        runFailure ??= error;
      }
      try {
        // Android may terminate the instrumentation process before returning
        // its result; retained logcat tags remain available after it exits.
        File('${output.path}/device.log').writeAsStringSync(
          await onDevice([
            'logcat',
            '-d',
            '-t',
            '2000',
            '-s',
            'flutter',
            'PatrolServer',
            'TestRunner',
          ]),
        );
      } catch (error) {
        stderr.writeln('Device log collection failed: $error');
      }
      // Stop a timed-out instrumentation process before collecting evidence.
      try {
        await onDevice(['shell', 'am', 'force-stop', _package]);
        await collectPatrolScreenshots(
          onDevice,
          output,
          runId,
          stopAfterHome: stopAfterHome,
          screenshots: screenshots,
        );
      } catch (error) {
        stderr.writeln('Evidence collection/stop failed: $error');
        runFailure ??= error;
      }
    }
    if (runFailure != null) throw runFailure;
    stdout.writeln(
      'Patrol ${stopAfterHome ? 'sign-in check' : 'task lifecycle'} '
      'passed. Screenshots: ${screenshots.path}; video: ${output.path}',
    );
  } catch (error) {
    stderr.writeln('$error\n$_usage');
    exitCode = 1;
  }
}

/// Replaces only this launcher's artifacts before a new test attempt.
/// Unreached checkpoints must not look like screenshots from the current run.
void preparePatrolArtifacts(Directory output, {Directory? screenshots}) {
  output.createSync(recursive: true);
  final screenshotDirectory = screenshots ?? output;
  screenshotDirectory.createSync(recursive: true);
  final screenshot = RegExp(r'^\d{2}_[a-z0-9_]+\.png$');
  for (final entry in screenshotDirectory.listSync(followLinks: false)) {
    if (entry is File && screenshot.hasMatch(entry.uri.pathSegments.last)) {
      entry.deleteSync();
    }
  }
  const diagnostics = {
    'test.mp4',
    'recording.txt',
    'instrumentation.txt',
    'device.log',
  };
  for (final entry in output.listSync(followLinks: false)) {
    if (entry is! File) continue;
    final name = entry.uri.pathSegments.last;
    if (diagnostics.contains(name)) {
      entry.deleteSync();
    }
  }
}

/// Can also recover screenshots after an interrupted artifact pull, without
/// starting instrumentation or rerunning the test.
Future<void> collectPatrolScreenshots(
  Future<String> Function(List<String>, {Duration timeout}) onDevice,
  Directory output,
  String runId, {
  bool stopAfterHome = false,
  Directory? screenshots,
}) async {
  if (!RegExp(r'^\d+$').hasMatch(runId)) throw ArgumentError('Invalid run ID.');
  // Native filenames include a timestamp and run ID. Keep those on-device to
  // reject stale captures, but use fixed numbered filenames for Git history.
  const remoteRoot = '/sdcard/Download/screenshots/$_testClass';
  final listing = await onDevice(['shell', 'find', remoteRoot, '-type', 'f']);
  final pattern = RegExp(
    r'^(?:(\d+)_)?' + RegExp.escape(runId) + r'_(\d{2}_[a-z0-9_]+)\.png$',
  );
  final latest = <String, ({String remote, int timestamp})>{};
  for (final remote in const LineSplitter().convert(listing)) {
    if (!remote.startsWith('$remoteRoot/')) continue;
    final match = pattern.firstMatch(remote.split('/').last);
    if (match == null) continue;
    final point = match.group(2)!;
    final timestamp = int.tryParse(match.group(1) ?? '') ?? 0;
    final previous = latest[point];
    if (previous == null ||
        timestamp > previous.timestamp ||
        (timestamp == previous.timestamp &&
            remote.compareTo(previous.remote) > 0)) {
      latest[point] = (remote: remote, timestamp: timestamp);
    }
  }
  final captured = <String>{};
  final points = latest.keys.toList()..sort();
  for (final point in points) {
    final local = File('${(screenshots ?? output).path}/$point.png');
    await local.parent.create(recursive: true);
    await onDevice(['pull', latest[point]!.remote, local.absolute.path]);
    if (!local.existsSync() || local.lengthSync() == 0) {
      throw StateError('Empty screenshot: $point.png');
    }
    captured.add(point);
  }
  if (captured.isEmpty) {
    throw StateError('No screenshots were collected for $runId.');
  }
  // A passing instrumentation run must include all requested milestones.
  final log = File('${output.path}/instrumentation.txt');
  if (log.existsSync() &&
      RegExp(r'OK \(1 test\)').hasMatch(log.readAsStringSync())) {
    for (final point in [
      '01_sign_in_required',
      '04_tasks_consent',
      '06_home',
      if (!stopAfterHome) ...[
        '07_new_task_form',
        '08_created',
        '09_edited_task_form',
        '10_edited',
        '11_before_delete',
        '12_delete_confirmation',
        '13_deleted',
        '14_sign_out_confirmation',
        '15_sign_in_required',
        '16_sign_in_canceled',
      ],
    ]) {
      if (!captured.contains(point)) {
        throw StateError('Required screenshot missing: $point');
      }
    }
  }
}

Future<String> _run(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  Duration timeout = const Duration(minutes: 2),
  bool echo = false,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
    runInShell: false,
  );
  var timedOut = false;
  final timer = Timer(timeout, () {
    timedOut = true;
    process.kill();
  });
  final out = StringBuffer();
  final err = StringBuffer();
  final reads = [
    process.stdout.transform(const Utf8Decoder(allowMalformed: true)).forEach((
      text,
    ) {
      out.write(text);
      if (echo) stdout.write(text);
    }),
    process.stderr.transform(const Utf8Decoder(allowMalformed: true)).forEach((
      text,
    ) {
      err.write(text);
      if (echo) stderr.write(text);
    }),
  ];
  try {
    final code = await process.exitCode;
    await Future.wait(reads);
    if (timedOut) {
      throw TimeoutException('$executable timed out\n$out\n$err', timeout);
    }
    if (code != 0) throw StateError('$executable exited $code\n$out\n$err');
    return '$out$err';
  } finally {
    timer.cancel();
  }
}
