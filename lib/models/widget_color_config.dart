import 'dart:convert';

class WidgetColorConfig {
  const WidgetColorConfig({
    this.textColor = 0xFF000000,
    this.backgroundColor = 0xFFFFFFFF,
    this.backgroundAlpha = 0x80,
  });

  final int textColor;
  final int backgroundColor;
  final int backgroundAlpha;

  WidgetColorConfig copyWith({
    int? textColor,
    int? backgroundColor,
    int? backgroundAlpha,
  }) {
    return WidgetColorConfig(
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundAlpha: backgroundAlpha ?? this.backgroundAlpha,
    );
  }

  Map<String, dynamic> toJson() => {
        'textColor': textColor,
        'backgroundColor': backgroundColor,
        'backgroundAlpha': backgroundAlpha,
      };

  factory WidgetColorConfig.fromJson(Map<String, dynamic> json) {
    return WidgetColorConfig(
      textColor: (json['textColor'] as num?)?.toInt() ?? 0xFF000000,
      backgroundColor: (json['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      backgroundAlpha: (json['backgroundAlpha'] as num?)?.toInt() ?? 0x80,
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
