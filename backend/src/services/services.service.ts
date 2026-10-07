import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Service } from "./service.entity";
import { Actor } from "../auth/auth.decorators";
import {
  createCatalog,
  updateCatalog,
  deleteCatalog,
} from "../common/catalog-crud";
import { CreateServiceDto, UpdateServiceDto } from "./service.dto";

@Injectable()
export class ServicesService {
  constructor(
    @InjectRepository(Service) private readonly services: Repository<Service>,
  ) {}
  create(dto: CreateServiceDto, actor: Actor) {
    return createCatalog(
      this.services,
      { ...dto, isActive: dto.isActive ?? true },
      actor,
    );
  }
  update(id: string, dto: UpdateServiceDto, actor: Actor) {
    return updateCatalog(this.services, id, dto, actor);
  }
  delete(id: string, actor: Actor) {
    return deleteCatalog(this.services, id, actor);
  }
  // Shared catalog includes inactive items; Booking must filter isActive.
  findAll(): Promise<Service[]> {
    return this.services.find({ order: { name: "ASC", id: "ASC" } });
  }
}
