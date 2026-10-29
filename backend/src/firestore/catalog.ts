import { ConflictException } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { Actor } from "../auth/auth.decorators";
import { Collection, FirestoreStore, Row, wire } from "./firestore.store";
import { fields, get, mutation, publicRows, sorted } from "./rules";
export class Catalog {
  constructor(
    protected readonly db: FirestoreStore,
    private readonly name: "categories" | "services",
  ) {}
  findAll() {
    return this.db.read([this.name], (s) =>
      publicRows(this.name, sorted(s[this.name], "name")),
    );
  }
  private input(dto: Row) {
    const value = { ...dto };
    if (this.name === "services") {
      if (value.price !== undefined) {
        value.priceVnd = value.price;
        delete value.price;
      }
      if (value.duration !== undefined) {
        value.durationMinutes = value.duration;
        delete value.duration;
      }
    }
    return value;
  }
  async create(dto: Row, actor: Actor) {
    return mutation(
      this.db,
      [this.name, "categories"],
      actor,
      ["superAdmin"],
      (s) => {
        const row: Row = {
          id: randomUUID(),
          ...(this.name === "services" ? { isActive: true } : {}),
          ...this.input(dto),
        };
        if (s[this.name].some((r) => r.id === row.id))
          throw new ConflictException("Record already exists");
        if (this.name === "services") get(s, "categories", row.categoryId);
        s[this.name].push(row);
        return wire(this.name, row);
      },
    );
  }
  update(id: string, dto: Row, actor: Actor) {
    const changes = this.input(fields(dto));
    return mutation(
      this.db,
      [this.name, "categories"],
      actor,
      ["superAdmin"],
      (s) => {
        const row = get(s, this.name, id);
        if (changes.categoryId !== undefined)
          get(s, "categories", changes.categoryId);
        Object.assign(row, changes);
        return wire(this.name, row);
      },
    );
  }
  delete(id: string, actor: Actor) {
    const names: Collection[] = [this.name, "services", "appointments"];
    return mutation(this.db, names, actor, ["superAdmin"], (s) => {
      get(s, this.name, id);
      if (
        this.name === "categories"
          ? s.services.some((r) => r.categoryId === id) ||
            s.users.some((r) => r.specializedCategoryIds?.includes(id))
          : s.appointments.some((r) => r.serviceIds?.includes(id))
      )
        throw new ConflictException("Record is referenced");
      s[this.name] = s[this.name].filter((r) => r.id !== id);
      return { message: "Deleted" };
    });
  }
}
