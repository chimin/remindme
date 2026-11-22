import '../scenario_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/models/task_metadata.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};

  scenarios['0'] = (state) async {
    state.next = () async {
      final metadata = TaskMetadata('hello', {
        'future': {'color': 'red'},
        'recurrence': {'frequency': 'monthly', 'anchorDay': 31},
      });
      final parsed = TaskMetadata.parse(metadata.encode(userNotes: 'edited'));
      state.next = () async {
        expect(parsed.notes, 'edited');
        expect(parsed.data['future'], {'color': 'red'});
        expect(parsed.frequency, 'monthly');
      };
    };
  };
  scenarios['1'] = (state) async {
    state.next = () async {
      const notes = 'hello\n[remindme:v1]\nbroken\n[/remindme]';
      state.next = () async {
        expect(TaskMetadata.parse(notes).encode(), notes);
      };
    };
  };
  scenarios['2'] = (state) async {
    state.next = () async {
      const notes = '[remindme:v2]\n{}\n[/remindme]';
      state.next = () async {
        expect(TaskMetadata.parse(notes).encode(), notes);
      };
    };
  };
  scenarios['3'] = (state) async {
    state.next = () async {
      final metadata = TaskMetadata('', {
        'recurrence': {'frequency': 'monthly', 'anchorDay': 31},
      });
      final february = metadata.nextDue(
        DateTime.utc(2027, 1, 31),
        DateTime.utc(2027, 1, 31),
      )!;
      state.next = () async {
        expect(february, DateTime.utc(2027, 2, 28));
        expect(metadata.nextDue(february, february), DateTime.utc(2027, 3, 31));
      };
    };
  };
  scenarios['4'] = (state) async {
    state.next = () async {
      final metadata = TaskMetadata('', {
        'recurrence': {'frequency': 'weekly', 'interval': 2},
      });
      state.next = () async {
        expect(
          metadata.nextDue(
            DateTime.utc(2026, 10, 1),
            DateTime.utc(2026, 10, 29),
          ),
          DateTime.utc(2026, 11, 12),
        );
      };
    };
  };
  scenarios['5'] = (state) async {
    state.next = () async {
      final metadata = TaskMetadata('', {
        'recurrence': {'frequency': 'yearly', 'anchorDay': 29},
      });
      state.next = () async {
        expect(
          metadata.nextDue(
            DateTime.utc(2027, 2, 28),
            DateTime.utc(2027, 2, 28),
          ),
          DateTime.utc(2028, 2, 29),
        );
      };
    };
  };
  scenarios['6'] = (state) async {
    state.next = () async {
      final metadata = TaskMetadata('', {
        'recurrence': {'frequency': 'daily', 'interval': 0},
      });
      state.next = () async {
        expect(
          metadata.nextDue(DateTime.utc(2026), DateTime.utc(2026)),
          isNull,
        );
      };
    };
  };

  return scenarios;
}
