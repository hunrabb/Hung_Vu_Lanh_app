import { Column, Entity, PrimaryColumn } from "typeorm";
@Entity("reviews")
export class Review {
  @PrimaryColumn("text", { name: "appointment_id" }) appointmentId!: string;
  @PrimaryColumn("text", { name: "target_type" }) target!: "branch" | "staff";
  @Column("text", { name: "target_id" }) targetId!: string;
  @Column("text", { name: "customer_id" }) customerId!: string;
  @Column("smallint") rating!: number;
  @Column("text") comment!: string;
  @Column("timestamptz", { name: "created_at" }) createdAt!: Date;
}
