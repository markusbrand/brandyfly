import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:benchmark_map/fixture_loader.dart';

void main() {
  group('FixtureLoader — validation rules', () {
    test('validatePmtilesBytes throws on empty bytes (stub file)', () {
      expect(
        () => FixtureLoader.validatePmtilesBytes(Uint8List(0), 'alpine_overview'),
        throwsA(
          isA<FixtureValidationException>().having(
            (e) => e.message,
            'message',
            contains('zero-byte stub'),
          ),
        ),
      );
    });

    test('validatePmtilesBytes throws on corrupt magic bytes', () {
      final corrupt = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]);
      expect(
        () => FixtureLoader.validatePmtilesBytes(corrupt, 'alpine_overview'),
        throwsA(
          isA<FixtureValidationException>().having(
            (e) => e.message,
            'message',
            contains('magic bytes'),
          ),
        ),
      );
    });

    test('validatePmtilesBytes accepts valid PMTiles magic bytes', () {
      // PMTiles magic: "PMTiles" = 0x50 0x4D 0x54 0x69 0x6C 0x65 0x73
      final magic = Uint8List.fromList([
        0x50, 0x4D, 0x54, 0x69, 0x6C, 0x65, 0x73,
        // followed by mock header data
        0x00, 0x01, 0x02, 0x03,
      ]);
      expect(
        () => FixtureLoader.validatePmtilesBytes(magic, 'alpine_overview'),
        returnsNormally,
      );
    });

    test('computeChecksum returns stable SHA-256 hex string', () {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final checksum = FixtureLoader.computeChecksum(data);
      // Known SHA-256 of 'hello world'
      expect(
        checksum,
        'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
      );
    });

    test('computeChecksum is deterministic', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final cs1 = FixtureLoader.computeChecksum(data);
      final cs2 = FixtureLoader.computeChecksum(data);
      expect(cs1, cs2);
    });

    test('computeChecksum differs for different data', () {
      final a = FixtureLoader.computeChecksum(Uint8List.fromList([1]));
      final b = FixtureLoader.computeChecksum(Uint8List.fromList([2]));
      expect(a, isNot(b));
    });

    test('validatePmtilesBytes accepts bytes smaller than 7 if non-empty', () {
      // Files under 7 bytes skip magic check (too small for full magic sequence).
      // They are treated as non-empty — if truly invalid, the map engine will surface the error.
      final small = Uint8List.fromList([0x50, 0x4D]);
      expect(
        () => FixtureLoader.validatePmtilesBytes(small, 'alpine_overview'),
        returnsNormally,
      );
    });
  });
}
