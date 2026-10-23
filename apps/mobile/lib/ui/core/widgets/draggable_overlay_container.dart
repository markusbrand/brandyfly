import 'package:flutter/material.dart';

/// A reusable 2D free-floating container for cockpit overlays (simulation,
/// recording status, replay control, and edit mode dock).
///
/// Features:
/// - Free 2D pan-to-move repositioning within the safe area.
/// - Clamps within viewport boundaries minus [MediaQuery.paddingOf(context)] and [margin].
/// - Automatically re-clamps when viewport constraints or child dimensions change
///   (e.g., orientation changes or expand/collapse transitions).
/// - Non-intercepting [Stack] layout: touches outside the child card pass
///   through to underlying flight instruments and map layers.
/// - Supports both uncontrolled (internal drag state) and controlled positioning.
class DraggableOverlayContainer extends StatefulWidget {
  const DraggableOverlayContainer({
    super.key,
    required this.child,
    this.cardKey,
    this.initialPosition,
    this.initialAlignment = Alignment.topRight,
    this.margin = const EdgeInsets.all(4),
    this.position,
    this.onPositionChanged,
    this.onPanStart,
    this.onPanEnd,
    this.enableDrag = true,
    this.semanticsLabel = 'Move overlay',
  });

  /// The child overlay card.
  final Widget child;

  /// Optional Key applied to the interactive draggable card widget.
  final Key? cardKey;

  /// Initial position offset if known before the first drag.
  final Offset? initialPosition;

  /// Default viewport alignment when neither [position] nor [initialPosition]
  /// is supplied. Defaults to [Alignment.topRight].
  final Alignment initialAlignment;

  /// Insets from the safe area boundaries. Defaults to 4 dp on all sides.
  final EdgeInsets margin;

  /// Controlled offset overriding internal drag state. When updated from non-null
  /// to null, internal drag position is reset.
  final Offset? position;

  /// Callback fired when the overlay is dragged to a new clamped position.
  final ValueChanged<Offset>? onPositionChanged;

  /// Callback fired when dragging begins.
  final GestureDragStartCallback? onPanStart;

  /// Callback fired when dragging ends.
  final GestureDragEndCallback? onPanEnd;

  /// Whether dragging is enabled. When false, the card remains stationary.
  final bool enableDrag;

  /// Accessibility label for the draggable container.
  final String semanticsLabel;

  @override
  State<DraggableOverlayContainer> createState() =>
      _DraggableOverlayContainerState();
}

class _DraggableOverlayContainerState
    extends State<DraggableOverlayContainer> {
  final GlobalKey _cardInternalKey = GlobalKey();
  Offset? _draggedPosition;
  Size? _lastCardSize;

  GlobalKey get _effectiveCardKey =>
      (widget.cardKey is GlobalKey)
          ? widget.cardKey as GlobalKey
          : _cardInternalKey;

  @override
  void initState() {
    super.initState();
    _draggedPosition = widget.position ?? widget.initialPosition;
  }

  @override
  void didUpdateWidget(DraggableOverlayContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position) {
      _draggedPosition = widget.position;
    }
  }

  Offset _clampPosition(
    Offset target,
    BoxConstraints constraints,
    EdgeInsets safePadding,
    Size cardSize,
  ) {
    final minX = safePadding.left + widget.margin.left;
    final maxX = (constraints.maxWidth -
            cardSize.width -
            safePadding.right -
            widget.margin.right)
        .clamp(minX, double.infinity);

    final minY = safePadding.top + widget.margin.top;
    final maxY = (constraints.maxHeight -
            cardSize.height -
            safePadding.bottom -
            widget.margin.bottom)
        .clamp(minY, double.infinity);

    return Offset(
      target.dx.clamp(minX, maxX),
      target.dy.clamp(minY, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final safePadding = MediaQuery.paddingOf(context);

        final RenderBox? box =
            _effectiveCardKey.currentContext?.findRenderObject()
                as RenderBox?;
        if (box != null && box.hasSize) {
          _lastCardSize = box.size;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final RenderBox? b = _effectiveCardKey.currentContext
              ?.findRenderObject() as RenderBox?;
          if (b != null && b.hasSize && b.size != _lastCardSize) {
            setState(() {
              _lastCardSize = b.size;
            });
          }
        });
        final cardSize = _lastCardSize ?? Size.zero;

        final activeOffset = widget.position ?? _draggedPosition;

        Offset? clampedPos;
        if (activeOffset != null) {
          clampedPos = _clampPosition(
            activeOffset,
            constraints,
            safePadding,
            cardSize,
          );
        }

        Widget card = Container(
          key: _effectiveCardKey,
          child: widget.child,
        );

        if (widget.enableDrag) {
          card = Semantics(
            button: true,
            label: widget.semanticsLabel,
            child: GestureDetector(
              key: widget.cardKey,
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                if (_draggedPosition == null && widget.position == null) {
                  final RenderBox? b =
                      _effectiveCardKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  final RenderBox? rootBox =
                      context.findRenderObject() as RenderBox?;
                  if (b != null &&
                      b.hasSize &&
                      rootBox != null &&
                      rootBox.hasSize) {
                    _draggedPosition = rootBox.globalToLocal(
                      b.localToGlobal(Offset.zero),
                    );
                  }
                }
                widget.onPanStart?.call(details);
              },
              onPanUpdate: (details) {
                final currentPos =
                    widget.position ??
                    _draggedPosition ??
                    clampedPos ??
                    Offset(
                      safePadding.left + widget.margin.left,
                      safePadding.top + widget.margin.top,
                    );

                final next = Offset(
                  currentPos.dx + details.delta.dx,
                  currentPos.dy + details.delta.dy,
                );

                final clamped = _clampPosition(
                  next,
                  constraints,
                  safePadding,
                  cardSize,
                );

                setState(() {
                  _draggedPosition = clamped;
                });
                widget.onPositionChanged?.call(clamped);
              },
              onPanEnd: widget.onPanEnd,
              child: card,
            ),
          );
        }

        if (clampedPos != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: clampedPos.dx,
                top: clampedPos.dy,
                child: card,
              ),
            ],
          );
        }

        double? left;
        double? top;
        double? right;
        double? bottom;

        if (widget.initialAlignment == Alignment.topRight) {
          top = safePadding.top + widget.margin.top;
          right = safePadding.right + widget.margin.right;
        } else if (widget.initialAlignment == Alignment.topLeft) {
          top = safePadding.top + widget.margin.top;
          left = safePadding.left + widget.margin.left;
        } else if (widget.initialAlignment == Alignment.bottomRight) {
          bottom = safePadding.bottom + widget.margin.bottom;
          right = safePadding.right + widget.margin.right;
        } else if (widget.initialAlignment == Alignment.bottomLeft) {
          bottom = safePadding.bottom + widget.margin.bottom;
          left = safePadding.left + widget.margin.left;
        } else if (widget.initialAlignment == Alignment.bottomCenter) {
          bottom = safePadding.bottom + widget.margin.bottom;
          left = safePadding.left + widget.margin.left;
          right = safePadding.right + widget.margin.right;
          card = Align(alignment: Alignment.bottomCenter, child: card);
        } else if (widget.initialAlignment == Alignment.topCenter) {
          top = safePadding.top + widget.margin.top;
          left = safePadding.left + widget.margin.left;
          right = safePadding.right + widget.margin.right;
          card = Align(alignment: Alignment.topCenter, child: card);
        } else {
          top = safePadding.top + widget.margin.top;
          right = safePadding.right + widget.margin.right;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: left,
              top: top,
              right: right,
              bottom: bottom,
              child: card,
            ),
          ],
        );
      },
    );
  }
}
