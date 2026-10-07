import {
  SetMetadata,
  createParamDecorator,
  ExecutionContext,
} from "@nestjs/common";
import { User, UserRole } from "../users/user.entity";
export const PUBLIC_KEY = "auth:public";
export const ROLES_KEY = "auth:roles";
export const Public = () => SetMetadata(PUBLIC_KEY, true);
export const Roles = (...roles: (UserRole | "boss")[]) =>
  SetMetadata(
    ROLES_KEY,
    roles.map((r) => (r === "boss" ? "superAdmin" : r)),
  );
export type Actor = User & { tokenVersion: number };
export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): Actor =>
    context.switchToHttp().getRequest().user,
);
