import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart' as google;
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:remindme/main.dart' as app;
import 'package:remindme/models/task_metadata.dart';
import 'package:remindme/screens/login_screen.dart';
import 'package:remindme/screens/task_home_screen.dart';
import 'package:remindme/screens/task_edit_screen.dart';
import 'package:remindme/services/auth_repository.dart';
import 'package:remindme/services/tasks_repository.dart';

const _account = String.fromEnvironment('PATROL_TEST_ACCOUNT');
const _runId = String.fromEnvironment('PATROL_RUN_ID');
const _allowUnverifiedApp = bool.fromEnvironment('PATROL_ALLOW_UNVERIFIED_APP');
const _stopAfterHome = bool.fromEnvironment('PATROL_STOP_AFTER_HOME');
const _googleTimeout = Duration(seconds: 60);
const _remoteTimeout = Duration(seconds: 30);

void main() {
  patrolTest(
    _stopAfterHome
        ? 'sign in should reach the home screen when Google Tasks permission is granted'
        : 'task lifecycle should create edit and delete a task when Google Tasks permission is granted',
    ($) async {
      expect(
        _account,
        isNotEmpty,
        reason: 'Use tool/run_patrol.dart --account.',
      );
      expect(_runId, isNotEmpty, reason: 'Use the clean-state Dart launcher.');
      final auth = AuthRepository();
      final title = 'RemindMe Patrol $_runId';
      final editedTitle = '$title edited';
      final notes = 'Created by Patrol $_runId';
      final editedNotes = 'Edited by Patrol $_runId';
      google.TasksApi? api;
      String? listId;
      String? taskId;
      var deleted = false;
      var createAttempted = false;

      try {
        await app.startApp(authRepository: auth);
        await _waitFor(
          $,
          () => find.byType(LoginScreen).evaluate().isNotEmpty,
          'Clean startup must show the login screen',
        );
        expect(auth.signedIn, isFalse);
        await _capture($, '01_login');

        // Do not settle an animation while Google owns the foreground.
        await $.tester.tap(find.text('Continue with Google'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _grantFreshTasksConsent($, auth);
        await _waitFor(
          $,
          () => find.byType(TaskHomeScreen).evaluate().isNotEmpty,
          'Home screen after Google authorization',
        );
        expect(auth.userEmail?.toLowerCase(), _account.toLowerCase());
        expect(auth.signedIn, isTrue);
        final repo = Provider.of<TasksRepository>(
          $.tester.element(find.byType(TaskHomeScreen)),
          listen: false,
        );
        await _waitFor(
          $,
          () =>
              repo.selectedTasklistId != null &&
              find.byType(CircularProgressIndicator).evaluate().isEmpty,
          'Initial task list loading',
        );
        listId = repo.selectedTasklistId!;
        api = google.TasksApi(auth.client!);
        await _capture($, '03_home');

        if (_stopAfterHome) {
          $.log('Sign-in verification reached the loaded home screen.');
          return;
        }

        await $(find.byTooltip('Add task')).tap();
        await $(#task_title).enterText(title);
        await $(#task_notes).enterText(notes);
        await _expectEditor($, title: title, notes: notes);
        await _capture($, '04a_new_task_form');
        createAttempted = true;
        await $(find.text('Create task')).scrollTo().tap();
        await _waitFor(
          $,
          () => find.byType(TaskHomeScreen).evaluate().isNotEmpty,
          'Return home after creating task',
        );
        await $(find.text(title)).scrollTo();
        expect(find.text(title), findsOneWidget);
        final created = await _pollRemote($, () async {
          final tasks = await _remoteTasks(api!, listId!);
          final matches = tasks.where((task) => task.title == title).toList();
          if (matches.length != 1 ||
              TaskMetadata.parse(matches.single.notes).notes != notes) {
            return null;
          }
          return matches.single;
        }, 'Created task must exist in Google Tasks');
        taskId = created.id!;
        await _capture($, '04_created');

        await $(find.text(title)).scrollTo().tap();
        await _expectEditor($, title: title, notes: notes);
        await $(#task_title).enterText(editedTitle);
        await $(#task_notes).enterText(editedNotes);
        await _expectEditor($, title: editedTitle, notes: editedNotes);
        await _capture($, '05a_edited_task_form');
        await $(find.text('Save changes')).scrollTo().tap();
        await _waitFor(
          $,
          () => find.byType(TaskHomeScreen).evaluate().isNotEmpty,
          'Return home after editing task',
        );
        await $(find.text(editedTitle)).scrollTo();
        expect(find.text(editedTitle), findsOneWidget);
        await _pollRemote($, () async {
          final task = await api!.tasks.get(listId!, taskId!);
          return task.title == editedTitle &&
                  TaskMetadata.parse(task.notes).notes == editedNotes
              ? task
              : null;
        }, 'Edited title and notes on the same remote task');
        expect(find.text(title), findsNothing);
        await _capture($, '05_edited');

        await $(find.text(editedTitle)).scrollTo().tap();
        await _expectEditor($, title: editedTitle, notes: editedNotes);
        await _capture($, '06a_before_delete');
        await $(find.byTooltip('Delete task')).tap();
        await _waitFor(
          $,
          () =>
              find.byType(TaskHomeScreen).evaluate().isNotEmpty &&
              find.text(editedTitle).evaluate().isEmpty,
          'Deleted task absent from home screen',
        );
        await _pollRemote($, () async {
          final tasks = await _remoteTasks(api!, listId!);
          return tasks.any((task) => task.id == taskId) ? null : true;
        }, 'Deleted task absent from Google Tasks');
        deleted = true;
        expect(find.text(title), findsNothing);
        await _capture($, '06_deleted');

        await $(find.byTooltip('Menu')).tap();
        await $(find.text('Sign out')).tap();
        await _capture($, '07_sign_out_confirmation');
        await $(find.widgetWithText(TextButton, 'Sign out')).tap();
        await _waitFor(
          $,
          () =>
              find.byType(LoginScreen).evaluate().isNotEmpty &&
              !auth.signedIn &&
              !repo.signingIn,
          'Signed out login screen',
        );
        expect(repo.selectedTasklistId, isNull);
        expect(find.text('Continue with Google'), findsOneWidget);
        await _capture($, '08_signed_out');
      } catch (_) {
        // Capture before cleanup changes the failing screen.
        try {
          await _capture($, '99_failure', settle: false);
        } catch (error) {
          $.log('Failure screenshot could not be captured: $error');
        }
        try {
          final roots = (await $.platform.android.getNativeViews(null)).roots;
          $.log(
            'Native screen at failure: ${jsonEncode(_flatten(roots).where((view) => _nativeLabel(view).isNotEmpty).map((view) => {'package': view.applicationPackage, 'label': _nativeLabel(view), 'resource': view.resourceName, 'enabled': view.isEnabled, 'checked': view.isChecked}).toList())}',
          );
        } catch (error) {
          $.log('Native screen diagnostics unavailable: $error');
        }
        rethrow;
      } finally {
        if (createAttempted && !deleted && api != null && listId != null) {
          try {
            // Also find a create that succeeded remotely before its assertion.
            final owned = (await _remoteTasks(api, listId)).where(
              (task) =>
                  (taskId != null && task.id == taskId) ||
                  ((task.title == title || task.title == editedTitle) &&
                      [
                        notes,
                        editedNotes,
                      ].contains(TaskMetadata.parse(task.notes).notes)),
            );
            for (final task in owned) {
              await api.tasks.delete(listId, task.id!).timeout(_remoteTimeout);
            }
          } catch (error) {
            $.log('Cleanup failed; remove only task for run $_runId: $error');
          }
        }
        if (auth.signedIn) {
          try {
            await auth.signOut().timeout(_remoteTimeout);
          } catch (error) {
            $.log('Sign-out cleanup failed: $error');
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _expectEditor(
  PatrolIntegrationTester $, {
  required String title,
  required String notes,
}) async {
  await _waitFor(
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

Future<void> _capture(
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
  await $.platform.android.takeNativeScreenshot('${_runId}_$checkpoint');
}

Future<void> _waitFor(
  PatrolIntegrationTester $,
  bool Function() condition,
  String description, {
  Duration timeout = _remoteTimeout,
}) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsed >= timeout) fail('Timed out: $description');
    await $.tester.pump(const Duration(milliseconds: 100));
  }
  await $.tester.pump();
}

Future<T> _pollRemote<T>(
  PatrolIntegrationTester $,
  Future<T?> Function() read,
  String description,
) async {
  final result = await $.tester.runAsync(() async {
    final clock = Stopwatch()..start();
    while (clock.elapsed < _remoteTimeout) {
      // API errors are failures, rather than a reason to accept cached state.
      final value = await read().timeout(_remoteTimeout - clock.elapsed);
      if (value != null) return value;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException(description, _remoteTimeout);
  });
  if (result == null) fail(description);
  return result;
}

Future<List<google.Task>> _remoteTasks(
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
        .timeout(_remoteTimeout);
    tasks.addAll(response.items ?? <google.Task>[]);
    page = response.nextPageToken;
  } while (page != null);
  return tasks;
}

Iterable<AndroidNativeView> _flatten(Iterable<AndroidNativeView> roots) sync* {
  for (final view in roots) {
    yield view;
    yield* _flatten(view.children);
  }
}

String _nativeLabel(AndroidNativeView view) =>
    ((view.text?.isNotEmpty ?? false)
            ? view.text!
            : view.contentDescription ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

Future<void> _tapGoogleView(
  PatrolIntegrationTester $,
  AndroidNativeView view,
) => $.platform.android.tap(
  AndroidSelector(
    applicationPackage: view.applicationPackage,
    text: (view.text?.isNotEmpty ?? false) ? view.text : null,
    contentDescription: (view.text?.isNotEmpty ?? false)
        ? null
        : view.contentDescription,
  ),
);

Future<void> _grantFreshTasksConsent(
  PatrolIntegrationTester $,
  AuthRepository auth,
) async {
  final android = $.platform.android;
  final clock = Stopwatch()..start();
  final screenClock = Stopwatch()..start();
  var selectedAccount = false;
  var sawTasks = false;
  var warningCaptured = false;
  var openedAdvanced = false;
  var followedDevelopmentLink = false;
  var warningScrolls = 0;
  var consentScrolls = 0;
  while (clock.elapsed < const Duration(minutes: 3) &&
      screenClock.elapsed < _googleTimeout) {
    if (find.byType(TaskHomeScreen).evaluate().isNotEmpty) {
      expect(sawTasks, isTrue, reason: 'Fresh Tasks consent must be shown.');
      return;
    }
    if (!auth.signingIn && auth.authError != null) {
      fail(
        'Google sign-in failed before Tasks consent: ${auth.authError} '
        'Inspect the emulator Google Play services version and OAuth configuration.',
      );
    }
    final views = _flatten((await android.getNativeViews(null)).roots).toList();
    final googleViews = views.where(
      (view) =>
          view.applicationPackage == 'com.google.android.gms' ||
          view.applicationPackage == 'com.google.android.gsf.login',
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
      await _capture($, '02a_development_warning', settle: false);
      warningCaptured = true;
    }
    if (_allowUnverifiedApp && warningCaptured && !followedDevelopmentLink) {
      final developmentLinks = googleViews.where(
        (view) => RegExp(
          r'^Go to Remind Me \(unsafe\)$',
          caseSensitive: false,
        ).hasMatch(_nativeLabel(view)),
      );
      if (developmentLinks.isNotEmpty) {
        await _capture($, '02b_development_confirmation', settle: false);
        await _tapGoogleView($, developmentLinks.first);
        followedDevelopmentLink = true;
        screenClock.reset();
        continue;
      }
      final advanced = googleViews.where(
        (view) => _nativeLabel(view).toLowerCase() == 'advanced',
      );
      if (!openedAdvanced && advanced.isNotEmpty) {
        await _tapGoogleView($, advanced.first);
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
            view.text?.toLowerCase() == _account.toLowerCase() ||
            view.contentDescription?.toLowerCase() == _account.toLowerCase(),
      );
      if (accounts.isNotEmpty) {
        final account = accounts.first;
        await _tapGoogleView($, account);
        selectedAccount = true;
        screenClock.reset();
        continue;
      }
    }
    // Identify the actual Tasks scope description, not a generic login button.
    final tasksPermission = googleViews.any(
      (view) => RegExp(
        r'(google tasks|(?:create|edit|manage|delete|view|see).*tasks)',
        caseSensitive: false,
      ).hasMatch('${view.text ?? ''} ${view.contentDescription ?? ''}'),
    );
    if (tasksPermission && !sawTasks) {
      await _capture($, '02_tasks_consent', settle: false);
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
          ].contains(_nativeLabel(view).toLowerCase()),
    );
    if (buttons.isNotEmpty) {
      final button = buttons.first;
      if (sawTasks) {
        await _capture($, '02c_tasks_confirmation', settle: false);
      }
      await _tapGoogleView($, button);
      screenClock.reset();
      continue;
    }
    if (sawTasks &&
        consentScrolls < 8 &&
        (tasksPermission ||
            googleViews.any(
              (view) => _nativeLabel(view).toLowerCase() == 'scroll down',
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
      if (!sawTasks) {
        fail(
          'Fresh Tasks permission prompt was absent. Revoke '
          'Remind Me access in the test Google account before running again.',
        );
      }
      return;
    }
  }
  fail(
    sawTasks
        ? 'Google authorization did not finish within 60 seconds.'
        : 'Fresh Tasks permission prompt was not found. Revoke account consent, '
              'use an English device, and check that the configured test account is added.',
  );
}
