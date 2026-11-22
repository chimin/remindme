import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart' as google;
import 'package:google_account_android/google_account_android.dart';
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
const _googleTimeout = Duration(seconds: 60);
const _remoteTimeout = Duration(seconds: 30);
const _freshConsentRequired =
    'Fresh Google Tasks consent prompt was not shown. Manually revoke Remind Me '
    'access from the test Google account before running this test again. '
    'Clearing local app data does not reset Google consent.';

final _lifecycles = Expando<TaskLifecycle>();
final _capturedScreenshots = <String, Map<String, Object>>{};

TaskLifecycle lifecycleFor(PatrolIntegrationTester tester) =>
    _lifecycles[tester]!;

void patrolScenario(
  String description,
  Future<void> Function(PatrolIntegrationTester) body,
) {
  patrolTest(description, ($) async {
    expect(_account, isNotEmpty, reason: 'Use tool/run_patrol.dart --account.');
    expect(_runId, isNotEmpty, reason: 'Use the clean-state Dart launcher.');
    _capturedScreenshots.clear();
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
  final title = 'RemindMe Patrol $_runId';
  final notes = 'Created by Patrol $_runId';
  final editedNotes = 'Edited by Patrol $_runId';
  String get editedTitle => '$title edited';
  late TasksRepository repo;
  google.TasksApi? api;
  String? listId;
  String? taskId;
  var deleted = false;
  var createAttempted = false;
  StreamIterator<String>? _googleScreens;
  String? _googleCheckpoint;

  Future<void> theAppStartsWithCleanLocalData() async {
    final reset = await GoogleAccountAndroid.channel
        .invokeMethod<bool>('revokeAccessForPatrol', {'email': _account})
        .timeout(_googleTimeout);
    expect(
      reset,
      isNotNull,
      reason: 'Native authorization reset must respond.',
    );
    $.log(
      reset!
          ? 'Native Google Tasks authorization reset completed.'
          : 'No token to revoke; continuing to mandatory fresh Tasks consent.',
    );
    await app.startApp(authRepository: auth);
    await _waitFor(
      $,
      () => find.byType(LoginScreen).evaluate().isNotEmpty,
      'Clean startup must show the login screen',
    );
    expect(auth.signedIn, isFalse);
  }

  Future<void> iStartGoogleSignIn() async {
    // Do not wait for Flutter frames while Google owns the foreground.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _googleScreens = StreamIterator(_completeSignIn($, auth));
    await _advanceGoogleSignIn();
  }

  Future<void> _advanceGoogleSignIn() async {
    final screens = _googleScreens!;
    _googleCheckpoint = await screens.moveNext() ? screens.current : null;
  }

  Future<void> iContinueGoogleSignInToIfShown(String checkpoint) async {
    const checkpoints = [
      '02_account_selected',
      '02_development_warning',
      '03_development_confirmation',
      '04_tasks_consent',
      '05_tasks_confirmation',
    ];
    final target = checkpoints.indexOf(checkpoint);
    if (target < 0) {
      throw ArgumentError('Unknown Google checkpoint: $checkpoint');
    }
    while (_googleCheckpoint != null &&
        checkpoints.indexOf(_googleCheckpoint!) < target) {
      await _advanceGoogleSignIn();
    }
  }

  Future<void> iFinishGoogleSignIn() async {
    await _advanceGoogleSignIn();
    expect(
      _googleCheckpoint,
      isNull,
      reason: 'All Google checkpoints must be captured.',
    );
  }

  Future<void> iAllowNotificationPermissionIfPrompted() async {
    final android = $.platform.android;
    final clock = Stopwatch()..start();
    while (clock.elapsed < _remoteTimeout) {
      final views = _flatten(
        (await android.getNativeViews(null)).roots,
      ).toList();
      final permissionViews = views.where(
        (view) =>
            view.applicationPackage?.endsWith('.permissioncontroller') ?? false,
      );
      final notificationPrompt = permissionViews.any(
        (view) => _nativeLabel(view).contains('send you notifications'),
      );
      if (notificationPrompt) {
        final allow = permissionViews.where(
          (view) =>
              view.isEnabled &&
              (view.resourceName?.endsWith('/permission_allow_button') ??
                  false),
        );
        if (allow.isNotEmpty) {
          await _tapGoogleView($, allow.first);
          await _waitFor($, () => !auth.signingIn, 'Google sign-in completion');
          return;
        }
      }
      // Keep polling native UI while a system dialog may pause Flutter.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> theSelectedAccountsTaskListShouldLoad() async {
    await _waitFor(
      $,
      () => find.byType(TaskHomeScreen).evaluate().isNotEmpty,
      'Home screen after Google authorization',
    );
    expect(auth.userEmail?.toLowerCase(), _account.toLowerCase());
    expect(auth.signedIn, isTrue);
    repo = Provider.of<TasksRepository>(
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
  }

  Future<void> iEnterATaskTitleAndNotes() async {
    await $(find.byTooltip('Add task')).tap();
    await $(#task_title).enterText(title);
    await $(#task_notes).enterText(notes);
    await _expectEditor($, title: title, notes: notes);
  }

  Future<void> iSaveTheTask() async {
    if (taskId == null) createAttempted = true;
    await $(find.byTooltip('Save task')).tap();
  }

  Future<void> theTaskShouldExistInGoogleTasks() async {
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
  }

  Future<void> iEditTheTasksTitleAndNotes() async {
    await $(find.text(title)).scrollTo().tap();
    await _expectEditor($, title: title, notes: notes);
    await $(#task_title).enterText(editedTitle);
    await $(#task_notes).enterText(editedNotes);
    await _expectEditor($, title: editedTitle, notes: editedNotes);
  }

  Future<void> theSameGoogleTaskShouldContainTheChanges() async {
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
  }

  Future<void> iOpenTheTaskForDeletion() async {
    await $(find.text(editedTitle)).scrollTo().tap();
    await _expectEditor($, title: editedTitle, notes: editedNotes);
  }

  Future<void> iRequestTaskDeletion() async {
    await $(find.byTooltip('Delete task')).tap();
    await _waitFor(
      $,
      () => find.text('Delete task?').evaluate().isNotEmpty,
      'Task deletion confirmation',
    );
  }

  Future<void> iConfirmTaskDeletion() async {
    await $(find.widgetWithText(FilledButton, 'Delete')).tap();
  }

  Future<void> theTaskShouldBeAbsentFromGoogleTasks() async {
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
  }

  Future<void> iRequestSignOut() async {
    await $(find.byTooltip('Menu')).tap();
    await $(find.text('Sign out')).tap();
  }

  Future<void> iConfirmSignOut() async {
    await $.tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await $.platform.android.waitUntilVisible(
      const AndroidSelector(
        applicationPackage: 'android',
        text: 'Choose an account',
      ),
      timeout: _googleTimeout,
    );
  }

  Future<void> iCancelAccountSelection() async {
    await $.platform.android.pressBack();
  }

  Future<void> theLoginScreenShouldAppear() async {
    await _waitFor(
      $,
      () =>
          find.byType(LoginScreen).evaluate().isNotEmpty &&
          !auth.signedIn &&
          !repo.signingIn,
      'Sign in screen after signing out',
    );
    expect(repo.selectedTasklistId, isNull);
    expect(auth.hasLinkedAccount, isFalse);
  }

  Future<void> iCaptureScreenshotAndCompareWithTheGoldenReference(
    String checkpoint,
  ) async {
    if (!RegExp(r'^\d{2}_[a-z0-9_]+$').hasMatch(checkpoint)) {
      throw ArgumentError('Invalid screenshot checkpoint.');
    }
    final googleScreen =
        checkpoint.startsWith('02_') ||
        checkpoint.startsWith('03_') ||
        checkpoint.startsWith('04_') ||
        checkpoint.startsWith('05_');
    if (googleScreen && _googleCheckpoint != checkpoint) {
      expect(
        checkpoint == '04_tasks_consent' ||
            checkpoint == '05_tasks_confirmation',
        isFalse,
        reason: _freshConsentRequired,
      );
      $.log('Optional Google screen was not shown: $checkpoint');
      return;
    }
    await _capture(
      $,
      checkpoint,
      settle: !googleScreen && checkpoint != '15_sign_in_required',
    );
    // Keep each message below Android's log length limit.
    $.log(
      'PATROL_SCREENSHOT_CAPTURE ${jsonEncode({'runId': _runId, ..._capturedScreenshots[checkpoint]!})}',
    );
    $.log(
      'PATROL_SCREENSHOT_SET ${jsonEncode({'runId': _runId, 'screenshotCount': _capturedScreenshots.length})}',
    );
  }

  Future<void> captureFailure() async {
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
  }

  Future<void> cleanUp() async {
    await _googleScreens?.cancel();
    final api = this.api;
    final listId = this.listId;
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
  if (checkpoint != '99_failure') {
    final padding = $.tester.view.viewPadding;
    _capturedScreenshots[checkpoint] = {
      'checkpoint': checkpoint,
      'left': padding.left.round(),
      'top': padding.top.round(),
      'right': padding.right.round(),
      'bottom': padding.bottom.round(),
    };
  }
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

Stream<String> _completeSignIn(
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
      screenClock.elapsed < _googleTimeout) {
    if (find.byType(TaskHomeScreen).evaluate().isNotEmpty) {
      expect(sawTasks, isTrue, reason: _freshConsentRequired);
      expect(auth.hasLinkedAccount, isTrue);
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
        ).hasMatch(_nativeLabel(view)),
      );
      if (developmentLinks.isNotEmpty) {
        yield '03_development_confirmation';
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
    final accountConfirmation = googleViews.where(
      (view) =>
          selectedAccount &&
          view.applicationPackage == 'android' &&
          view.isEnabled &&
          _nativeLabel(view).toLowerCase() == 'ok',
    );
    if (accountConfirmation.isNotEmpty) {
      yield '02_account_selected';
      await _tapGoogleView($, accountConfirmation.first);
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
          ].contains(_nativeLabel(view).toLowerCase()),
    );
    if (buttons.isNotEmpty) {
      final button = buttons.first;
      if (sawTasks && !confirmedTasks) {
        yield '05_tasks_confirmation';
        confirmedTasks = true;
      }
      await _tapGoogleView($, button);
      screenClock.reset();
      continue;
    }
    final consentPage = googleViews.any(
      (view) => _nativeLabel(
        view,
      ).toLowerCase().contains('wants access to your google account'),
    );
    if ((sawTasks || consentPage) &&
        consentScrolls < 8 &&
        (tasksPermission ||
            consentPage ||
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
      expect(sawTasks, isTrue, reason: _freshConsentRequired);
      expect(auth.hasLinkedAccount, isTrue);
      return;
    }
  }
  fail(
    sawTasks
        ? 'Google authorization did not finish within 60 seconds.'
        : _freshConsentRequired,
  );
}
