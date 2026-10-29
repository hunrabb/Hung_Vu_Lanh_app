import { Injectable } from "@nestjs/common";
import { Catalog } from "../firestore/catalog";
import { FirestoreStore } from "../firestore/firestore.store";
@Injectable()
export class ServicesService extends Catalog {
  constructor(db: FirestoreStore) {
    super(db, "services");
  }
}
