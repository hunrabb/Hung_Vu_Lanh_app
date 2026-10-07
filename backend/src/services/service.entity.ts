import { Column, Entity, PrimaryColumn } from "typeorm";

@Entity({ name: "services", schema: "public" })
export class Service {
  @PrimaryColumn({ type: "text" }) id!: string;
  @Column({ name: "category_id", type: "text" }) categoryId!: string;
  @Column({ type: "text" }) name!: string;
  // PostgreSQL BIGINT is returned as a string to preserve money exactly.
  @Column({ name: "price_vnd", type: "bigint" }) price!: string;
  @Column({ name: "duration_minutes", type: "integer" }) duration!: number;
  @Column({ name: "is_active", type: "boolean" }) isActive!: boolean;
}
