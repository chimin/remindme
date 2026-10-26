import 'dart:convert';

/// Extensible application data stored alongside the user's Google Tasks notes.
class TaskMetadata {
  TaskMetadata(this.notes, this.data);

  final String notes;
  final Map<String, dynamic> data;
  static final _block = RegExp(
    r'(?:\r?\n)?\[remindme:v1\]\r?\n([\s\S]*?)\r?\n\[/remindme\]$',
  );

  factory TaskMetadata.parse(String? value) {
    final text = value ?? '';
    final match = _block.firstMatch(text);
    if (match != null) {
      try {
        final data = jsonDecode(match.group(1)!);
        if (data is Map<String, dynamic>) {
          return TaskMetadata(text.substring(0, match.start), data);
        }
      } on FormatException {
        // Preserve unrecognised content as user notes.
      }
    }
    return TaskMetadata(text, {});
  }

  String encode({String? userNotes}) {
    final text = userNotes ?? notes;
    final result = data.isEmpty
        ? text
        : '$text${text.isEmpty ? '' : '\n'}[remindme:v1]\n${jsonEncode(data)}\n[/remindme]';
    if (result.length > 8192) {
      throw ArgumentError('Notes exceed Google Tasks limit');
    }
    return result;
  }

  String? get frequency {
    final rule = data['recurrence'];
    if (rule is! Map) return null;
    final value = rule['frequency'];
    return const ['daily', 'weekly', 'monthly', 'yearly'].contains(value)
        ? value as String
        : null;
  }

  DateTime? nextDue(DateTime due, DateTime now) {
    final frequency = this.frequency;
    if (frequency == null) return null;
    final rule = data['recurrence'] as Map;
    final interval = rule['interval'] ?? 1;
    if (interval is! int || interval < 1) return null;
    final anchor = rule['anchorDay'] ?? due.day;
    if (anchor is! int || anchor < 1 || anchor > 31) return null;
    final today = DateTime.utc(now.year, now.month, now.day);
    var next = DateTime.utc(due.year, due.month, due.day);
    do {
      if (frequency == 'daily' || frequency == 'weekly') {
        next = next.add(
          Duration(days: interval * (frequency == 'weekly' ? 7 : 1)),
        );
      } else {
        final month = DateTime.utc(
          next.year + (frequency == 'yearly' ? interval : 0),
          next.month + (frequency == 'monthly' ? interval : 0),
        );
        final last = DateTime.utc(month.year, month.month + 1, 0).day;
        next = DateTime.utc(
          month.year,
          month.month,
          anchor > last ? last : anchor,
        );
      }
    } while (!next.isAfter(today));
    return next;
  }
}
