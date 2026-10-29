import { Global, Injectable, Module, OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  applicationDefault,
  deleteApp,
  initializeApp,
  App,
} from "firebase-admin/app";
import { Firestore, getFirestore, Timestamp } from "firebase-admin/firestore";
import { isDeepStrictEqual } from "node:util";

export const collections = [
  "users",
  "auth_credentials",
  "branches",
  "categories",
  "services",
  "appointments",
  "staff_shifts",
  "staff_leave_requests",
  "reviews",
] as const;
export type Collection = (typeof collections)[number];
// Documents retain their imported schema. API aliases are applied only at the boundary.
export type Row = Record<string, any>;
export type State = Record<Collection, Row[]>;
export function decode(value: any, field = ""): any {
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === "bigint") {
    if (["priceVnd", "totalPriceVnd"].includes(field)) return value.toString();
    const n = Number(value);
    if (!Number.isSafeInteger(n)) throw new Error("Unsafe non-money integer");
    return n;
  }
  if (Array.isArray(value)) return value.map((item) => decode(item, field));
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, decode(item, key)]),
    );
  return value;
}
export function encode(value: any, field = ""): any {
  if (value instanceof Date || value instanceof Timestamp) return value;
  if (["priceVnd", "totalPriceVnd"].includes(field)) return BigInt(value);
  if (Array.isArray(value)) return value.map((item) => encode(item, field));
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value)
        .filter(([, item]) => item !== undefined)
        .map(([key, item]) => [key, encode(item, key)]),
    );
  return value;
}
export function identity(collection: Collection, row: Row): string {
  return collection === "auth_credentials"
    ? row.userId
    : collection === "reviews"
      ? `${row.appointmentId}__${row.targetType}`
      : row.id;
}
export function wire(collection: Collection, row: Row): Row {
  if (collection === "services") {
    const { priceVnd, durationMinutes, ...rest } = row;
    return { ...rest, price: String(priceVnd), duration: durationMinutes };
  }
  if (collection === "reviews") {
    const { targetType, ...rest } = row;
    return { ...rest, target: targetType };
  }
  if (collection === "branches") {
    const { settings, ...rest } = row;
    return rest;
  }
  if (collection === "appointments") {
    const { serviceIds, ...rest } = row;
    return { ...rest, totalPriceVnd: String(row.totalPriceVnd) };
  }
  return { ...row };
}
@Injectable()
export class FirestoreStore implements OnModuleDestroy {
  readonly db: Firestore;
  private readonly app: App;
  private readonly root: string;
  constructor(config: ConfigService) {
    const testRun = config.get<string>("FIRESTORE_TEST_RUN_ID");
    if (testRun && !/^[a-zA-Z0-9-]+$/.test(testRun))
      throw new Error("Invalid isolated test ID");
    this.root = testRun ? "_test_runs/" + testRun + "/" : "";
    this.app = initializeApp(
      {
        projectId: config.getOrThrow<string>("FIREBASE_PROJECT_ID"),
        credential: applicationDefault(),
      },
      "ktgk-api",
    );
    this.db = getFirestore(
      this.app,
      config.getOrThrow<string>("FIRESTORE_DATABASE_ID"),
    );
    this.db.settings({ useBigInt: true });
  }
  async onModuleDestroy() {
    await this.db.terminate();
    await deleteApp(this.app);
  }
  async read<T>(
    names: readonly Collection[],
    work: (state: State) => T | Promise<T>,
  ): Promise<T> {
    return this.db.runTransaction(
      async (tx) => {
        const state = Object.fromEntries(
          collections.map((name) => [name, []]),
        ) as unknown as State;
        for (const name of names)
          state[name] = (
            await tx.get(this.db.collection(this.root + name))
          ).docs.map((doc) => decode(doc.data()));
        return work(state);
      },
      { readOnly: true },
    );
  }
  async mutate<T>(
    names: readonly Collection[],
    work: (state: State) => T | Promise<T>,
  ): Promise<T> {
    return this.db.runTransaction(async (tx) => {
      // A shared write fence serializes constraints even when a query is empty.
      // Suitable for this small coursework dataset; see FIRESTORE_RUNTIME.md.
      const fence = this.db.doc(this.root + "_runtime/constraints");
      await tx.get(fence);
      const state = Object.fromEntries(
        collections.map((name) => [name, []]),
      ) as unknown as State;
      const original = new Map<Collection, Map<string, Row>>();
      for (const name of new Set<Collection>([
        "users",
        "auth_credentials",
        ...names,
      ])) {
        const docs = (await tx.get(this.db.collection(this.root + name))).docs;
        state[name] = docs.map((doc) => decode(doc.data()));
        original.set(
          name,
          new Map(
            state[name].map((row) => [
              identity(name, row),
              structuredClone(row),
            ]),
          ),
        );
      }
      const result = await work(state);
      for (const [name, before] of original) {
        const after = new Map(
          state[name].map((row) => [identity(name, row), row]),
        );
        for (const [id, row] of after) {
          if (!id || id.includes("/"))
            throw new Error("Invalid document identity");
          const ref = this.db.collection(this.root + name).doc(id);
          if (!before.has(id)) tx.create(ref, encode(row));
          else if (!isDeepStrictEqual(before.get(id), row)) {
            // Patch changed top-level fields to retain untouched Timestamp precision.
            const patch = Object.fromEntries(
              Object.entries(row).filter(
                ([key, value]) =>
                  !isDeepStrictEqual(before.get(id)![key], value),
              ),
            );
            tx.update(ref, encode(patch));
          }
        }
        for (const id of before.keys())
          if (!after.has(id))
            tx.delete(this.db.collection(this.root + name).doc(id));
      }
      tx.set(fence, { changedAt: Timestamp.now() });
      return result;
    });
  }
}
@Global()
@Module({ providers: [FirestoreStore], exports: [FirestoreStore] })
export class FirestoreModule {}
