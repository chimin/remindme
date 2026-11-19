import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

/// Hive boxes must have a single owner across foreground and worker engines.
class TaskStorageLease {
  static const _name = 'chimin.remindme.task_storage';
  ReceivePort? _port;
  Future<bool> acquire({bool wait = true}) async {
    if (_port != null) return true;
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    do {
      final port = ReceivePort();
      if (IsolateNameServer.registerPortWithName(port.sendPort, _name)) {
        port.listen((_) {});
        _port = port;
        return true;
      }
      port.close();
      if (!wait) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } while (DateTime.now().isBefore(deadline));
    throw TimeoutException('Task storage is busy. Please retry.');
  }

  void release() {
    if (_port == null) return;
    IsolateNameServer.removePortNameMapping(_name);
    _port!.close();
    _port = null;
  }
}
