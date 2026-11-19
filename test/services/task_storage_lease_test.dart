import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/services/task_storage_lease.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'acquire should defer a worker when another engine owns task storage',
    () async {
      final foreground = TaskStorageLease();
      final worker = TaskStorageLease();
      addTearDown(foreground.release);
      addTearDown(worker.release);
      expect(await foreground.acquire(), isTrue);
      expect(await worker.acquire(wait: false), isFalse);
      foreground.release();
      expect(await worker.acquire(wait: false), isTrue);
    },
  );
}
