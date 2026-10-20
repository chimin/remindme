import 'package:flutter/material.dart';

import '../models/widget_color_config.dart';

const _swatches = <int>[
  0xFF000000,
  0xFFFFFFFF,
  0xFF2196F3,
  0xFF4CAF50,
  0xFFF44336,
  0xFFFF9800,
  0xFF9C27B0,
];

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Widget colors'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Text color'),
            _swatchRow(
              selected: _config.textColor,
              onSelect: (c) => setState(() => _config = _config.copyWith(textColor: c)),
            ),
            const SizedBox(height: 12),
            const Text('Background color'),
            _swatchRow(
              selected: _config.backgroundColor,
              onSelect: (c) => setState(() => _config = _config.copyWith(backgroundColor: c)),
            ),
            const SizedBox(height: 12),
            Text('Transparency: ${((1 - _config.backgroundAlpha / 255) * 100).round()}%'),
            Slider(
              value: _config.backgroundAlpha.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => setState(() => _config = _config.copyWith(backgroundAlpha: v.round())),
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

  Widget _swatchRow({required int selected, required ValueChanged<int> onSelect}) {
    return Wrap(
      spacing: 8,
      children: _swatches.map((c) {
        return GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected == c ? Colors.blue : Colors.grey,
                width: selected == c ? 3 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
