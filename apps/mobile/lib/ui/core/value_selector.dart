import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds [builder] only when the value selected from [listenable] changes.
///
/// Lets each instrument subscribe to just the telemetry fields it displays so
/// that unrelated widgets and the layout canvas are not rebuilt per tick.
class ValueSelector<S, T> extends StatefulWidget {
  const ValueSelector({
    super.key,
    required this.listenable,
    required this.select,
    required this.builder,
    this.equals,
  });

  final ValueListenable<S> listenable;
  final T Function(S value) select;
  final Widget Function(BuildContext context, T value) builder;

  /// Custom equality; defaults to `==`.
  final bool Function(T a, T b)? equals;

  @override
  State<ValueSelector<S, T>> createState() => _ValueSelectorState<S, T>();
}

class _ValueSelectorState<S, T> extends State<ValueSelector<S, T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.select(widget.listenable.value);
    widget.listenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ValueSelector<S, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.listenable, widget.listenable)) {
      oldWidget.listenable.removeListener(_onChanged);
      widget.listenable.addListener(_onChanged);
    }
    _value = widget.select(widget.listenable.value);
  }

  void _onChanged() {
    final next = widget.select(widget.listenable.value);
    final same = widget.equals?.call(_value, next) ?? (_value == next);
    if (same) return;
    setState(() => _value = next);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
