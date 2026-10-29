import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import { Actor } from "../auth/auth.decorators";
import { UserRole } from "../users/user.entity";
import {
  Collection,
  FirestoreStore,
  Row,
  State,
  wire,
} from "./firestore.store";
export function requireRole(actor: Actor, roles: readonly UserRole[]) {
  if (!actor || !roles.includes(actor.role)) throw new ForbiddenException();
}
export function authorize(
  s: State,
  actor: Actor,
  roles: readonly UserRole[],
): Row {
  requireRole(actor, roles);
  const user = s.users.find((u) => u.id === actor.id),
    credential = s.auth_credentials.find((c) => c.userId === actor.id);
  if (
    !user ||
    !credential ||
    !user.isApproved ||
    user.role !== actor.role ||
    user.branchId !== actor.branchId ||
    credential.tokenVersion !== actor.tokenVersion
  )
    throw new UnauthorizedException("Account changed");
  return user;
}
export function mutation<T>(
  db: FirestoreStore,
  names: Collection[],
  actor: Actor,
  roles: readonly UserRole[],
  work: (s: State, user: Row) => T | Promise<T>,
) {
  requireRole(actor, roles);
  return db.mutate(names, (s) => work(s, authorize(s, actor, roles)));
}
export function get(s: State, name: Collection, id: string): Row {
  const row = s[name].find((r) =>
    name === "auth_credentials" ? r.userId === id : r.id === id,
  );
  if (!row) throw new NotFoundException("Record not found");
  return row;
}
export function branchScope(
  actor: Pick<Actor, "role" | "branchId">,
  id: string,
) {
  if (
    !["manager", "superAdmin"].includes(actor.role) ||
    (actor.role === "manager" && actor.branchId !== id)
  )
    throw new ForbiddenException("Branch access denied");
}
export function staff(s: State, branch: string, id: string) {
  get(s, "branches", branch);
  const user = get(s, "users", id);
  if (user.role !== "staff" || !user.isApproved)
    throw new BadRequestException("Approved Staff required");
  if (user.branchId !== branch)
    throw new ForbiddenException("Staff belongs to another branch");
  return user;
}
export function emailUnique(s: State, email: string, id?: string) {
  if (
    s.users.some(
      (u) =>
        u.id !== id && u.email.toLowerCase() === email.trim().toLowerCase(),
    )
  )
    throw new ConflictException("Email already registered");
}
export function fields(dto: object): Row {
  const result = Object.fromEntries(
    Object.entries(dto).filter(([, v]) => v !== undefined),
  );
  if (!Object.keys(result).length)
    throw new BadRequestException("Empty update");
  return result;
}
export const overlaps = (a: Row, b: Row) =>
  +a.startAt < +b.endAt && +a.endAt > +b.startAt;
export const blocking = (a: Row) =>
  ["pending", "confirmed", "completed"].includes(a.status);
export function sorted(rows: Row[], key: string, descending = false) {
  return [...rows].sort((a, b) => {
    const x = a[key] instanceof Date ? +a[key] : a[key],
      y = b[key] instanceof Date ? +b[key] : b[key];
    return (
      (x < y ? -1 : x > y ? 1 : 0) * (descending ? -1 : 1) ||
      String(a.id ?? a.appointmentId).localeCompare(
        String(b.id ?? b.appointmentId),
      )
    );
  });
}
export function page(rows: Row[], q: { page: number; limit: number }) {
  return rows.slice((q.page - 1) * q.limit, q.page * q.limit);
}
export function publicRows(name: Collection, rows: Row[]) {
  return rows.map((row) => wire(name, row));
}
