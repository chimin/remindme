import 'package:flutter/material.dart';
import '../models/widget_color_config.dart';
import '../widgets/color_picker.dart';

/// Edits widget colors with a live preview before saving.
class WidgetColorConfigDialog extends StatefulWidget {
  const WidgetColorConfigDialog({
    super.key,
    required this.initial,
    required this.onSaved,
  });
  final WidgetColorConfig initial;
  final ValueChanged<WidgetColorConfig> onSaved;
  @override
  State<WidgetColorConfigDialog> createState() =>
      _WidgetColorConfigDialogState();
}

class _WidgetColorConfigDialogState extends State<WidgetColorConfigDialog> {
  late WidgetColorConfig _config = widget.initial;
  static const _dark = WidgetColorConfig(
    textColor: 0xFFF5F0FA,
    backgroundColor: 0xFF272131,
    backgroundAlpha: 242,
    overdueColor: 0xFFFFB4AB,
  );
  String get _preset {
    if (_config.toJsonString() == const WidgetColorConfig().toJsonString()) {
      return 'Light';
    }
    if (_config.toJsonString() == _dark.toJsonString()) return 'Dark';
    return 'Custom';
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
    if (picked != null && mounted) onPicked(picked);
  }

  Widget _preview() {
    final text = Color(_config.textColor);
    return Semantics(
      label: 'Live widget appearance preview',
      child: Container(
        key: const ValueKey('widget_preview'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE5DCF0), Color(0xFF8D78A8)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(
              _config.backgroundColor,
            ).withValues(alpha: _config.backgroundAlpha / 255),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DefaultTextStyle(
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: text),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Tasks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Overdue',
                  style: TextStyle(
                    color: Color(_config.overdueColor),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_box_outline_blank, size: 20, color: text),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Renew library books')),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Today',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_box_outline_blank, size: 20, color: text),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Water plants')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Widget appearance'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _preview(),
              const SizedBox(height: 20),
              const Text('Theme'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final preset in ['Light', 'Dark'])
                    ChoiceChip(
                      label: Text(preset),
                      selected: _preset == preset,
                      onSelected: (_) => setState(
                        () => _config = preset == 'Light'
                            ? const WidgetColorConfig()
                            : _dark,
                      ),
                    ),
                  if (_preset == 'Custom') const Chip(label: Text('Custom')),
                ],
              ),
              const SizedBox(height: 12),
              _ColorRow(
                label: 'Text color',
                color: _config.textColor,
                onPick: () => _pickColor(
                  title: 'Text color',
                  current: _config.textColor,
                  onPicked: (c) =>
                      setState(() => _config = _config.copyWith(textColor: c)),
                ),
              ),
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
              _ColorRow(
                label: 'Background color',
                color: _config.backgroundColor,
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
                'Background opacity: ${(_config.backgroundAlpha / 255 * 100).round()}%',
              ),
              Slider(
                value: _config.backgroundAlpha.toDouble(),
                min: 0,
                max: 255,
                label: '${(_config.backgroundAlpha / 255 * 100).round()}%',
                onChanged: (v) => setState(
                  () => _config = _config.copyWith(backgroundAlpha: v.round()),
                ),
              ),
              Text(
                'Higher opacity makes tasks easier to read.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _config = const WidgetColorConfig()),
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  widget.onSaved(_config);
                  Navigator.of(context).pop();
                },
                child: const Text('Save appearance'),
              ),
            ),
          ],
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
  });
  final String label;
  final int color;
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('color_box_$label'),
    onTap: onPick,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color(color),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );
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
