import { Column, Entity, PrimaryColumn } from "typeorm";

@Entity({ name: "branches", schema: "public" })
export class Branch {
  @PrimaryColumn({ type: "text" })
  id!: string;

  @Column({ type: "text" })
  name!: string;

  @Column({ type: "text" })
  address!: string;

  @Column({ type: "text" })
  phone!: string;
}
