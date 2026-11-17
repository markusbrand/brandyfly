/// Typed snapshot of native sensor hardware and OS permission capabilities.
class NativeSensorCapabilities {
  const NativeSensorCapabilities({
    required this.hasBarometer,
    required this.hasGps,
    required this.locationEnabled,
    required this.locationPermissionGranted,
    this.bluetoothAvailable = false,
    this.isCapabilityKnown = true,
  });

  /// Returned when the host platform does not implement native capability probing.
  static const NativeSensorCapabilities unknown = NativeSensorCapabilities(
    hasBarometer: false,
    hasGps: false,
    locationEnabled: false,
    locationPermissionGranted: false,
    bluetoothAvailable: false,
    isCapabilityKnown: false,
  );

  final bool hasBarometer;
  final bool hasGps;
  final bool locationEnabled;
  final bool locationPermissionGranted;
  final bool bluetoothAvailable;
  final bool isCapabilityKnown;

  factory NativeSensorCapabilities.fromMap(Map<Object?, Object?> map) {
    return NativeSensorCapabilities(
      hasBarometer: map['hasBarometer'] as bool? ?? false,
      hasGps: map['hasGps'] as bool? ?? false,
      locationEnabled: map['locationEnabled'] as bool? ?? false,
      locationPermissionGranted:
          map['locationPermissionGranted'] as bool? ?? false,
      bluetoothAvailable: map['bluetoothAvailable'] as bool? ?? false,
      isCapabilityKnown: map['isCapabilityKnown'] as bool? ?? true,
    );
  }

  Map<String, Object?> toMap() => {
        'hasBarometer': hasBarometer,
        'hasGps': hasGps,
        'locationEnabled': locationEnabled,
        'locationPermissionGranted': locationPermissionGranted,
        'bluetoothAvailable': bluetoothAvailable,
        'isCapabilityKnown': isCapabilityKnown,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NativeSensorCapabilities &&
        other.hasBarometer == hasBarometer &&
        other.hasGps == hasGps &&
        other.locationEnabled == locationEnabled &&
        other.locationPermissionGranted == locationPermissionGranted &&
        other.bluetoothAvailable == bluetoothAvailable &&
        other.isCapabilityKnown == isCapabilityKnown;
  }

  @override
  int get hashCode => Object.hash(
        hasBarometer,
        hasGps,
        locationEnabled,
        locationPermissionGranted,
        bluetoothAvailable,
        isCapabilityKnown,
      );
}
