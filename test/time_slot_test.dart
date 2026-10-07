import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/models/time_slot.dart';

void main() {
  TimeSlot slot(int start, int end) => TimeSlot(
    start: DateTime.utc(2026, 10, 5, start),
    end: DateTime.utc(2026, 10, 5, end),
  );
  test('Overlap includes containment but excludes touching boundaries', () {
    expect(slot(9, 11).overlaps(slot(10, 12)), isTrue);
    expect(slot(9, 12).overlaps(slot(10, 11)), isTrue);
    expect(slot(9, 10).overlaps(slot(10, 11)), isFalse);
    expect(slot(9, 10).overlaps(slot(11, 12)), isFalse);
  });
  test('Rejects empty and reversed intervals', () {
    expect(() => slot(9, 9), throwsArgumentError);
    expect(() => slot(10, 9), throwsArgumentError);
  });
}
