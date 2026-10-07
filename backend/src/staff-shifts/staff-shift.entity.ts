import { Column, Entity, PrimaryColumn } from "typeorm";
@Entity({ name: "staff_shifts", schema: "public" })
export class StaffShift {
  @PrimaryColumn({ type: "text" }) id!: string;
  @Column({ name: "staff_id", type: "text" }) staffId!: string;
  @Column({ name: "branch_id", type: "text" }) branchId!: string;
  @Column({ name: "start_at", type: "timestamptz" }) startAt!: Date;
  @Column({ name: "end_at", type: "timestamptz" }) endAt!: Date;
}
