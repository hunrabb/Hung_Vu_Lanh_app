import { BadRequestException, NotFoundException } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { DeepPartial, ObjectLiteral, Repository } from "typeorm";
import { Actor } from "../auth/auth.decorators";
import { scopedMutation } from "./mutations";
export function defined<T extends object>(dto: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(dto).filter(([, value]) => value !== undefined),
  ) as Partial<T>;
}
export function createCatalog<E extends ObjectLiteral>(
  repo: Repository<E>,
  dto: object,
  actor: Actor,
) {
  return scopedMutation(repo, actor, ["superAdmin"], async (manager) => {
    const target = manager.getRepository(repo.target);
    const item = target.create({
      id: randomUUID(),
      ...dto,
    } as unknown as DeepPartial<E>);
    await target.insert(item);
    return item;
  });
}
export function updateCatalog<E extends ObjectLiteral>(
  repo: Repository<E>,
  id: string,
  dto: object,
  actor: Actor,
) {
  const fields = defined(dto);
  if (!Object.keys(fields).length)
    throw new BadRequestException("Empty update");
  return scopedMutation(repo, actor, ["superAdmin"], async (manager) => {
    const target = manager.getRepository(repo.target);
    const item = await target.findOne({
      where: { id } as never,
      lock: { mode: "pessimistic_write" },
    });
    if (!item) throw new NotFoundException();
    Object.assign(item, fields);
    return target.save(item);
  });
}
export function deleteCatalog<E extends ObjectLiteral>(
  repo: Repository<E>,
  id: string,
  actor: Actor,
) {
  return scopedMutation(repo, actor, ["superAdmin"], async (manager) => {
    const target = manager.getRepository(repo.target);
    const item = await target.findOne({
      where: { id } as never,
      lock: { mode: "pessimistic_write" },
    });
    if (!item) throw new NotFoundException();
    await target.remove(item);
    return { message: "Deleted" };
  });
}
