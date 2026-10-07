import {
  ConflictException,
  ForbiddenException,
  UnauthorizedException,
} from "@nestjs/common";
import { EntityManager, ObjectLiteral, Repository } from "typeorm";
import { Actor } from "../auth/auth.decorators";
import { User, UserRole } from "../users/user.entity";
import { Credential } from "../auth/credential.entity";

export function requireRole(actor: Actor, roles: UserRole[]) {
  if (!actor || !roles.includes(actor.role)) throw new ForbiddenException();
}
export async function scopedMutation<T, E extends ObjectLiteral>(
  repo: Repository<E>,
  actor: Actor,
  roles: UserRole[],
  work: (manager: EntityManager, current: User) => Promise<T>,
  beforeAuthorize?: (manager: EntityManager) => Promise<void>,
): Promise<T> {
  requireRole(actor, roles);
  try {
    return await repo.manager.connection.transaction(async (manager) => {
      if (beforeAuthorize) await beforeAuthorize(manager);
      const current = await manager.findOne(User, {
        where: { id: actor.id },
        lock: { mode: "pessimistic_read" },
      });
      const credential = await manager.findOne(Credential, {
        where: { userId: actor.id },
        lock: { mode: "pessimistic_read" },
      });
      if (
        !current ||
        !credential ||
        !current.isApproved ||
        current.role !== actor.role ||
        current.branchId !== actor.branchId ||
        credential.tokenVersion !== actor.tokenVersion
      )
        throw new UnauthorizedException("Account changed");
      requireRole({ ...current, tokenVersion: actor.tokenVersion }, roles);
      return work(manager, current);
    });
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code === "23505" || code === "23P01")
      throw new ConflictException("Record already exists or overlaps");
    if (code === "23503" || code === "23001")
      throw new ConflictException(
        "Record is referenced or a related record is missing",
      );
    throw error;
  }
}
