import { Column, Entity, PrimaryColumn } from "typeorm";

@Entity({ name: "categories", schema: "public" })
export class Category {
  @PrimaryColumn({ type: "text" }) id!: string;
  @Column({ type: "text" }) name!: string;
}
