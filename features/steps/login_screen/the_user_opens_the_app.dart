import '../scenario_runner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:remindme/main.dart';
import 'package:remindme/services/tasks_repository.dart';

// Keep fresh-install storage and authentication isolated from the host machine.
class _FreshInstallRepository extends TasksRepository {
  @override
  Future<void> init() async {
    initialized = true;
    notifyListeners();
  }

  @override
  Future<void> signIn() async {}
}

Future<void> theUserOpensTheApp(ScenarioState state) async {
  final tester = state.tester!;
  final repo = _FreshInstallRepository();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<TasksRepository>.value(
      value: repo,
      child: const MyApp(),
    ),
  );
  await repo.init();
  await tester.pumpAndSettle();
}
