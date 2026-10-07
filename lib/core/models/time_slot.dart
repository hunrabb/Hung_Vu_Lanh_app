/// Half-open UTC interval: adjacent appointments do not overlap.
class TimeSlot {
  TimeSlot({required DateTime start, required DateTime end})
    : start = start.toUtc(),
      end = end.toUtc() {
    if (!this.end.isAfter(this.start)) {
      throw ArgumentError('End must be after start.');
    }
  }

  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);
  bool overlaps(TimeSlot other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
}
