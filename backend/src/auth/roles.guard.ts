import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { Actor, ROLES_KEY } from "./auth.decorators";
import { UserRole } from "../users/user.entity";
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}
  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!roles) return true;
    const user: Actor = context.switchToHttp().getRequest().user;
    if (!user || !roles.includes(user.role))
      throw new ForbiddenException("Insufficient role");
    return true;
  }
}
