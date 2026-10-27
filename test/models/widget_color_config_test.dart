import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/models/widget_color_config.dart';

void main() {
  test('construct should use defaults when no args', () {
    const config = WidgetColorConfig();

    expect(config.textColor, 0xFF211B2B);
    expect(config.backgroundColor, 0xFFFAF8FC);
    expect(config.backgroundAlpha, 0xF2);
    expect(config.overdueColor, 0xFFB73545);
  });

  test('copyWith should override only provided fields', () {
    const config = WidgetColorConfig();

    final updated = config.copyWith(overdueColor: 0xFF00FF00);

    expect(updated.overdueColor, 0xFF00FF00);
    expect(updated.textColor, config.textColor);
    expect(updated.backgroundColor, config.backgroundColor);
    expect(updated.backgroundAlpha, config.backgroundAlpha);
  });

  test('toJson/fromJson should round-trip', () {
    const config = WidgetColorConfig(
      textColor: 0xFF123456,
      backgroundColor: 0xFF654321,
      backgroundAlpha: 0x40,
      overdueColor: 0xFFABCDEF,
    );

    final restored = WidgetColorConfig.fromJson(config.toJson());

    expect(restored.textColor, config.textColor);
    expect(restored.backgroundColor, config.backgroundColor);
    expect(restored.backgroundAlpha, config.backgroundAlpha);
    expect(restored.overdueColor, config.overdueColor);
  });

  test('fromJsonString should use defaults when json is invalid', () {
    final config = WidgetColorConfig.fromJsonString('not json');

    expect(config.textColor, 0xFF211B2B);
    expect(config.overdueColor, 0xFFB73545);
  });

  test('fromJsonString should use defaults when json is missing keys', () {
    final config = WidgetColorConfig.fromJsonString('{"textColor":255}');

    expect(config.textColor, 255);
    expect(config.overdueColor, 0xFFB73545);
  });
}
