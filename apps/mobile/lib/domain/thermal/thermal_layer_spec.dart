import 'thermal_variant.dart';

/// Desired state of the KK7 thermal heatmap layer on one map.
class ThermalLayerSpec {
  const ThermalLayerSpec({required this.variant, required this.opacity});

  final ThermalVariant variant;

  /// Layer opacity 0.1-1.0.
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is ThermalLayerSpec &&
      other.variant == variant &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(variant, opacity);

  @override
  String toString() => 'ThermalLayerSpec(${variant.key}, $opacity)';
}
