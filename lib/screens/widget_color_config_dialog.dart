import 'package:flutter/material.dart';

import '../models/widget_color_config.dart';
import '../widgets/color_picker.dart';

/// Dialog that lets the user configure the home-screen widget colors.
///
/// Three colors can be configured: the task text color, the widget background
/// color and the color of the "Overdue" group title. The background
/// transparency is controlled by a separate slider.
class WidgetColorConfigDialog extends StatefulWidget {
  const WidgetColorConfigDialog({
    super.key,
    required this.initial,
    required this.onSaved,
  });

  final WidgetColorConfig initial;
  final ValueChanged<WidgetColorConfig> onSaved;

  @override
  State<WidgetColorConfigDialog> createState() => _WidgetColorConfigDialogState();
}

class _WidgetColorConfigDialogState extends State<WidgetColorConfigDialog> {
  late WidgetColorConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initial;
  }

  Future<void> _pickColor({
    required String title,
    required int current,
    required ValueChanged<int> onPicked,
  }) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => _ColorPickerDialog(title: title, color: current),
    );
    if (picked == null) return;
    onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Widget colors'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ColorRow(
              label: 'Text color',
              color: _config.textColor,
              onPick: () => _pickColor(
                title: 'Text color',
                current: _config.textColor,
                onPicked: (c) => setState(
                  () => _config = _config.copyWith(textColor: c),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ColorRow(
              label: 'Overdue title color',
              color: _config.overdueColor,
              onPick: () => _pickColor(
                title: 'Overdue title color',
                current: _config.overdueColor,
                onPicked: (c) => setState(
                  () => _config = _config.copyWith(overdueColor: c),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ColorRow(
              label: 'Background color',
              color: _config.backgroundColor,
              alpha: _config.backgroundAlpha,
              onPick: () => _pickColor(
                title: 'Background color',
                current: _config.backgroundColor,
                onPicked: (c) => setState(
                  () => _config = _config.copyWith(backgroundColor: c),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Transparency: '
              '${((1 - _config.backgroundAlpha / 255) * 100).round()}%',
            ),
            Slider(
              value: _config.backgroundAlpha.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => setState(
                () => _config = _config.copyWith(backgroundAlpha: v.round()),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onSaved(_config);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.onPick,
    this.alpha,
  });

  final String label;
  final int color;
  final int? alpha;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final value = Color(color);
    final preview = alpha == null
        ? value
        : value.withValues(alpha: alpha! / 255);
    return Row(
      children: [
        Expanded(child: Text(label)),
        GestureDetector(
          key: ValueKey('color_box_$label'),
          onTap: onPick,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: preview,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog wrapping [ColorPicker] that returns the picked color.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.title, required this.color});

  final String title;
  final int color;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color = Color(widget.color);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: ColorPicker(
            color: _color,
            onChanged: (c) => setState(() => _color = c),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_color.toARGB32()),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
