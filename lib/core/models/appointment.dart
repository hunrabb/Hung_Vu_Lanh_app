import 'time_slot.dart';

const _unsetRating = Object();

enum AppointmentStatus { pending, confirmed, completed, cancelled, noShow }

class Appointment {
  Appointment({
    required this.id,
    required this.branchId,
    required this.customerId,
    required this.staffId,
    required List<String> serviceIds,
    required List<String> serviceNamesSnapshot,
    required DateTime startAt,
    required DateTime endAt,
    required this.totalPriceVnd,
    this.status = AppointmentStatus.pending,
    this.isHiddenByCustomer = false,
    this.isHiddenByStaff = false,
    this.customerName = '',
    bool? isReviewed = false,
    this.rating,
  }) : _isReviewed = isReviewed ?? false,
       serviceIds = List.unmodifiable(serviceIds),
       serviceNamesSnapshot = List.unmodifiable(serviceNamesSnapshot),
       slot = TimeSlot(start: startAt, end: endAt) {
    if ((rating != null && (rating! < 1 || rating! > 5)) ||
        (this.isReviewed && rating == null)) {
      throw ArgumentError(
        'Reviewed appointments require a rating from 1 to 5.',
      );
    }
    if (branchId.trim().isEmpty ||
        serviceIds.isEmpty ||
        serviceIds.length != serviceNamesSnapshot.length ||
        totalPriceVnd < 0) {
      throw ArgumentError(
        'Services need matching name snapshots and a valid price.',
      );
    }
  }

  final String id, customerId, staffId;
  final String branchId;
  final List<String> serviceIds, serviceNamesSnapshot;
  final TimeSlot slot;
  DateTime get startAt => slot.start;
  DateTime get endAt => slot.end;
  final int totalPriceVnd;
  final AppointmentStatus status;
  final bool isHiddenByCustomer;
  final bool isHiddenByStaff;
  // Existing RAM instances may lack newly added fields after hot reload.
  final bool? _isReviewed;
  bool get isReviewed => _isReviewed ?? false;
  final int? rating;

  /// Walk-in name/contact snapshot; no customer account is required.
  final String customerName;

  // Completed appointments also retain their occupied interval in history.
  bool get blocksTime =>
      status != AppointmentStatus.cancelled &&
      status != AppointmentStatus.noShow;

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] as String,
    branchId: json['branchId'] as String,
    customerId: json['customerId'] as String,
    staffId: json['staffId'] as String,
    serviceIds: List<String>.from(json['serviceIds'] as List),
    serviceNamesSnapshot: List<String>.from(
      json['serviceNamesSnapshot'] as List,
    ),
    startAt: DateTime.parse(json['startAt'] as String),
    endAt: DateTime.parse(json['endAt'] as String),
    totalPriceVnd: json['totalPriceVnd'] as int,
    status: AppointmentStatus.values.byName(json['status'] as String),
    isHiddenByCustomer: json['isHiddenByCustomer'] as bool? ?? false,
    isHiddenByStaff: json['isHiddenByStaff'] as bool? ?? false,
    customerName: json['customerName'] as String? ?? '',
    isReviewed: json['isReviewed'] as bool? ?? false,
    rating: json['rating'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'customerId': customerId,
    'staffId': staffId,
    'serviceIds': serviceIds.toList(),
    'serviceNamesSnapshot': serviceNamesSnapshot.toList(),
    'startAt': startAt.toIso8601String(),
    'endAt': endAt.toIso8601String(),
    'totalPriceVnd': totalPriceVnd,
    'status': status.name,
    'isHiddenByCustomer': isHiddenByCustomer,
    'isHiddenByStaff': isHiddenByStaff,
    'customerName': customerName,
    'isReviewed': isReviewed,
    'rating': rating,
  };

  Appointment copyWith({
    String? id,
    String? branchId,
    String? customerId,
    String? staffId,
    List<String>? serviceIds,
    List<String>? serviceNamesSnapshot,
    DateTime? startAt,
    DateTime? endAt,
    int? totalPriceVnd,
    AppointmentStatus? status,
    bool? isHiddenByCustomer,
    bool? isHiddenByStaff,
    String? customerName,
    bool? isReviewed,
    Object? rating = _unsetRating,
  }) => Appointment(
    id: id ?? this.id,
    branchId: branchId ?? this.branchId,
    customerId: customerId ?? this.customerId,
    staffId: staffId ?? this.staffId,
    serviceIds: serviceIds ?? this.serviceIds,
    serviceNamesSnapshot: serviceNamesSnapshot ?? this.serviceNamesSnapshot,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    totalPriceVnd: totalPriceVnd ?? this.totalPriceVnd,
    status: status ?? this.status,
    isHiddenByCustomer: isHiddenByCustomer ?? this.isHiddenByCustomer,
    isHiddenByStaff: isHiddenByStaff ?? this.isHiddenByStaff,
    customerName: customerName ?? this.customerName,
    isReviewed: isReviewed ?? this.isReviewed,
    rating: identical(rating, _unsetRating) ? this.rating : rating as int?,
  );
}
