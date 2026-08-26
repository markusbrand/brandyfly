import 'dart:math' as math;
import '../models/flight_model.dart';

class IGCParserService {
  const IGCParserService();

  FlightModel parseIgc(String content, {String? id, String? defaultTitle}) {
    final lines = content.split(RegExp(r'\r?\n'));
    DateTime? flightDate;
    String pilotName = 'Markus Brandstätter';
    String gliderType = 'Paraglider';
    String siteName = '';
    final List<FlightPoint> points = [];

    // Check for I-record definitions
    // e.g. I053638FXA3941VXA4244GSP4547CCO4850HDT
    // Format: I, then 2-digit count of extensions, then for each: startByte (2 digits), endByte (2 digits), 3-char code
    final Map<String, ({int start, int end})> extensions = {};

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('HFDTE') || line.startsWith('HFDTEDATE:')) {
        // HFDTE150826 or HFDTEDATE:150826,01
        final dateStr = line.replaceAll(RegExp(r'^HFDTEDATE:|^HFDTE'), '').trim();
        if (dateStr.length >= 6) {
          final day = int.tryParse(dateStr.substring(0, 2)) ?? 1;
          final month = int.tryParse(dateStr.substring(2, 4)) ?? 1;
          var year = int.tryParse(dateStr.substring(4, 6)) ?? 26;
          year += (year < 70) ? 2000 : 1900;
          flightDate = DateTime.utc(year, month, day);
        }
      } else if (line.startsWith('HFPLTPILOT:') || line.startsWith('HFPLTPILOTINCHARGE:')) {
        final parts = line.split(':');
        if (parts.length > 1) pilotName = parts.sublist(1).join(':').trim();
      } else if (line.startsWith('HFGTYGLIDERTYPE:')) {
        final parts = line.split(':');
        if (parts.length > 1) gliderType = parts.sublist(1).join(':').trim();
      } else if (line.startsWith('HFSITSITE:')) {
        final parts = line.split(':');
        if (parts.length > 1) siteName = parts.sublist(1).join(':').trim();
      } else if (line.startsWith('I')) {
        _parseIRecord(line, extensions);
      } else if (line.startsWith('B') && line.length >= 35) {
        final pt = _parseBRecord(line, flightDate ?? DateTime.now(), extensions, points.lastOrNull);
        if (pt != null) {
          points.add(pt);
        }
      }
    }

    final effectiveDate = points.isNotEmpty
        ? points.first.timestamp
        : (flightDate ?? DateTime.now());

    final calculatedStats = computeStatistics(points);
    final flightId = id ?? 'flight_${effectiveDate.millisecondsSinceEpoch}';
    final autoTitle = defaultTitle ?? (siteName.isNotEmpty ? siteName : 'Flight ${effectiveDate.toIso8601String().substring(0, 10)}');

    return FlightModel(
      id: flightId,
      title: autoTitle,
      date: effectiveDate,
      pilotName: pilotName,
      gliderType: gliderType,
      siteName: siteName,
      points: points,
      statistics: calculatedStats,
      rawIgcContent: content,
      category: FlightCategory.myFlights,
      uploadStatus: UploadStatus.notUploaded,
    );
  }

  void _parseIRecord(String line, Map<String, ({int start, int end})> extensions) {
    if (line.length < 3) return;
    final numExt = int.tryParse(line.substring(1, 3)) ?? 0;
    var idx = 3;
    for (var i = 0; i < numExt; i++) {
      if (idx + 7 > line.length) break;
      final start = int.tryParse(line.substring(idx, idx + 2));
      final end = int.tryParse(line.substring(idx + 2, idx + 4));
      final code = line.substring(idx + 4, idx + 7);
      if (start != null && end != null) {
        extensions[code] = (start: start, end: end);
      }
      idx += 7;
    }
  }

  FlightPoint? _parseBRecord(
    String line,
    DateTime baseDate,
    Map<String, ({int start, int end})> extensions,
    FlightPoint? previousPoint,
  ) {
    final detailed = parseDetailedBRecord(line, baseDate, extensions, previousPoint);
    return detailed?.toFlightPoint();
  }

  /// Parses a raw B-record into a structured [ParsedIGCBRecord] with validity and altitude fields.
  ParsedIGCBRecord? parseDetailedBRecord(
    String line,
    DateTime baseDate, [
    Map<String, ({int start, int end})>? extensions,
    FlightPoint? previousPoint,
  ]) {
    // Format:
    // B (1)
    // HHMMSS (2..7)
    // DDMMmmmN (8..15)
    // DDDMMmmmE (16..24)
    // V (25) -> A (valid) or V (void/warning)
    // PPPPP (26..30) -> Pressure Altitude
    // GGGGG (31..35) -> GNSS Altitude
    if (line.length < 35 || !line.startsWith('B')) return null;

    try {
      final hh = int.tryParse(line.substring(1, 3));
      final mm = int.tryParse(line.substring(3, 5));
      final ss = int.tryParse(line.substring(5, 7));
      if (hh == null || mm == null || ss == null || hh > 23 || mm > 59 || ss > 59) {
        return null;
      }

      final timestamp = DateTime.utc(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hh,
        mm,
        ss,
      );

      final latDeg = double.tryParse(line.substring(7, 9));
      final latMin = (double.tryParse(line.substring(9, 14)) ?? 0.0) / 1000.0;
      final latHemi = line.substring(14, 15).toUpperCase();
      if (latDeg == null || (latHemi != 'N' && latHemi != 'S')) return null;
      var latitude = latDeg + (latMin / 60.0);
      if (latHemi == 'S') latitude = -latitude;

      final lonDeg = double.tryParse(line.substring(15, 18));
      final lonMin = (double.tryParse(line.substring(18, 23)) ?? 0.0) / 1000.0;
      final lonHemi = line.substring(23, 24).toUpperCase();
      if (lonDeg == null || (lonHemi != 'E' && lonHemi != 'W')) return null;
      var longitude = lonDeg + (lonMin / 60.0);
      if (lonHemi == 'W') longitude = -longitude;

      final validityChar = line.substring(24, 25).toUpperCase();
      final isValidFix = validityChar == 'A';

      final pressAlt = double.tryParse(line.substring(25, 30)) ?? 0.0;
      final gnssAlt = double.tryParse(line.substring(30, 35)) ?? pressAlt;

      double vario = 0.0;
      double speed = 0.0;
      double heading = 0.0;

      final extMap = extensions ?? const {};

      // Extract IGC extensions if present
      if (extMap.containsKey('VXA')) {
        final ext = extMap['VXA']!;
        if (line.length >= ext.end) {
          final rawV = int.tryParse(line.substring(ext.start - 1, ext.end));
          if (rawV != null) {
            // VXA in cm/s or dm/s
            vario = (rawV > 500 ? rawV - 1000 : rawV) / 10.0;
          }
        }
      }
      if (extMap.containsKey('GSP')) {
        final ext = extMap['GSP']!;
        if (line.length >= ext.end) {
          final rawS = double.tryParse(line.substring(ext.start - 1, ext.end));
          if (rawS != null) speed = rawS; // km/h
        }
      }
      if (extMap.containsKey('HDT')) {
        final ext = extMap['HDT']!;
        if (line.length >= ext.end) {
          final rawH = double.tryParse(line.substring(ext.start - 1, ext.end));
          if (rawH != null) heading = rawH;
        }
      }

      // If vario, speed or heading not in extensions, compute dynamically
      if (previousPoint != null) {
        final dtSec = timestamp.difference(previousPoint.timestamp).inMilliseconds / 1000.0;
        if (dtSec > 0) {
          if (vario == 0.0) {
            vario = (pressAlt - previousPoint.altitude) / dtSec;
          }
          if (speed == 0.0) {
            final distKm = calculateDistanceKm(
              previousPoint.latitude,
              previousPoint.longitude,
              latitude,
              longitude,
            );
            speed = (distKm / (dtSec / 3600.0));
          }
          if (heading == 0.0) {
            heading = calculateBearing(
              previousPoint.latitude,
              previousPoint.longitude,
              latitude,
              longitude,
            );
          }
        }
      }

      return ParsedIGCBRecord(
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
        pressureAltitude: pressAlt,
        gnssAltitude: gnssAlt,
        isValidFix: isValidFix,
        validityChar: validityChar,
        vario: double.parse(vario.toStringAsFixed(2)),
        speed: double.parse(speed.toStringAsFixed(1)),
        heading: double.parse(heading.toStringAsFixed(1)),
      );
    } catch (_) {
      return null;
    }
  }

  String generateIgc(FlightModel flight) {
    final buffer = StringBuffer();
    final d = flight.date;
    final dateFormatted = '${d.day.toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}${(d.year % 100).toString().padLeft(2, '0')}';

    buffer.writeln('AXFH001');
    buffer.writeln('HFDTE$dateFormatted');
    buffer.writeln('HFPLTPILOT:${flight.pilotName}');
    buffer.writeln('HFGTYGLIDERTYPE:${flight.gliderType}');
    buffer.writeln('HFDTM100GPSDATUM:WGS84');
    buffer.writeln('HFFTYFRTYPE:BrandyFly,1.0');
    buffer.writeln('HFGPS:Internal');
    buffer.writeln('HFPRSVARIO:BrandyFly Sensor Engine');
    buffer.writeln('HFCCLCOMPETITIONCLASS:Paraglider');
    if (flight.siteName.isNotEmpty) {
      buffer.writeln('HFSITSITE:${flight.siteName}');
    }

    // Include extension descriptor: FXA (36-38), VXA (39-41), GSP (42-44), HDT (45-47)
    buffer.writeln('I043638FXA3941VXA4244GSP4547HDT');

    for (final pt in flight.points) {
      final t = pt.timestamp.toUtc();
      final timeStr = '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}${t.second.toString().padLeft(2, '0')}';

      // Format latitude DDMMmmmN
      final latHemi = pt.latitude >= 0 ? 'N' : 'S';
      final absLat = pt.latitude.abs();
      final latDeg = absLat.floor();
      final latMin = (absLat - latDeg) * 60.0;
      final latMinThousandths = (latMin * 1000).round().clamp(0, 59999);
      final latStr = '${latDeg.toString().padLeft(2, '0')}${latMinThousandths.toString().padLeft(5, '0')}$latHemi';

      // Format longitude DDDMMmmmE
      final lonHemi = pt.longitude >= 0 ? 'E' : 'W';
      final absLon = pt.longitude.abs();
      final lonDeg = absLon.floor();
      final lonMin = (absLon - lonDeg) * 60.0;
      final lonMinThousandths = (lonMin * 1000).round().clamp(0, 59999);
      final lonStr = '${lonDeg.toString().padLeft(3, '0')}${lonMinThousandths.toString().padLeft(5, '0')}$lonHemi';

      final pressAlt = pt.altitude.round().clamp(-1000, 99999).toString().padLeft(5, '0');
      final gnssAlt = (pt.gnssAltitude ?? pt.altitude).round().clamp(-1000, 99999).toString().padLeft(5, '0');

      final fxa = '000';
      final vxaRaw = (pt.vario * 10).round();
      final vxa = (vxaRaw >= 0 ? vxaRaw : 1000 + vxaRaw).toString().padLeft(3, '0');
      final gsp = pt.speed.round().clamp(0, 999).toString().padLeft(3, '0');
      final hdt = pt.heading.round().clamp(0, 359).toString().padLeft(3, '0');

      buffer.writeln('B$timeStr$latStr$lonStr' 'A$pressAlt$gnssAlt$fxa$vxa$gsp$hdt');
    }

    buffer.writeln('G00000000000000000000000000000000');
    return buffer.toString();
  }

  static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final y = math.sin((lon2 - lon1) * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0);
    final x = math.cos(lat1 * math.pi / 180.0) * math.sin(lat2 * math.pi / 180.0) -
        math.sin(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) * math.cos((lon2 - lon1) * math.pi / 180.0);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    return (brng + 360.0) % 360.0;
  }

  static FlightStatistics computeStatistics(List<FlightPoint> points) {
    if (points.isEmpty) return FlightStatistics.empty();

    var maxAlt = points.first.altitude;
    var minAlt = points.first.altitude;
    var maxClimb = points.first.vario;
    var maxSink = points.first.vario;
    var totalDist = 0.0;
    var totalSpeed = 0.0;

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.altitude > maxAlt) maxAlt = p.altitude;
      if (p.altitude < minAlt) minAlt = p.altitude;
      if (p.vario > maxClimb) maxClimb = p.vario;
      if (p.vario < maxSink) maxSink = p.vario;
      totalSpeed += p.speed;

      if (i > 0) {
        final prev = points[i - 1];
        totalDist += calculateDistanceKm(prev.latitude, prev.longitude, p.latitude, p.longitude);
      }
    }

    final duration = points.length > 1
        ? points.last.timestamp.difference(points.first.timestamp)
        : Duration.zero;

    final avgSpeed = points.isNotEmpty ? (totalSpeed / points.length) : 0.0;

    // Glide ratio = distance (m) / altitude lost (m)
    final altDiff = (points.first.altitude - points.last.altitude);
    final avgGlide = (altDiff > 5.0 && totalDist > 0.05)
        ? ((totalDist * 1000.0) / altDiff)
        : 8.0;

    return FlightStatistics(
      duration: duration,
      maxAltitude: double.parse(maxAlt.toStringAsFixed(1)),
      minAltitude: double.parse(minAlt.toStringAsFixed(1)),
      maxClimbRate: double.parse(maxClimb.toStringAsFixed(2)),
      maxSinkRate: double.parse(maxSink.toStringAsFixed(2)),
      totalDistanceKm: double.parse(totalDist.toStringAsFixed(2)),
      averageSpeedKmh: double.parse(avgSpeed.toStringAsFixed(1)),
      averageGlideRatio: double.parse(avgGlide.clamp(0.0, 30.0).toStringAsFixed(1)),
    );
  }
}

/// Detailed representation of a parsed IGC B-record with full fix validity and altitude channels.
class ParsedIGCBRecord {
  const ParsedIGCBRecord({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.pressureAltitude,
    required this.gnssAltitude,
    required this.isValidFix,
    required this.validityChar,
    required this.vario,
    required this.speed,
    required this.heading,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double pressureAltitude;
  final double gnssAltitude;
  final bool isValidFix;
  final String validityChar;
  final double vario;
  final double speed;
  final double heading;

  FlightPoint toFlightPoint() {
    return FlightPoint(
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      altitude: pressureAltitude,
      gnssAltitude: gnssAltitude,
      vario: vario,
      speed: speed,
      heading: heading,
    );
  }
}
