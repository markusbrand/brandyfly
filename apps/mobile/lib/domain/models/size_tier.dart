/// Content density tier chosen from the rendered pixel size of a widget.
enum SizeTier { tiny, compact, regular }

/// Shortest side below which a widget renders its value only.
const double kTinyTierMaxExtent = 40.0;

/// Shortest side below which a widget renders value plus unit only.
const double kCompactTierMaxExtent = 80.0;

SizeTier sizeTierFor(double width, double height) {
  final shortest = width < height ? width : height;
  if (!shortest.isFinite) return SizeTier.regular;
  if (shortest < kTinyTierMaxExtent) return SizeTier.tiny;
  if (shortest < kCompactTierMaxExtent) return SizeTier.compact;
  return SizeTier.regular;
}
