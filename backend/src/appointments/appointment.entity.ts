import { Column, Entity, PrimaryColumn } from "typeorm";
export type AppointmentStatus =
  "pending" | "confirmed" | "completed" | "cancelled" | "noShow";
@Entity("appointments")
export class Appointment {
  @PrimaryColumn("text") id!: string;
  @Column("text", { name: "branch_id" }) branchId!: string;
  @Column("text", { name: "staff_id" }) staffId!: string;
  @Column("text", { name: "customer_id", nullable: true }) customerId!:
    string | null;
  @Column("text", { name: "customer_name" }) customerName!: string;
  @Column("timestamptz", { name: "start_at" }) startAt!: Date;
  @Column("timestamptz", { name: "end_at" }) endAt!: Date;
  @Column("bigint", { name: "total_price_vnd" }) totalPriceVnd!: string;
  @Column("text") status!: AppointmentStatus;
  @Column("boolean", { name: "is_hidden_by_customer" })
  isHiddenByCustomer!: boolean;
  @Column("boolean", { name: "is_hidden_by_staff" }) isHiddenByStaff!: boolean;
  @Column("boolean", { name: "is_reviewed" }) isReviewed!: boolean;
  @Column("smallint", { nullable: true }) rating!: number | null;
}
@Entity("appointment_services")
export class AppointmentServiceItem {
  @PrimaryColumn("text", { name: "appointment_id" }) appointmentId!: string;
  @PrimaryColumn("integer") position!: number;
  @Column("text", { name: "service_id" }) serviceId!: string;
  @Column("text", { name: "service_name_snapshot" })
  serviceNameSnapshot!: string;
}
