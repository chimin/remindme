import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;

/// A popup menu entry that marks the active choice with a checkmark placed on
/// the trailing (right) edge.
///
/// [CheckedPopupMenuItem] always renders its checkmark in the leading slot,
/// which pushes the label away from the left edge. This entry keeps the label
/// on the left and puts the tick on the right, aligned with the right edge of
/// the menu.
class TrailingCheckedMenuItem<T> extends PopupMenuItem<T> {
  /// Creates a menu entry labelled [label] that shows a checkmark on the
  /// trailing edge when [checked] is true.
  const TrailingCheckedMenuItem({
    super.key,
    super.value,
    required this.label,
    this.checked = false,
    super.enabled,
    super.height,
    super.padding,
  }) : super(child: const SizedBox.shrink());

  /// Text shown for this entry.
  final String label;

  /// Whether this entry is the active choice and therefore shows a checkmark.
  final bool checked;

  @override
  PopupMenuItemState<T, TrailingCheckedMenuItem<T>> createState() =>
      _TrailingCheckedMenuItemState<T>();
}

class _TrailingCheckedMenuItemState<T>
    extends PopupMenuItemState<T, TrailingCheckedMenuItem<T>> {
  @override
  Widget? buildChild() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(widget.label)),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(widget.checked ? Icons.done : null),
        ),
      ],
    );
  }

  @override
  Widget buildSemantics({required Widget child}) {
    return Semantics(
      role: SemanticsRole.menuItemCheckbox,
      enabled: widget.enabled,
      checked: widget.checked,
      button: true,
      child: child,
    );
  }
}
