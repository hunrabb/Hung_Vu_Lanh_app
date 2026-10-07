enum LeaveStatus { pending, approved, rejected }

String leaveLabel(LeaveStatus status) => switch (status) {
  LeaveStatus.pending => 'Chờ duyệt',
  LeaveStatus.approved => 'Đã duyệt',
  LeaveStatus.rejected => 'Từ chối',
};

/// View model for mock records and the existing staff_leave_requests API.
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.branchId,
    required this.date,
    required this.createdAt,
    this.status = LeaveStatus.pending,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedBranchName,
    this.reviewedAt,
    this.note = '',
    this.startAt,
    this.endAt,
    this.reason = '',
  });
  final String id, staffId, staffName, branchId, date;
  final DateTime createdAt;
  final LeaveStatus status;
  final String? reviewedBy;
  final String? reviewedByName;
  final String? reviewedBranchName;
  final DateTime? reviewedAt;
  final String note;
  final DateTime? startAt, endAt;
  final String reason;
  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    id: json['id'] as String,
    staffId: json['staffId'] as String,
    staffName: json['staffName'] as String,
    branchId: json['branchId'] as String,
    date: json['leaveDate'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    startAt: DateTime.parse(json['startAt'] as String).toUtc(),
    endAt: DateTime.parse(json['endAt'] as String).toUtc(),
    reason: json['reason'] as String? ?? '',
    status: LeaveStatus.values.byName(json['status'] as String),
    reviewedBy: json['reviewedBy'] as String?,
    reviewedByName: json['reviewedByName'] as String?,
    reviewedBranchName: json['reviewedBranchName'] as String?,
    reviewedAt: json['reviewedAt'] == null
        ? null
        : DateTime.parse(json['reviewedAt'] as String).toUtc(),
    note: json['note'] as String? ?? '',
  );
  LeaveRequest reviewed({
    required LeaveStatus status,
    required String managerId,
    required String managerName,
    required String? branchName,
    required DateTime at,
    required String note,
  }) => LeaveRequest(
    id: id,
    staffId: staffId,
    staffName: staffName,
    branchId: branchId,
    date: date,
    createdAt: createdAt,
    status: status,
    reviewedBy: managerId,
    reviewedByName: managerName,
    reviewedBranchName: branchName,
    reviewedAt: at,
    note: note,
    startAt: startAt,
    endAt: endAt,
    reason: reason,
  );
}
