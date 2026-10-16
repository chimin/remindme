import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import 'package:remindme/main.dart';
import 'package:remindme/services/tasks_repository.dart';

class MockTasksRepository extends TasksRepository {
  bool _signedIn = false;
  String? _selectedTasklistId;
  final List<Task> _mockTasks = <Task>[];

  @override
  bool get signedIn => _signedIn;

  @override
  String? get selectedTasklistId => _selectedTasklistId;

  @override
  Future<void> init() async {
    initialized = true;
    _signedIn = false;
    notifyListeners();
  }

  @override
  Future<void> signIn() async {
    _signedIn = true;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    notifyListeners();
  }

  @override
  Future<List<TaskList>> getTaskLists() async => <TaskList>[];

  @override
  Future<List<Task>> getTasks(String tasklistId) async => _mockTasks;

  @override
  Future<String> resolveDefaultTasklistId() async => 'list-1';

  @override
  Future<void> selectTasklist(String id) async {
    _selectedTasklistId = id;
    notifyListeners();
  }

  void populateTasks(List<Task> tasks) {
    _mockTasks
      ..clear()
      ..addAll(tasks);
    notifyListeners();
  }

  void signInMock({String? tasklistId}) {
    _signedIn = true;
    if (tasklistId != null) _selectedTasklistId = tasklistId;
    notifyListeners();
  }
}

const double kGoldenDiffThreshold = 5.0;

const String _kLoginGoldenPath = 'test/screens/golden/login_screen.png';
const String _kHomeGoldenPath = 'test/screens/golden/home_screen.png';
const String _kReportPath = 'test/reports/golden_comparison_report.md';

Future<ui.Image> _decodePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

double _computeDiffPct(ByteData a, ByteData b) {
  if (a.lengthInBytes != b.lengthInBytes) {
    return 100.0;
  }
  final length = a.lengthInBytes;
  int differing = 0;
  for (var i = 0; i < length; i += 4) {
    if ((a.getUint8(i) - b.getUint8(i)).abs() > 5 ||
        (a.getUint8(i + 1) - b.getUint8(i + 1)).abs() > 5 ||
        (a.getUint8(i + 2) - b.getUint8(i + 2)).abs() > 5 ||
        (a.getUint8(i + 3) - b.getUint8(i + 3)).abs() > 5) {
      differing += 1;
    }
  }
  return differing / (length / 4) * 100;
}

Future<Map<String, dynamic>> _captureAndCompare(
  WidgetTester tester,
  Finder finder,
  String goldenPath,
  String name,
) async {
  return (await tester.binding.runAsync(() async {
    final image = await captureImage(finder.evaluate().single);
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (raw == null || pngBytes == null) {
      throw StateError('failed to encode screenshot for $name');
    }
    final goldenFile = File(goldenPath);
    final result = <String, dynamic>{
      'name': name,
      'goldenMissing': false,
    };
    if (!await goldenFile.exists()) {
      debugPrint('Golden missing; created $goldenPath');
      await goldenFile.parent.create(recursive: true);
      await goldenFile.writeAsBytes(pngBytes.buffer.asUint8List());
      result['diffPct'] = 0.0;
      result['pass'] = true;
      result['goldenMissing'] = true;
      image.dispose();
      return result;
    }
    image.dispose();
    final goldenImage = await _decodePng(await goldenFile.readAsBytes());
    try {
      final goldenRaw =
          await goldenImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (goldenRaw == null) {
        throw StateError('failed to decode golden $goldenPath');
      }
      final diffPct = _computeDiffPct(raw, goldenRaw);
      result['diffPct'] = diffPct;
      result['pass'] = diffPct <= kGoldenDiffThreshold;
    } finally {
      goldenImage.dispose();
    }
    return result;
  }))!;
}

Future<void> _writeReport({
  required double threshold,
  required Map<String, dynamic> screenshots,
}) async {
  final entries = screenshots.entries.toList()
    ..sort((a, b) {
      final sa = a.value as Map<String, dynamic>;
      final sb = b.value as Map<String, dynamic>;
      final ga = sa['goldenMissing'] as bool;
      final gb = sb['goldenMissing'] as bool;
      if (ga != gb) {
        return ga ? -1 : 1;
      }
      final da = ga ? double.infinity : (sa['diffPct'] as num).toDouble();
      final db = gb ? double.infinity : (sb['diffPct'] as num).toDouble();
      if (db != da) {
        return db.compareTo(da);
      }
      return a.key.compareTo(b.key);
    });

  final lines = <String>[];
  lines.add('# Golden Screenshot Comparison Report');
  lines.add('');
  lines.add('- Threshold: $threshold%');
  lines.add('- Overall pass: ${screenshots.values.every((element) => element['pass'] as bool)}');
  lines.add('- Timestamp: ${DateTime.now().toUtc().toIso8601String()}');
  lines.add('');
  lines.add('## Screenshots');
  lines.add('');
  lines.add('| Name | Diff % | Pass |');
  lines.add('|------|--------|------|');
  for (final entry in entries) {
    final s = entry.value as Map<String, dynamic>;
    final name = s['name'] as String;
    final missing = s['goldenMissing'] as bool;
    final diff = missing ? 'Missing' : '${(s['diffPct'] as num).toStringAsFixed(2)}%';
    lines.add('| $name | $diff | ${s['pass']} |');
  }
  lines.add('');
  final failing = screenshots.values.where((element) => !(element['pass'] as bool)).length;
  lines.add('## Result');
  lines.add('');
  lines.add(failing == 0
      ? 'All screenshots are within the $threshold% difference threshold.'
      : '$failing screenshot(s) exceed the $threshold% difference threshold.');
  lines.add('');

  final reportFile = File(_kReportPath);
  await reportFile.parent.create(recursive: true);
  await reportFile.writeAsString(lines.join('\n'));
}

void main() {
  setUpAll(() async {
    final robotoBytes = await File('test/fonts/roboto-regular.ttf').readAsBytes();
    final robotoLoader = FontLoader('Roboto')
      ..addFont(Future<ByteData>.value(ByteData.view(robotoBytes.buffer)));
    await robotoLoader.load();

    final materialIconsBytes = await File(
      'test/fonts/materialicons-regular.otf',
    ).readAsBytes();
    final materialIconsLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future<ByteData>.value(ByteData.view(materialIconsBytes.buffer)),
      );
    await materialIconsLoader.load();
  });

  testWidgets(
    'sign in should show home screen with tasks when user clicks continue with google',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final mock = MockTasksRepository();
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
                fontFamily: 'Roboto',
              ),
              home: const AuthRouter(),
            ),
          ),
        ),
      );
      // Typical phone viewport in portrait (360×640 logical @ 2x device pixel
      // ratio) so fonts and layout render at phone-appropriate sizes.
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
      await mock.init();
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);

      final loginResult = await _captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        _kLoginGoldenPath,
        'login_screen',
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      final tasks = <Task>[
        Task(id: '1', title: 'Buy groceries', status: 'needsAction', due: '2026-01-15'),
        Task(id: '2', title: 'Call mom', status: 'completed', due: '2026-01-14'),
        Task(id: '3', title: 'Finish report', status: 'needsAction', due: '2026-01-20'),
      ];
      mock.populateTasks(tasks);
      mock.signInMock(tasklistId: 'list-1');

      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.text('Call mom'), findsOneWidget);
      expect(find.text('Finish report'), findsOneWidget);

      final homeResult = await _captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        _kHomeGoldenPath,
        'home_screen',
      );

      await tester.binding.runAsync(() async {
        await _writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{
            'login_screen': loginResult,
            'home_screen': homeResult,
          },
        );
      });

      expect(
        loginResult['pass'] as bool,
        isTrue,
        reason: 'login screen golden diff exceeded threshold',
      );
      expect(
        homeResult['pass'] as bool,
        isTrue,
        reason: 'home screen golden diff exceeded threshold',
      );
    },
  );
}
