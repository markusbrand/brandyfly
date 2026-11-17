/// Readiness status of an individual required live flight sensor domain.
enum SensorDomainStatus {
  /// Valid, non-stale readings are actively arriving.
  availableReady,

  /// Required onboard sensor hardware is absent and no external source provides it.
  hardwareMissing,

  /// Onboard sensor exists, but OS permission has not been granted.
  permissionDenied,

  /// Onboard sensor exists and is permitted, but disabled in OS settings.
  disabled,

  /// Hardware/transport is available, awaiting initial valid readings.
  waitingForFix,

  /// External sensor transport (e.g. Bluetooth vario) is disconnected.
  disconnected,

  /// Previously active readings have exceeded the staleness threshold.
  stale;

  bool get isReady => this == SensorDomainStatus.availableReady;
}

/// Connection lifecycle state of an external Bluetooth vario transport.
enum ExternalVarioConnectionState {
  none,
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Snapshot of device hardware and OS permission capabilities for live sensors.
class SensorCapabilities {
  const SensorCapabilities({
    required this.hasBarometer,
    required this.hasGps,
    required this.locationEnabled,
    required this.locationPermissionGranted,
    this.bluetoothAvailable = false,
    this.isCapabilityKnown = true,
  });

  /// Safe fallback when platform capability probing is unavailable.
  static const SensorCapabilities unknown = SensorCapabilities(
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

  factory SensorCapabilities.fromMap(Map<String, Object?> map) {
    return SensorCapabilities(
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

  SensorCapabilities copyWith({
    bool? hasBarometer,
    bool? hasGps,
    bool? locationEnabled,
    bool? locationPermissionGranted,
    bool? bluetoothAvailable,
    bool? isCapabilityKnown,
  }) {
    return SensorCapabilities(
      hasBarometer: hasBarometer ?? this.hasBarometer,
      hasGps: hasGps ?? this.hasGps,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      locationPermissionGranted:
          locationPermissionGranted ?? this.locationPermissionGranted,
      bluetoothAvailable: bluetoothAvailable ?? this.bluetoothAvailable,
      isCapabilityKnown: isCapabilityKnown ?? this.isCapabilityKnown,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorCapabilities &&
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

/// Current live sample and transport state evaluated by [SensorReadinessEvaluator].
class LiveSensorInput {
  const LiveSensorInput({
    this.hasLiveSource = false,
    this.isExternalVarioSource = false,
    this.externalVarioState = ExternalVarioConnectionState.none,
    this.hasBaroSample = false,
    this.lastBaroSampleAt,
    this.hasGpsSample = false,
    this.lastGpsSampleAt,
    this.isSampleValid = false,
    this.isSampleStale = false,
    this.isMockFlightMode = false,
    this.isReplayActive = false,
  });

  final bool hasLiveSource;
  final bool isExternalVarioSource;
  final ExternalVarioConnectionState externalVarioState;
  final bool hasBaroSample;
  final DateTime? lastBaroSampleAt;
  final bool hasGpsSample;
  final DateTime? lastGpsSampleAt;
  final bool isSampleValid;
  final bool isSampleStale;
  final bool isMockFlightMode;
  final bool isReplayActive;

  /// Validates that coordinates represent a real GNSS fix rather than null/zero placeholders.
  static bool isValidGpsCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude < -90.0 || latitude > 90.0) return false;
    if (longitude < -180.0 || longitude > 180.0) return false;
    if (latitude == 0.0 && longitude == 0.0) return false;
    return true;
  }

  LiveSensorInput copyWith({
    bool? hasLiveSource,
    bool? isExternalVarioSource,
    ExternalVarioConnectionState? externalVarioState,
    bool? hasBaroSample,
    Object? lastBaroSampleAt = _sentinel,
    bool? hasGpsSample,
    Object? lastGpsSampleAt = _sentinel,
    bool? isSampleValid,
    bool? isSampleStale,
    bool? isMockFlightMode,
    bool? isReplayActive,
  }) {
    return LiveSensorInput(
      hasLiveSource: hasLiveSource ?? this.hasLiveSource,
      isExternalVarioSource:
          isExternalVarioSource ?? this.isExternalVarioSource,
      externalVarioState: externalVarioState ?? this.externalVarioState,
      hasBaroSample: hasBaroSample ?? this.hasBaroSample,
      lastBaroSampleAt: identical(lastBaroSampleAt, _sentinel)
          ? this.lastBaroSampleAt
          : lastBaroSampleAt as DateTime?,
      hasGpsSample: hasGpsSample ?? this.hasGpsSample,
      lastGpsSampleAt: identical(lastGpsSampleAt, _sentinel)
          ? this.lastGpsSampleAt
          : lastGpsSampleAt as DateTime?,
      isSampleValid: isSampleValid ?? this.isSampleValid,
      isSampleStale: isSampleStale ?? this.isSampleStale,
      isMockFlightMode: isMockFlightMode ?? this.isMockFlightMode,
      isReplayActive: isReplayActive ?? this.isReplayActive,
    );
  }

  static const Object _sentinel = Object();
}

/// Immutable sensor readiness evaluation consumed by the application shell.
class SensorReadinessState {
  const SensorReadinessState({
    required this.barometerStatus,
    required this.gpsStatus,
    this.isMockFlightMode = false,
    this.isReplayActive = false,
    this.externalVarioConnected = false,
  });

  final SensorDomainStatus barometerStatus;
  final SensorDomainStatus gpsStatus;
  final bool isMockFlightMode;
  final bool isReplayActive;
  final bool externalVarioConnected;

  bool get isReady => barometerStatus.isReady && gpsStatus.isReady;

  /// Suppress warning liner during intentional simulation or IGC replay.
  bool get shouldShowBanner =>
      !isMockFlightMode && !isReplayActive && !isReady;

  List<String> get missingDomains {
    final missing = <String>[];
    if (!barometerStatus.isReady) missing.add('Barometer');
    if (!gpsStatus.isReady) missing.add('GPS');
    return missing;
  }

  String get barometerSummary {
    switch (barometerStatus) {
      case SensorDomainStatus.availableReady:
        return 'Barometer ready';
      case SensorDomainStatus.hardwareMissing:
        return 'No barometer';
      case SensorDomainStatus.permissionDenied:
        return 'Barometer permission denied';
      case SensorDomainStatus.disabled:
        return 'Barometer disabled';
      case SensorDomainStatus.waitingForFix:
        return 'Waiting for barometer/vario';
      case SensorDomainStatus.disconnected:
        return 'Bluetooth vario disconnected';
      case SensorDomainStatus.stale:
        return 'Barometer signal stale';
    }
  }

  String get gpsSummary {
    switch (gpsStatus) {
      case SensorDomainStatus.availableReady:
        return 'GPS ready';
      case SensorDomainStatus.hardwareMissing:
        return 'GPS missing';
      case SensorDomainStatus.permissionDenied:
        return 'GPS permission required';
      case SensorDomainStatus.disabled:
        return 'GPS disabled';
      case SensorDomainStatus.waitingForFix:
        return 'Waiting for GPS fix';
      case SensorDomainStatus.disconnected:
        return 'External GPS disconnected';
      case SensorDomainStatus.stale:
        return 'GPS signal stale';
    }
  }

  /// Concise pilot-facing banner text identifying missing sensors and remediation.
  String get warningMessage {
    if (isReady) return 'All required flight sensors ready';
    final issues = <String>[];
    if (!barometerStatus.isReady) issues.add(barometerSummary);
    if (!gpsStatus.isReady) issues.add(gpsSummary);
    final issueText = issues.join(' · ');

    final needsExternalVarioHint =
        barometerStatus == SensorDomainStatus.hardwareMissing ||
            barometerStatus == SensorDomainStatus.disconnected ||
            barometerStatus == SensorDomainStatus.waitingForFix ||
            gpsStatus == SensorDomainStatus.hardwareMissing;

    if (needsExternalVarioHint) {
      return 'Insufficient sensors: $issueText — Connect a Bluetooth vario or enable device sensors';
    }
    return 'Insufficient sensors: $issueText — Enable device permissions/sensors';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorReadinessState &&
        other.barometerStatus == barometerStatus &&
        other.gpsStatus == gpsStatus &&
        other.isMockFlightMode == isMockFlightMode &&
        other.isReplayActive == isReplayActive &&
        other.externalVarioConnected == externalVarioConnected;
  }

  @override
  int get hashCode => Object.hash(
        barometerStatus,
        gpsStatus,
        isMockFlightMode,
        isReplayActive,
        externalVarioConnected,
      );
}

/// Pure-Dart readiness evaluator without Flutter widget dependencies.
class SensorReadinessEvaluator {
  const SensorReadinessEvaluator._();

  static const Duration defaultStalenessThreshold = Duration(seconds: 5);

  static SensorReadinessState evaluate({
    required SensorCapabilities capabilities,
    required LiveSensorInput input,
    required DateTime now,
    Duration stalenessThreshold = defaultStalenessThreshold,
  }) {
    final barometerStatus = _evaluateBarometer(
      capabilities: capabilities,
      input: input,
      now: now,
      stalenessThreshold: stalenessThreshold,
    );
    final gpsStatus = _evaluateGps(
      capabilities: capabilities,
      input: input,
      now: now,
      stalenessThreshold: stalenessThreshold,
    );

    return SensorReadinessState(
      barometerStatus: barometerStatus,
      gpsStatus: gpsStatus,
      isMockFlightMode: input.isMockFlightMode,
      isReplayActive: input.isReplayActive,
      externalVarioConnected:
          input.externalVarioState == ExternalVarioConnectionState.connected,
    );
  }

  static SensorDomainStatus _evaluateBarometer({
    required SensorCapabilities capabilities,
    required LiveSensorInput input,
    required DateTime now,
    required Duration stalenessThreshold,
  }) {
    final lastBaro = input.lastBaroSampleAt;
    final baroTimedOut =
        lastBaro != null && now.difference(lastBaro) > stalenessThreshold;

    final baroFresh = input.hasLiveSource &&
        input.hasBaroSample &&
        input.isSampleValid &&
        !input.isSampleStale &&
        lastBaro != null &&
        !baroTimedOut;

    if (baroFresh) {
      return SensorDomainStatus.availableReady;
    }

    if (_isExternalDisconnected(input.externalVarioState) &&
        (input.isExternalVarioSource || !capabilities.hasBarometer)) {
      return SensorDomainStatus.disconnected;
    }

    if (baroTimedOut || (input.isSampleStale && input.hasBaroSample)) {
      return SensorDomainStatus.stale;
    }

    if (!capabilities.hasBarometer) {
      return SensorDomainStatus.hardwareMissing;
    }

    return SensorDomainStatus.waitingForFix;
  }

  static SensorDomainStatus _evaluateGps({
    required SensorCapabilities capabilities,
    required LiveSensorInput input,
    required DateTime now,
    required Duration stalenessThreshold,
  }) {
    final lastGps = input.lastGpsSampleAt;
    final gpsTimedOut =
        lastGps != null && now.difference(lastGps) > stalenessThreshold;

    final gpsFresh = input.hasLiveSource &&
        input.hasGpsSample &&
        input.isSampleValid &&
        !input.isSampleStale &&
        lastGps != null &&
        !gpsTimedOut;

    if (gpsFresh) {
      return SensorDomainStatus.availableReady;
    }

    if (gpsTimedOut || (input.isSampleStale && input.hasGpsSample)) {
      return SensorDomainStatus.stale;
    }

    if (_isExternalDisconnected(input.externalVarioState) &&
        input.isExternalVarioSource &&
        !capabilities.hasGps) {
      return SensorDomainStatus.disconnected;
    }

    if (!capabilities.hasGps) {
      return SensorDomainStatus.hardwareMissing;
    }

    if (!capabilities.locationPermissionGranted) {
      return SensorDomainStatus.permissionDenied;
    }

    if (!capabilities.locationEnabled) {
      return SensorDomainStatus.disabled;
    }

    return SensorDomainStatus.waitingForFix;
  }

  static bool _isExternalDisconnected(ExternalVarioConnectionState state) {
    return state == ExternalVarioConnectionState.disconnected ||
        state == ExternalVarioConnectionState.reconnecting ||
        state == ExternalVarioConnectionState.error;
  }
}
