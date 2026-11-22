import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart' as google;
import 'package:patrol/patrol.dart';
import 'package:remindme/models/task_metadata.dart';
import 'package:remindme/screens/task_home_screen.dart';
import 'package:remindme/screens/task_edit_screen.dart';
import 'package:remindme/services/auth_repository.dart';
import 'package:remindme/services/tasks_repository.dart';

const patrolAccount = String.fromEnvironment('PATROL_TEST_ACCOUNT');
const patrolRunId = String.fromEnvironment('PATROL_RUN_ID');
const _allowUnverifiedApp = bool.fromEnvironment('PATROL_ALLOW_UNVERIFIED_APP');
const googleTimeout = Duration(seconds: 60);
const remoteTimeout = Duration(seconds: 30);
const freshConsentRequired =
    'Fresh Google Tasks consent prompt was not shown. Manually revoke Remind Me '
    'access from the test Google account before running this test again. '
    'Clearing local app data does not reset Google consent.';

final _lifecycles = Expando<TaskLifecycle>();
final capturedScreenshots = <String, Map<String, Object>>{};

TaskLifecycle lifecycleFor(PatrolIntegrationTester tester) =>
    _lifecycles[tester]!;

void patrolScenario(
  String description,
  Future<void> Function(PatrolIntegrationTester) body,
) {
  patrolTest(description, ($) async {
    expect(
      patrolAccount,
      isNotEmpty,
      reason: 'Use tool/run_patrol.dart --account.',
    );
    expect(
      patrolRunId,
      isNotEmpty,
      reason: 'Use the clean-state Dart launcher.',
    );
    capturedScreenshots.clear();
    final lifecycle = TaskLifecycle($);
    _lifecycles[$] = lifecycle;
    try {
      await body($);
    } catch (_) {
      await lifecycle.captureFailure();
      rethrow;
    } finally {
      await lifecycle.cleanUp();
      _lifecycles[$] = null;
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

class TaskLifecycle {
  TaskLifecycle(this.$);

  final PatrolIntegrationTester $;
  final auth = AuthRepository();
  final title = 'RemindMe Patrol $patrolRunId';
  final notes = 'Created by Patrol $patrolRunId';
  final editedNotes = 'Edited by Patrol $patrolRunId';
  String get editedTitle => '$title edited';
  late TasksRepository repo;
  google.TasksApi? api;
  String? listId;
  String? taskId;
  var deleted = false;
  var createAttempted = false;
  StreamIterator<String>? googleScreens;
  String? googleCheckpoint;

  Future<void> advanceGoogleSignIn() async {
    final screens = googleScreens!;
    googleCheckpoint = await screens.moveNext() ? screens.current : null;
  }

  Future<void> captureFailure() async {
    // Capture before cleanup changes the failing screen.
    try {
      await captureScreenshot($, '99_failure', settle: false);
    } catch (error) {
      $.log('Failure screenshot could not be captured: $error');
    }
    try {
      final roots = (await $.platform.android.getNativeViews(null)).roots;
      $.log(
        'Native screen at failure: ${jsonEncode(flattenNativeViews(roots).where((view) => nativeLabel(view).isNotEmpty).map((view) => {'package': view.applicationPackage, 'label': nativeLabel(view), 'resource': view.resourceName, 'enabled': view.isEnabled, 'checked': view.isChecked}).toList())}',
      );
    } catch (error) {
      $.log('Native screen diagnostics unavailable: $error');
    }
  }

  Future<void> cleanUp() async {
    await googleScreens?.cancel();
    final api = this.api;
    final listId = this.listId;
    if (createAttempted && !deleted && api != null && listId != null) {
      try {
        // Also find a create that succeeded remotely before its assertion.
        final owned = (await remoteTasks(api, listId)).where(
          (task) =>
              (taskId != null && task.id == taskId) ||
              ((task.title == title || task.title == editedTitle) &&
                  [
                    notes,
                    editedNotes,
                  ].contains(TaskMetadata.parse(task.notes).notes)),
        );
        for (final task in owned) {
          await api.tasks.delete(listId, task.id!).timeout(remoteTimeout);
        }
      } catch (error) {
        $.log('Cleanup failed; remove only task for run $patrolRunId: $error');
      }
    }
    if (auth.signedIn) {
      try {
        await auth.signOut().timeout(remoteTimeout);
      } catch (error) {
        $.log('Sign-out cleanup failed: $error');
      }
    }
  }
}

Future<void> expectEditor(
  PatrolIntegrationTester $, {
  required String title,
  required String notes,
}) async {
  await waitFor(
    $,
    () => find.byType(TaskEditScreen).evaluate().isNotEmpty,
    'Task editor',
  );
  final titleInput = $.tester.widget<TextFormField>(
    find.byKey(const ValueKey('task_title')),
  );
  final notesInput = $.tester.widget<TextField>(
    find.byKey(const ValueKey('task_notes')),
  );
  expect(titleInput.controller!.text, title);
  expect(notesInput.controller!.text, notes);
}

Future<void> captureScreenshot(
  PatrolIntegrationTester $,
  String checkpoint, {
  bool settle = true,
}) async {
  if (settle) {
    await $.tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
  }
  await $.platform.android.takeNativeScreenshot('${patrolRunId}_$checkpoint');
  if (checkpoint != '99_failure') {
    final padding = $.tester.view.viewPadding;
    capturedScreenshots[checkpoint] = {
      'checkpoint': checkpoint,
      'left': padding.left.round(),
      'top': padding.top.round(),
      'right': padding.right.round(),
      'bottom': padding.bottom.round(),
    };
  }
}

Future<void> waitFor(
  PatrolIntegrationTester $,
  bool Function() condition,
  String description, {
  Duration timeout = remoteTimeout,
}) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsed >= timeout) fail('Timed out: $description');
    await $.tester.pump(const Duration(milliseconds: 100));
  }
  await $.tester.pump();
}

Future<T> pollRemote<T>(
  PatrolIntegrationTester $,
  Future<T?> Function() read,
  String description,
) async {
  final result = await $.tester.runAsync(() async {
    final clock = Stopwatch()..start();
    while (clock.elapsed < remoteTimeout) {
      // API errors are failures, rather than a reason to accept cached state.
      final value = await read().timeout(remoteTimeout - clock.elapsed);
      if (value != null) return value;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException(description, remoteTimeout);
  });
  if (result == null) fail(description);
  return result;
}

Future<List<google.Task>> remoteTasks(
  google.TasksApi api,
  String listId,
) async {
  final tasks = <google.Task>[];
  String? page;
  do {
    final response = await api.tasks
        .list(
          listId,
          maxResults: 100,
          pageToken: page,
          showCompleted: true,
          showHidden: true,
          showDeleted: false,
        )
        .timeout(remoteTimeout);
    tasks.addAll(response.items ?? <google.Task>[]);
    page = response.nextPageToken;
  } while (page != null);
  return tasks;
}

Iterable<AndroidNativeView> flattenNativeViews(
  Iterable<AndroidNativeView> roots,
) sync* {
  for (final view in roots) {
    yield view;
    yield* flattenNativeViews(view.children);
  }
}

String nativeLabel(AndroidNativeView view) =>
    ((view.text?.isNotEmpty ?? false)
            ? view.text!
            : view.contentDescription ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

Future<void> tapNativeView(PatrolIntegrationTester $, AndroidNativeView view) =>
    $.platform.android.tap(
      AndroidSelector(
        applicationPackage: view.applicationPackage,
        text: (view.text?.isNotEmpty ?? false) ? view.text : null,
        contentDescription: (view.text?.isNotEmpty ?? false)
            ? null
            : view.contentDescription,
      ),
    );

Stream<String> completeSignIn(
  PatrolIntegrationTester $,
  AuthRepository auth,
) async* {
  final android = $.platform.android;
  final clock = Stopwatch()..start();
  final screenClock = Stopwatch()..start();
  var selectedAccount = false;
  var sawTasks = false;
  var confirmedTasks = false;
  var warningCaptured = false;
  var openedAdvanced = false;
  var followedDevelopmentLink = false;
  var warningScrolls = 0;
  var consentScrolls = 0;
  while (clock.elapsed < const Duration(minutes: 3) &&
      screenClock.elapsed < googleTimeout) {
    if (find.byType(TaskHomeScreen).evaluate().isNotEmpty) {
      expect(sawTasks, isTrue, reason: freshConsentRequired);
      expect(auth.hasLinkedAccount, isTrue);
      return;
    }
    if (!auth.signingIn && auth.authError != null) {
      fail(
        'Google sign-in failed before Tasks consent: ${auth.authError} '
        'Inspect the emulator Google Play services version and OAuth configuration.',
      );
    }
    final views = flattenNativeViews(
      (await android.getNativeViews(null)).roots,
    ).toList();
    final googleViews = views.where(
      (view) =>
          view.applicationPackage == 'com.google.android.gms' ||
          view.applicationPackage == 'com.google.android.gsf.login' ||
          view.applicationPackage == 'android' ||
          view.applicationPackage == 'com.android.settings',
    );
    final unverifiedWarning = googleViews.any(
      (view) => RegExp(
        r'google hasn.t verified this app',
        caseSensitive: false,
      ).hasMatch('${view.text ?? ''} ${view.contentDescription ?? ''}'),
    );
    if (unverifiedWarning && !_allowUnverifiedApp) {
      fail(
        'This development OAuth app is unverified. Use '
        '--allow-unverified-app only for your own Remind Me test project.',
      );
    }
    if (unverifiedWarning && !warningCaptured) {
      // WebView accessibility text can arrive before its first painted frame.
      await Future<void>.delayed(const Duration(seconds: 3));
      yield '02_development_warning';
      warningCaptured = true;
    }
    if (_allowUnverifiedApp && warningCaptured && !followedDevelopmentLink) {
      final developmentLinks = googleViews.where(
        (view) => RegExp(
          r'^Go to Remind Me \(unsafe\)$',
          caseSensitive: false,
        ).hasMatch(nativeLabel(view)),
      );
      if (developmentLinks.isNotEmpty) {
        yield '03_development_confirmation';
        await tapNativeView($, developmentLinks.first);
        followedDevelopmentLink = true;
        screenClock.reset();
        continue;
      }
      final advanced = googleViews.where(
        (view) => nativeLabel(view).toLowerCase() == 'advanced',
      );
      if (!openedAdvanced && advanced.isNotEmpty) {
        await tapNativeView($, advanced.first);
        openedAdvanced = true;
        screenClock.reset();
        continue;
      }
      if (openedAdvanced && warningScrolls < 4) {
        await android.swipe(
          from: const Offset(0.5, 0.75),
          to: const Offset(0.5, 0.4),
        );
        warningScrolls++;
        continue;
      }
    }
    if (!selectedAccount) {
      final accounts = googleViews.where(
        (view) =>
            view.text?.toLowerCase() == patrolAccount.toLowerCase() ||
            view.contentDescription?.toLowerCase() ==
                patrolAccount.toLowerCase(),
      );
      if (accounts.isNotEmpty) {
        final account = accounts.first;
        await tapNativeView($, account);
        selectedAccount = true;
        screenClock.reset();
        continue;
      }
    }
    final accountConfirmation = googleViews.where(
      (view) =>
          selectedAccount &&
          view.applicationPackage == 'android' &&
          view.isEnabled &&
          nativeLabel(view).toLowerCase() == 'ok',
    );
    if (accountConfirmation.isNotEmpty) {
      yield '02_account_selected';
      await tapNativeView($, accountConfirmation.first);
      screenClock.reset();
      continue;
    }
    // Identify the actual Tasks scope description, not a generic login button.
    final tasksPermission = googleViews.any(
      (view) => RegExp(
        r'(google tasks|(?:create|edit|manage|delete|view|see).*tasks)',
        caseSensitive: false,
      ).hasMatch('${view.text ?? ''} ${view.contentDescription ?? ''}'),
    );
    if (tasksPermission && !sawTasks) {
      yield '04_tasks_consent';
      sawTasks = true;
    }
    if (sawTasks && tasksPermission) {
      final unchecked = googleViews.where(
        (view) => view.isCheckable && !view.isChecked && view.isEnabled,
      );
      if (unchecked.isNotEmpty) {
        // This app requests only the single Google Tasks scope.
        await android.tap(
          AndroidSelector(
            applicationPackage: unchecked.first.applicationPackage,
            isCheckable: true,
            isChecked: false,
            instance: 0,
          ),
        );
        screenClock.reset();
        continue;
      }
    }
    final buttons = googleViews.where(
      (view) =>
          view.isEnabled &&
          const [
            'continue',
            'allow',
            'next',
            'agree and share',
          ].contains(nativeLabel(view).toLowerCase()),
    );
    if (buttons.isNotEmpty) {
      final button = buttons.first;
      if (sawTasks && !confirmedTasks) {
        yield '05_tasks_confirmation';
        confirmedTasks = true;
      }
      await tapNativeView($, button);
      screenClock.reset();
      continue;
    }
    final consentPage = googleViews.any(
      (view) => nativeLabel(
        view,
      ).toLowerCase().contains('wants access to your google account'),
    );
    if ((sawTasks || consentPage) &&
        consentScrolls < 8 &&
        (tasksPermission ||
            consentPage ||
            googleViews.any(
              (view) => nativeLabel(view).toLowerCase() == 'scroll down',
            ))) {
      // Google's bottom arrow can be an indicator rather than a scroll action.
      // Swipe the WebView itself until the final Continue button is visible.
      await android.swipe(
        from: const Offset(0.5, 0.85),
        to: const Offset(0.5, 0.25),
        steps: 40,
      );
      consentScrolls++;
      screenClock.reset();
      continue;
    }
    // Google may pause the Flutter Activity. Waiting for a Flutter frame here
    // can hang until the authorization Activity closes; poll in real time.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (find.byType(TaskHomeScreen).evaluate().isNotEmpty) {
      expect(sawTasks, isTrue, reason: freshConsentRequired);
      expect(auth.hasLinkedAccount, isTrue);
      return;
    }
  }
  fail(
    sawTasks
        ? 'Google authorization did not finish within 60 seconds.'
        : freshConsentRequired,
  );
}
