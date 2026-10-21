import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A color picker that allows selecting any color.
///
/// The picker is built from three parts:
///  - a saturation/value area that picks the tint and brightness of the
///    currently selected hue,
///  - a hue slider that picks the base hue,
///  - a hex field that allows typing an exact color value.
///
/// The picked color is always fully opaque; the alpha channel is left to the
/// caller (the widget background uses a separate transparency setting).
class ColorPicker extends StatefulWidget {
  const ColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  /// Formats [color] as an uppercase `#RRGGBB` string.
  static String formatHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Parses a hex string such as `#FF0000`, `FF0000` or `#F00`.
  ///
  /// Returns `null` when the value is not a valid hex color.
  static Color? parseHex(String text) {
    var value = text.trim().replaceFirst('#', '').toUpperCase();
    if (value.length == 3) {
      value = value.split('').map((c) => '$c$c').join();
    }
    if (value.length != 6) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  static const double _areaHeight = 140;
  static const double _hueHeight = 24;
  static const double _thumbSize = 16;

  late HSVColor _hsv;
  final TextEditingController _hexController = TextEditingController();
  final FocusNode _hexFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
    _hexController.text = ColorPicker.formatHex(_hsv.toColor());
  }

  @override
  void didUpdateWidget(ColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != oldWidget.color && !_hexFocus.hasFocus) {
      _hsv = HSVColor.fromColor(widget.color);
      _hexController.text = ColorPicker.formatHex(_hsv.toColor());
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  void _update(HSVColor next) {
    setState(() {
      _hsv = next;
      _hexController.text = ColorPicker.formatHex(next.toColor());
    });
    widget.onChanged(next.toColor());
  }

  void _onHexSubmitted(String text) {
    final parsed = ColorPicker.parseHex(text);
    if (parsed == null) {
      _hexController.text = ColorPicker.formatHex(_hsv.toColor());
      return;
    }
    setState(() {
      _hsv = HSVColor.fromColor(parsed);
      _hexController.text = ColorPicker.formatHex(parsed);
    });
    widget.onChanged(parsed);
  }

  Color get _hueColor => HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTapDown: (details) => _onAreaChanged(details.localPosition, width),
              onPanDown: (details) => _onAreaChanged(details.localPosition, width),
              onPanUpdate: (details) =>
                  _onAreaChanged(details.localPosition, width),
              child: SizedBox(
                height: _areaHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, _hueColor],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _hsv.saturation * width - _thumbSize / 2,
                      top: (1 - _hsv.value) * (_areaHeight - _thumbSize),
                      child: _thumb(_hsv.toColor()),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTapDown: (details) => _onHueChanged(details.localPosition.dx, width),
              onPanDown: (details) => _onHueChanged(details.localPosition.dx, width),
              onPanUpdate: (details) =>
                  _onHueChanged(details.localPosition.dx, width),
              child: SizedBox(
                height: _hueHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF0000),
                              Color(0xFFFFFF00),
                              Color(0xFF00FF00),
                              Color(0xFF00FFFF),
                              Color(0xFF0000FF),
                              Color(0xFFFF00FF),
                              Color(0xFFFF0000),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (_hsv.hue / 360) * (width - _thumbSize),
                      top: (_hueHeight - _thumbSize) / 2,
                      child: _thumb(_hueColor, borderColor: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hexController,
                focusNode: _hexFocus,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(7),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9a-fA-F#]'),
                  ),
                ],
                onSubmitted: _onHexSubmitted,
                decoration: const InputDecoration(
                  labelText: 'Hex',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _thumb(Color color, {Color borderColor = Colors.black}) {
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }

  void _onAreaChanged(Offset position, double width) {
    final saturation = (position.dx / width).clamp(0.0, 1.0);
    final value = (1 - position.dy / _areaHeight).clamp(0.0, 1.0);
    _update(_hsv.withSaturation(saturation).withValue(value));
  }

  void _onHueChanged(double dx, double width) {
    final hue = ((dx / width) * 360).clamp(0.0, 360.0);
    _update(_hsv.withHue(hue));
  }
}
