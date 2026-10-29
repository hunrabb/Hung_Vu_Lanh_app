export type UserRole = "superAdmin" | "manager" | "staff" | "customer";
export class User {
  id!: string;
  email!: string;
  role!: UserRole;
  branchId!: string | null;
  name!: string;
  phone!: string | null;
  address!: string | null;
  isApproved!: boolean;
  createdAt!: Date;
}
