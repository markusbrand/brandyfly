/// Geometry of the virtual flight canvas grid.
///
/// The canvas is always divided into [columns] x [rows] cells whose pixel size
/// is derived from the canvas size, so a layout always fits without scrolling.
class GridSpec {
  const GridSpec._();

  static const int columns = 16;
  static const int rows = 32;

  /// Persisted schema version of the UI configuration.
  ///  1 = legacy 4-column grid, 2 = 8-column grid, 3 = 16x32 grid + variants.
  static const int schemaVersion = 3;

  /// Minimum interactive touch target in logical pixels.
  static const double minTouchTargetDp = 48.0;

  /// Number of cells needed so that [cellExtent] * n >= [minTouchTargetDp].
  static int cellsForTouchTarget(double cellExtent) {
    if (!cellExtent.isFinite || cellExtent <= 0) return 1;
    // Small epsilon avoids 47.9999 rounding artifacts.
    return ((minTouchTargetDp - 1e-6) / cellExtent).ceil().clamp(1, rows);
  }
}

/// Shape of the canvas used to pick the layout variant.
enum CanvasShape { tall, wide }

/// Classifies a canvas by its available space (not device orientation).
CanvasShape canvasShapeFor(double width, double height) =>
    width > height ? CanvasShape.wide : CanvasShape.tall;

/// Size of one grid cell in logical pixels.
class CellGeometry {
  const CellGeometry(this.cellWidth, this.cellHeight);

  final double cellWidth;
  final double cellHeight;

  static const CellGeometry unknown = CellGeometry(0, 0);

  bool get isKnown =>
      cellWidth.isFinite && cellHeight.isFinite && cellWidth > 0 && cellHeight > 0;

  int get touchCellsW => GridSpec.cellsForTouchTarget(cellWidth);
  int get touchCellsH => GridSpec.cellsForTouchTarget(cellHeight);

  @override
  bool operator ==(Object other) =>
      other is CellGeometry &&
      other.cellWidth == cellWidth &&
      other.cellHeight == cellHeight;

  @override
  int get hashCode => Object.hash(cellWidth, cellHeight);
}
