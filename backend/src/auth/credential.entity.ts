import { Column, Entity, PrimaryColumn } from "typeorm";
@Entity({ name: "auth_credentials", schema: "public" })
export class Credential {
  @PrimaryColumn({ name: "user_id", type: "text" }) userId!: string;
  @Column({ name: "password_hash", type: "text", select: false })
  passwordHash!: string;
  @Column({ name: "token_version", type: "integer" }) tokenVersion!: number;
}
