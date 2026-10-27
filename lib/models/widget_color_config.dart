import 'dart:convert';

class WidgetColorConfig {
  const WidgetColorConfig({
    this.textColor = 0xFF211B2B,
    this.backgroundColor = 0xFFFAF8FC,
    this.backgroundAlpha = 0xF2,
    this.overdueColor = 0xFFB73545,
  });

  final int textColor;
  final int backgroundColor;
  final int backgroundAlpha;

  /// Color of the "Overdue" group title in the widget.
  final int overdueColor;

  WidgetColorConfig copyWith({
    int? textColor,
    int? backgroundColor,
    int? backgroundAlpha,
    int? overdueColor,
  }) {
    return WidgetColorConfig(
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundAlpha: backgroundAlpha ?? this.backgroundAlpha,
      overdueColor: overdueColor ?? this.overdueColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'textColor': textColor,
    'backgroundColor': backgroundColor,
    'backgroundAlpha': backgroundAlpha,
    'overdueColor': overdueColor,
  };

  factory WidgetColorConfig.fromJson(Map<String, dynamic> json) {
    return WidgetColorConfig(
      textColor: (json['textColor'] as num?)?.toInt() ?? 0xFF211B2B,
      backgroundColor: (json['backgroundColor'] as num?)?.toInt() ?? 0xFFFAF8FC,
      backgroundAlpha: (json['backgroundAlpha'] as num?)?.toInt() ?? 0xF2,
      overdueColor: (json['overdueColor'] as num?)?.toInt() ?? 0xFFB73545,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static WidgetColorConfig fromJsonString(String? s) {
    if (s == null || s.isEmpty) return const WidgetColorConfig();
    try {
      return WidgetColorConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const WidgetColorConfig();
    }
  }
}
