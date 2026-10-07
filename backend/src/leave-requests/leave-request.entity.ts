import { Column, Entity, PrimaryColumn } from "typeorm";
@Entity("staff_leave_requests")
export class LeaveRequest {
  @PrimaryColumn("text") id!: string;
  @Column("text", { name: "staff_id" }) staffId!: string;
  @Column("text", { name: "staff_name" }) staffName!: string;
  @Column("text", { name: "branch_id" }) branchId!: string;
  @Column("date", { name: "leave_date" }) leaveDate!: string;
  @Column("timestamptz", { name: "start_at" }) startAt!: Date;
  @Column("timestamptz", { name: "end_at" }) endAt!: Date;
  @Column("text") reason!: string;
  @Column("timestamptz", { name: "created_at" }) createdAt!: Date;
  @Column("text") status!: string;
  @Column("text", { name: "reviewed_by", nullable: true }) reviewedBy!:
    string | null;
  @Column("text", { name: "reviewed_by_name", nullable: true })
  reviewedByName!: string | null;
  @Column("text", { name: "reviewed_branch_name", nullable: true })
  reviewedBranchName!: string | null;
  @Column("timestamptz", { name: "reviewed_at", nullable: true })
  reviewedAt!: Date | null;
  @Column("text") note!: string;
}
