export class LeaveRequest {
  id!: string;
  staffId!: string;
  staffName!: string;
  branchId!: string;
  leaveDate!: string;
  startAt!: Date;
  endAt!: Date;
  reason!: string;
  createdAt!: Date;
  status!: string;
  reviewedBy!: string | null;
  reviewedByName!: string | null;
  reviewedBranchName!: string | null;
  reviewedAt!: Date | null;
  note!: string;
}
