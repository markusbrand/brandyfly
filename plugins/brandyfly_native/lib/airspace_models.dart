import 'dart:ffi' as ffi;
import 'package:flutter/foundation.dart';

/// Representation of an airspace proximity evaluation input.
@immutable
class NativeAirspaceEvaluationInput {
  const NativeAirspaceEvaluationInput({
    required this.latitude,
    required this.longitude,
    required this.altitudeMsl,
    required this.groundspeedMps,
    required this.trackHeadingDeg,
    required this.glideRatio,
    required this.qnhHpa,
    required this.terrainElevationMsl,
    required this.timestampMs,
  });

  final double latitude;
  final double longitude;
  final double altitudeMsl;
  final double groundspeedMps;
  final double trackHeadingDeg;
  final double glideRatio;
  final double qnhHpa;
  final double terrainElevationMsl;
  final int timestampMs;

  Map<String, Object?> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitudeMsl': altitudeMsl,
        'groundspeedMps': groundspeedMps,
        'trackHeadingDeg': trackHeadingDeg,
        'glideRatio': glideRatio,
        'qnhHpa': qnhHpa,
        'terrainElevationMsl': terrainElevationMsl,
        'timestampMs': timestampMs,
      };

  factory NativeAirspaceEvaluationInput.fromMap(Map<String, Object?> map) {
    return NativeAirspaceEvaluationInput(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      altitudeMsl: (map['altitudeMsl'] as num?)?.toDouble() ?? 0.0,
      groundspeedMps: (map['groundspeedMps'] as num?)?.toDouble() ?? 0.0,
      trackHeadingDeg: (map['trackHeadingDeg'] as num?)?.toDouble() ?? 0.0,
      glideRatio: (map['glideRatio'] as num?)?.toDouble() ?? 8.0,
      qnhHpa: (map['qnhHpa'] as num?)?.toDouble() ?? 1013.25,
      terrainElevationMsl:
          (map['terrainElevationMsl'] as num?)?.toDouble() ?? 0.0,
      timestampMs: (map['timestampMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Representation of an airspace proximity evaluation output.
@immutable
class NativeAirspaceEvaluationOutput {
  const NativeAirspaceEvaluationOutput({
    required this.alertLevel,
    required this.horizontalSeparationM,
    required this.verticalSeparationM,
    required this.total3dDistanceM,
    required this.isInsideHorizontal,
    required this.isInsideVertical,
    required this.floorMslM,
    required this.ceilingMslM,
    required this.forwardIntersectionDistanceM,
    required this.forwardIntersectionTimeS,
    required this.willPenetrateGlideSlope,
  });

  /// 0 = Clear/None, 1 = Advisory, 2 = Warning, 3 = Violation
  final int alertLevel;
  final double horizontalSeparationM;
  final double verticalSeparationM;
  final double total3dDistanceM;
  final bool isInsideHorizontal;
  final bool isInsideVertical;
  final double floorMslM;
  final double ceilingMslM;
  final double forwardIntersectionDistanceM;
  final double forwardIntersectionTimeS;
  final bool willPenetrateGlideSlope;

  static const NativeAirspaceEvaluationOutput clear =
      NativeAirspaceEvaluationOutput(
    alertLevel: 0,
    horizontalSeparationM: double.infinity,
    verticalSeparationM: double.infinity,
    total3dDistanceM: double.infinity,
    isInsideHorizontal: false,
    isInsideVertical: false,
    floorMslM: 0.0,
    ceilingMslM: 0.0,
    forwardIntersectionDistanceM: -1.0,
    forwardIntersectionTimeS: -1.0,
    willPenetrateGlideSlope: false,
  );

  Map<String, Object?> toMap() => {
        'alertLevel': alertLevel,
        'horizontalSeparationM': horizontalSeparationM,
        'verticalSeparationM': verticalSeparationM,
        'total3dDistanceM': total3dDistanceM,
        'isInsideHorizontal': isInsideHorizontal,
        'isInsideVertical': isInsideVertical,
        'floorMslM': floorMslM,
        'ceilingMslM': ceilingMslM,
        'forwardIntersectionDistanceM': forwardIntersectionDistanceM,
        'forwardIntersectionTimeS': forwardIntersectionTimeS,
        'willPenetrateGlideSlope': willPenetrateGlideSlope,
      };

  factory NativeAirspaceEvaluationOutput.fromMap(Map<String, Object?> map) {
    return NativeAirspaceEvaluationOutput(
      alertLevel: (map['alertLevel'] as num?)?.toInt() ?? 0,
      horizontalSeparationM:
          (map['horizontalSeparationM'] as num?)?.toDouble() ?? double.infinity,
      verticalSeparationM:
          (map['verticalSeparationM'] as num?)?.toDouble() ?? double.infinity,
      total3dDistanceM:
          (map['total3dDistanceM'] as num?)?.toDouble() ?? double.infinity,
      isInsideHorizontal: map['isInsideHorizontal'] == true ||
          map['isInsideHorizontal'] == 1,
      isInsideVertical:
          map['isInsideVertical'] == true || map['isInsideVertical'] == 1,
      floorMslM: (map['floorMslM'] as num?)?.toDouble() ?? 0.0,
      ceilingMslM: (map['ceilingMslM'] as num?)?.toDouble() ?? 0.0,
      forwardIntersectionDistanceM:
          (map['forwardIntersectionDistanceM'] as num?)?.toDouble() ?? -1.0,
      forwardIntersectionTimeS:
          (map['forwardIntersectionTimeS'] as num?)?.toDouble() ?? -1.0,
      willPenetrateGlideSlope: map['willPenetrateGlideSlope'] == true ||
          map['willPenetrateGlideSlope'] == 1,
    );
  }
}

/// C-ABI struct matching `flight_core::airspace::ffi::AirspaceEvaluationInput`.
final class CAirspaceEvaluationInput extends ffi.Struct {
  @ffi.Double()
  external double latitude;

  @ffi.Double()
  external double longitude;

  @ffi.Double()
  external double altitudeMsl;

  @ffi.Double()
  external double groundspeedMps;

  @ffi.Double()
  external double trackHeadingDeg;

  @ffi.Double()
  external double glideRatio;

  @ffi.Double()
  external double qnhHpa;

  @ffi.Double()
  external double terrainElevationMsl;

  @ffi.Uint64()
  external int timestampMs;
}

/// C-ABI struct matching `flight_core::airspace::ffi::AirspaceEvaluationOutput`.
final class CAirspaceEvaluationOutput extends ffi.Struct {
  @ffi.Uint8()
  external int alertLevel;

  @ffi.Double()
  external double horizontalSeparationM;

  @ffi.Double()
  external double verticalSeparationM;

  @ffi.Double()
  external double total3dDistanceM;

  @ffi.Uint8()
  external int isInsideHorizontal;

  @ffi.Uint8()
  external int isInsideVertical;

  @ffi.Double()
  external double floorMslM;

  @ffi.Double()
  external double ceilingMslM;

  @ffi.Double()
  external double forwardIntersectionDistanceM;

  @ffi.Double()
  external double forwardIntersectionTimeS;

  @ffi.Uint8()
  external int willPenetrateGlideSlope;
}
