import { Column, Entity, PrimaryColumn } from "typeorm";

export type UserRole = "superAdmin" | "manager" | "staff" | "customer";

@Entity({ name: "users", schema: "public" })
export class User {
  @PrimaryColumn({ type: "text" }) id!: string;
  @Column({ type: "text" }) email!: string;
  @Column({ type: "text" }) role!: UserRole;
  @Column({ name: "branch_id", type: "text", nullable: true }) branchId!:
    string | null;
  @Column({ type: "text" }) name!: string;
  @Column({ type: "text", nullable: true }) phone!: string | null;
  @Column({ type: "text", nullable: true }) address!: string | null;
  @Column({ name: "is_approved", type: "boolean" }) isApproved!: boolean;
  @Column({ name: "created_at", type: "timestamptz" }) createdAt!: Date;
}
