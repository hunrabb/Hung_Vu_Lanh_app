import { Entity, PrimaryColumn } from "typeorm";
@Entity({ name: "staff_specializations", schema: "public" })
export class StaffSpecialization {
  @PrimaryColumn({ name: "staff_id", type: "text" }) staffId!: string;
  @PrimaryColumn({ name: "category_id", type: "text" }) categoryId!: string;
}
