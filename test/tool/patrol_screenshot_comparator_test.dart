import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/patrol_screenshot_comparator.dart';

void main() {
  late Directory screenshots;
  late File capture;
  late File baseline;
  late File log;

  String request(
    String runId, {
    List<String> points = const ['16_sign_in_canceled'],
  }) {
    String event(String marker, Map<String, Object> metadata) =>
        'I/flutter: PATROL_LOG ${jsonEncode({
          'type': 'log',
          'message': '$marker ${jsonEncode({'runId': runId, ...metadata})}',
        })}';
    return [
      for (final checkpoint in points)
        event('PATROL_SCREENSHOT_CAPTURE', {
          'checkpoint': checkpoint,
          'left': 0,
          'top': 1,
          'right': 0,
          'bottom': 1,
        }),
      event('PATROL_SCREENSHOT_SET', {'screenshotCount': points.length}),
    ].join('\n');
  }

  img.Image screen() => img.fill(
    img.Image(width: 10, height: 12, numChannels: 4),
    color: img.ColorRgba8(255, 255, 255, 255),
  );

  Future<void> writeCapture(img.Image image, {File? target}) async {
    await (target ?? capture).writeAsBytes(img.encodePng(image));
  }

  Future<Map<String, dynamic>> report() async =>
      jsonDecode(
            await File(
              '${screenshots.path}/screenshot_comparison.json',
            ).readAsString(),
          )
          as Map<String, dynamic>;

  setUp(() async {
    screenshots = await Directory.systemTemp.createTemp('patrol_comparison_');
    capture = File('${screenshots.path}/screenshots/16_sign_in_canceled.png');
    await capture.parent.create();
    baseline = File('${screenshots.path}/16_sign_in_canceled.png');
    log = File('${screenshots.path}/device.log');
    await log.writeAsString(request('42'));
    await writeCapture(screen());
  });

  tearDown(() async {
    expect(
      screenshots.absolute.path,
      startsWith(Directory.systemTemp.absolute.path),
    );
    await screenshots.delete(recursive: true);
  });

  test(
    'compare screenshot set should create every native golden for review when updates are explicit',
    () async {
      await log.writeAsString(
        request('42', points: ['16_sign_in_canceled', '06_home']),
      );
      final other = File('${screenshots.path}/screenshots/06_home.png');
      await writeCapture(screen(), target: other);
      final result = await comparePatrolScreenshot(
        screenshots,
        log,
        '42',
        updateGoldens: true,
      );
      expect(await baseline.readAsBytes(), await capture.readAsBytes());
      expect(
        await File('${screenshots.path}/06_home.png').readAsBytes(),
        await other.readAsBytes(),
      );
      expect(result, contains('Created 2 golden references'));
      expect(result, contains('No baseline comparison was asserted'));
    },
  );

  test(
    'compare screenshot set should fail without creating references when goldens are missing',
    () async {
      await expectLater(
        comparePatrolScreenshot(screenshots, log, '42'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Missing golden reference'),
          ),
        ),
      );
      expect(await baseline.exists(), isFalse);
      expect((await report())['screenshots'].single['status'], 'failed');
    },
  );

  test(
    'compare screenshot set should ignore system bars when app pixels match',
    () async {
      await comparePatrolScreenshot(
        screenshots,
        log,
        '42',
        updateGoldens: true,
      );
      final changed = screen();
      for (var x = 0; x < 10; x++) {
        changed.setPixelRgba(x, 0, 0, 0, 255, 255);
        changed.setPixelRgba(x, 11, 0, 0, 255, 255);
      }
      await writeCapture(changed);
      await comparePatrolScreenshot(screenshots, log, '42');
      expect((await report())['screenshots'].single['differencePercent'], 0);
    },
  );

  test(
    'compare screenshot set should pass when the difference equals the allowed percentage',
    () async {
      await comparePatrolScreenshot(
        screenshots,
        log,
        '42',
        updateGoldens: true,
      );
      final changed = screen();
      for (var x = 0; x < 5; x++) {
        changed.setPixelRgba(x, 5, 0, 0, 0, 255);
      }
      await writeCapture(changed);
      await comparePatrolScreenshot(screenshots, log, '42');
      final result = (await report())['screenshots'].single;
      expect(result['differentPixels'], 5);
      expect(result['comparedPixels'], 100);
      expect(result['differencePercent'], 5);
      expect(result['status'], 'passed');
      expect(
        await File('${screenshots.path}/16_sign_in_canceled_FAILED.png').exists(),
        isFalse,
      );
    },
  );

  test(
    'compare screenshot set should fail and preserve the golden when the difference exceeds the limit',
    () async {
      await comparePatrolScreenshot(
        screenshots,
        log,
        '42',
        updateGoldens: true,
      );
      final reference = await baseline.readAsBytes();
      final changed = screen();
      for (var x = 0; x < 6; x++) {
        changed.setPixelRgba(x, 5, 0, 0, 0, 255);
      }
      await writeCapture(changed);
      await expectLater(
        comparePatrolScreenshot(screenshots, log, '42'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('6.0000% exceeds 5.0%'),
          ),
        ),
      );
      expect(
        await File('${screenshots.path}/16_sign_in_canceled_FAILED.png').exists(),
        isTrue,
      );
      expect(await baseline.readAsBytes(), reference);
      expect(
        await File(
          '${screenshots.path}/16_sign_in_canceled_FAILED.png',
        ).readAsBytes(),
        await capture.readAsBytes(),
      );
      expect((await report())['library'], 'pixelmatch');
    },
  );

  test(
    'compare screenshot set should inspect every checkpoint when an earlier screenshot fails',
    () async {
      await log.writeAsString(
        request('42', points: ['06_home', '16_sign_in_canceled']),
      );
      final other = File('${screenshots.path}/screenshots/06_home.png');
      await writeCapture(screen(), target: other);
      await comparePatrolScreenshot(
        screenshots,
        log,
        '42',
        updateGoldens: true,
      );
      await writeCapture(
        img.fill(screen(), color: img.ColorRgba8(0, 0, 0, 255)),
        target: other,
      );
      await expectLater(
        comparePatrolScreenshot(screenshots, log, '42'),
        throwsA(isA<StateError>()),
      );
      final results = (await report())['screenshots'] as List;
      expect(results, hasLength(2));
      expect(results[0]['status'], 'failed');
      expect(results[1]['status'], 'passed');
    },
  );

  test(
    'compare screenshot set should compare every image when Android limits each log message to 1024 bytes',
    () async {
      final points = [
        for (var i = 1; i <= 18; i++)
          '${i.toString().padLeft(2, '0')}_checkpoint',
      ];
      final metadata = request('42', points: points);
      final lines = const LineSplitter().convert(metadata);
      expect(lines, hasLength(19));
      expect(lines.every((line) => utf8.encode(line).length <= 1024), isTrue);
      await log.writeAsString(metadata);
      for (final point in points) {
        await writeCapture(
          screen(),
          target: File('${screenshots.path}/screenshots/$point.png'),
        );
      }
      await comparePatrolScreenshot(
        screenshots,
        log,
        '42',
        updateGoldens: true,
      );
      await comparePatrolScreenshot(screenshots, log, '42');
      expect((await report())['screenshots'], hasLength(18));
    },
  );

  test(
    'compare screenshot set should fail before updating references when capture metadata is missing',
    () async {
      final lines = const LineSplitter().convert(request('42'));
      await log.writeAsString(lines.last);
      await expectLater(
        comparePatrolScreenshot(screenshots, log, '42', updateGoldens: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Incomplete screenshot metadata'),
          ),
        ),
      );
      expect(await baseline.exists(), isFalse);
    },
  );

  test(
    'compare screenshot set should reject stale manifests when the run identifier differs',
    () async {
      await log.writeAsString(request('41'));
      await expectLater(
        comparePatrolScreenshot(screenshots, log, '42', updateGoldens: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('No screenshot set requested'),
          ),
        ),
      );
      expect(await baseline.exists(), isFalse);
    },
  );

  test(
    'compare screenshot set should reject dimensions when the percentage limit would otherwise allow differences',
    () async {
      await comparePatrolScreenshot(
        screenshots,
        log,
        '42',
        updateGoldens: true,
      );
      await writeCapture(img.Image(width: 11, height: 12, numChannels: 4));
      await expectLater(
        comparePatrolScreenshot(
          screenshots,
          log,
          '42',
          allowedDifferencePercent: 100,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('dimensions differ'),
          ),
        ),
      );
    },
  );
}
