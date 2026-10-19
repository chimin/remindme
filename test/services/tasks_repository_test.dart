import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';

import 'package:remindme/services/tasks_repository.dart';

void main() {
  test(
    'mergeTasks should keep the local entry when it is newer than the remote entry',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = [
        CachedTask(
          id: 'a', tasklistId: 'l', title: 'Local',
          updatedAt: nowMs, dirty: true,
        ),
      ];
      final remote = [
        Task(
          id: 'a', title: 'Remote',
          updated: DateTime(2026, 1, 15, 10, 0, 0).toUtc().toIso8601String(),
        ),
      ];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.title, 'Local');
      expect(result.first.dirty, isTrue);
    },
  );

  test(
    'mergeTasks should prefer the remote entry when it is newer than the local entry',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = [
        CachedTask(
          id: 'a', tasklistId: 'l', title: 'Local',
          updatedAt: DateTime(2026, 1, 15, 10, 0, 0).millisecondsSinceEpoch,
          dirty: true,
        ),
      ];
      final remote = [
        Task(
          id: 'a', title: 'Remote',
          updated: DateTime(2026, 1, 15, 12, 0, 0).toUtc().toIso8601String(),
        ),
      ];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.title, 'Remote');
      expect(result.first.dirty, isFalse);
    },
  );

  test(
    'mergeTasks should preserve a locally-requested deletion when newer than the remote entry',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = [
        CachedTask(
          id: 'a', tasklistId: 'l', title: 'Local',
          updatedAt: nowMs, isDeleted: true, dirty: true,
        ),
      ];
      final remote = [
        Task(
          id: 'a', title: 'Remote',
          updated: DateTime(2026, 1, 15, 10, 0, 0).toUtc().toIso8601String(),
        ),
      ];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.isDeleted, isTrue);
    },
  );

  test(
    'mergeTasks should add remote-only tasks and clear the dirty flag',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = <CachedTask>[];
      final remote = [
        Task(
          id: 'b', title: 'Remote only',
          updated: DateTime(2026, 1, 15, 10, 0, 0).toUtc().toIso8601String(),
        ),
      ];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.id, 'b');
      expect(result.first.title, 'Remote only');
      expect(result.first.dirty, isFalse);
      expect(result.first.isDeleted, isFalse);
    },
  );

  test(
    'mergeTasks should keep local-only entries that are not present remotely',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = [
        CachedTask(id: 'a', tasklistId: 'l', title: 'Local only', updatedAt: nowMs),
      ];
      final remote = <Task>[];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.id, 'a');
      expect(result.first.title, 'Local only');
    },
  );
}
