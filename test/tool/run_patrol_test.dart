import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/run_patrol.dart';

const _remoteRoot =
    '/sdcard/Download/screenshots/chimin.remindme.PatrolMainTest';

class _ScreenshotDevice {
  _ScreenshotDevice(this.files);

  final List<String> files;
  final List<String> pulled = [];
  bool empty = false;

  Future<String> run(
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (arguments.first == 'shell') return files.join('\n');
    expect(arguments.first, 'pull');
    pulled.add(arguments[1]);
    await File(arguments[2]).writeAsString(empty ? '' : arguments[1]);
    return '';
  }
}

void main() {
  late Directory output;

  setUp(() async {
    output = await Directory.systemTemp.createTemp(
      'remindme_patrol_artifacts_',
    );
  });

  tearDown(() async {
    expect(
      output.absolute.path,
      startsWith(Directory.systemTemp.absolute.path),
    );
    await output.delete(recursive: true);
  });

  test(
    'prepare artifacts should remove stale captures when a new test attempt starts',
    () async {
      for (final name in [
        '01_sign_in_required.png',
        '02_development_warning.png',
        '16_sign_in_canceled.png',
        '99_failure_FAILED.png',
        '01_sign_in_required_FAILED.png',
        'test.mp4',
        'instrumentation.txt',
        'device.log',
        'recording.txt',
        'screenshot_comparison.json',
        'notes.txt',
        'reference.png',
      ]) {
        final file = File('${output.path}/$name');
        await file.parent.create(recursive: true);
        await file.writeAsString('previous run');
      }
      final history = Directory('${output.path}/123')..createSync();
      await File('${history.path}/test.mp4').writeAsString('history');

      final raw = File('${output.path}/screenshots/01_sign_in_required.png');
      await raw.parent.create();
      await raw.writeAsString('previous actual');
      preparePatrolArtifacts(output);
      expect(await raw.exists(), isFalse);

      final remaining = output
          .listSync()
          .map(
            (entry) =>
                entry.uri.pathSegments.where((part) => part.isNotEmpty).last,
          )
          .toSet();
      expect(remaining, {
        '123',
        'screenshots',
        'notes.txt',
        'reference.png',
        '01_sign_in_required.png',
        '02_development_warning.png',
        '16_sign_in_canceled.png',
      });
      expect(await File('${history.path}/test.mp4').readAsString(), 'history');
    },
  );

  test(
    'collect screenshots should reuse numbered filenames when native captures repeat or include other runs',
    () async {
      final device = _ScreenshotDevice([
        '$_remoteRoot/nested/1000_42_01_sign_in_required.png',
        '$_remoteRoot/nested/900_42_01_sign_in_required.png',
        '$_remoteRoot/nested/1100_442_01_sign_in_required.png',
        '/somewhere/1200_42_01_sign_in_required.png',
        '$_remoteRoot/nested/1100_42_04_tasks_consent.png',
        '$_remoteRoot/nested/1200_42_99_failure.png',
      ]);
      final oldLogin = File('${output.path}/01_sign_in_required.png');
      await oldLogin.parent.create(recursive: true);
      await oldLogin.writeAsString('old login');

      await collectPatrolScreenshots(device.run, output, '42');

      expect(
        output
            .listSync(recursive: true)
            .whereType<File>()
            .map(
              (file) => file.path
                  .substring(output.path.length + 1)
                  .replaceAll('\\', '/'),
            )
            .toSet(),
        {
          '01_sign_in_required.png',
          'screenshots/01_sign_in_required.png',
          'screenshots/04_tasks_consent.png',
          'screenshots/99_failure.png',
          '99_failure_FAILED.png',
        },
      );
      expect(
        await File(
          '${output.path}/screenshots/01_sign_in_required.png',
        ).readAsString(),
        endsWith('1000_42_01_sign_in_required.png'),
      );
      expect(await oldLogin.readAsString(), 'old login');
      expect(device.pulled, [
        '$_remoteRoot/nested/1000_42_01_sign_in_required.png',
        '$_remoteRoot/nested/1100_42_04_tasks_consent.png',
        '$_remoteRoot/nested/1200_42_99_failure.png',
      ]);
    },
  );

  test(
    'collect screenshots should require all lifecycle checkpoints when instrumentation passes',
    () async {
      await File(
        '${output.path}/instrumentation.txt',
      ).writeAsString('OK (1 test)');
      final device = _ScreenshotDevice([
        '$_remoteRoot/1000_42_01_sign_in_required.png',
        '$_remoteRoot/1000_42_04_tasks_consent.png',
      ]);

      await expectLater(
        collectPatrolScreenshots(device.run, output, '42'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('06_home'),
          ),
        ),
      );
    },
  );

  test(
    'collect screenshots should reject silent sign in when the consent prompt was not captured',
    () async {
      await File(
        '${output.path}/instrumentation.txt',
      ).writeAsString('OK (1 test)');
      final device = _ScreenshotDevice([
        '$_remoteRoot/1000_42_01_sign_in_required.png',
        '$_remoteRoot/1000_42_06_home.png',
      ]);
      await expectLater(
        collectPatrolScreenshots(device.run, output, '42'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('04_tasks_consent'),
          ),
        ),
      );
    },
  );

  test(
    'collect screenshots should accept all lifecycle checkpoints when the full flow passes',
    () async {
      await File(
        '${output.path}/instrumentation.txt',
      ).writeAsString('OK (1 test)');
      final device = _ScreenshotDevice([
        for (final point in [
          '06_home',
          '01_sign_in_required',
          '04_tasks_consent',
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
        ])
          '$_remoteRoot/1000_42_$point.png',
      ]);

      await collectPatrolScreenshots(device.run, output, '42');

      expect(device.pulled, hasLength(13));
      expect(
        await File('${output.path}/screenshots/06_home.png').exists(),
        isTrue,
      );
      expect(
        await File(
          '${output.path}/screenshots/16_sign_in_canceled.png',
        ).exists(),
        isTrue,
      );
    },
  );

  test(
    'collect screenshots should preserve other baselines when diagnostics and screenshots use separate directories',
    () async {
      final screenshots = Directory('${output.path}/screenshots/e2e');
      final baseline = File(
        '${output.path}/screenshots/login_screen/login_screen_when_displayed.png',
      );
      final capture = File('${screenshots.path}/01_sign_in_required.png');
      await baseline.parent.create(recursive: true);
      await capture.parent.create(recursive: true);
      await baseline.writeAsString('native baseline');
      await capture.writeAsString('stale patrol capture');
      await File('${output.path}/device.log').writeAsString('stale log');

      preparePatrolArtifacts(output, screenshots: screenshots);

      expect(await baseline.readAsString(), 'native baseline');
      expect(await capture.readAsString(), 'stale patrol capture');
      expect(await File('${output.path}/device.log').exists(), isFalse);
      final device = _ScreenshotDevice([
        '$_remoteRoot/1000_42_01_sign_in_required.png',
      ]);
      await collectPatrolScreenshots(
        device.run,
        output,
        '42',
        screenshots: screenshots,
      );

      expect(await baseline.readAsString(), 'native baseline');
      expect(
        await File(
          '${output.path}/screenshots/01_sign_in_required.png',
        ).readAsString(),
        endsWith('1000_42_01_sign_in_required.png'),
      );
      expect(await capture.readAsString(), 'stale patrol capture');
      expect(
        await File('${output.path}/01_sign_in_required.png').exists(),
        isFalse,
      );
    },
  );

  test(
    'collect screenshots should reject stale runs when no current screenshots exist',
    () async {
      final device = _ScreenshotDevice([
        '$_remoteRoot/1000_442_01_sign_in_required.png',
      ]);

      await expectLater(
        collectPatrolScreenshots(device.run, output, '42'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('No screenshots'),
          ),
        ),
      );
      expect(device.pulled, isEmpty);
    },
  );

  test(
    'collect screenshots should reject an empty file when artifact transfer fails',
    () async {
      final device = _ScreenshotDevice([
        '$_remoteRoot/1000_42_01_sign_in_required.png',
      ])..empty = true;

      await expectLater(
        collectPatrolScreenshots(device.run, output, '42'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Empty screenshot'),
          ),
        ),
      );
    },
  );
}
