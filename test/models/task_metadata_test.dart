import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/models/task_metadata.dart';

void main() {
  test('encode should preserve unknown fields when notes are edited', () {
    final metadata = TaskMetadata('hello', {
      'future': {'color': 'red'},
      'recurrence': {'frequency': 'monthly', 'anchorDay': 31},
    });
    final parsed = TaskMetadata.parse(metadata.encode(userNotes: 'edited'));
    expect(parsed.notes, 'edited');
    expect(parsed.data['future'], {'color': 'red'});
    expect(parsed.frequency, 'monthly');
  });
  test('parse should preserve notes when metadata is malformed', () {
    const notes = 'hello\n[remindme:v1]\nbroken\n[/remindme]';
    expect(TaskMetadata.parse(notes).encode(), notes);
  });
  test('parse should preserve notes when metadata version is unsupported', () {
    const notes = '[remindme:v2]\n{}\n[/remindme]';
    expect(TaskMetadata.parse(notes).encode(), notes);
  });
  test('next due should restore anchor day when February has fewer days', () {
    final metadata = TaskMetadata('', {
      'recurrence': {'frequency': 'monthly', 'anchorDay': 31},
    });
    final february = metadata.nextDue(
      DateTime.utc(2027, 1, 31),
      DateTime.utc(2027, 1, 31),
    )!;
    expect(february, DateTime.utc(2027, 2, 28));
    expect(metadata.nextDue(february, february), DateTime.utc(2027, 3, 31));
  });
  test('next due should skip missed dates when a task is overdue', () {
    final metadata = TaskMetadata('', {
      'recurrence': {'frequency': 'weekly', 'interval': 2},
    });
    expect(
      metadata.nextDue(DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 29)),
      DateTime.utc(2026, 11, 12),
    );
  });
  test('next due should restore leap day when the next leap year arrives', () {
    final metadata = TaskMetadata('', {
      'recurrence': {'frequency': 'yearly', 'anchorDay': 29},
    });
    expect(
      metadata.nextDue(DateTime.utc(2027, 2, 28), DateTime.utc(2027, 2, 28)),
      DateTime.utc(2028, 2, 29),
    );
  });
  test('next due should ignore recurrence when interval is invalid', () {
    final metadata = TaskMetadata('', {
      'recurrence': {'frequency': 'daily', 'interval': 0},
    });
    expect(metadata.nextDue(DateTime.utc(2026), DateTime.utc(2026)), isNull);
  });
}
