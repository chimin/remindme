import 'package:home_widget/home_widget.dart';

import '../models/widget_color_config.dart';

class WidgetColorService {
  WidgetColorService._();

  static const String configKey = 'task_widget_config';

  static Future<WidgetColorConfig> loadConfig() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>(configKey);
      return WidgetColorConfig.fromJsonString(raw);
    } catch (_) {
      return const WidgetColorConfig();
    }
  }

  static Future<void> saveConfig(WidgetColorConfig config) async {
    await HomeWidget.saveWidgetData<String>(configKey, config.toJsonString());
  }
}
