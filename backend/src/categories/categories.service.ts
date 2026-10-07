import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Category } from "./category.entity";
import { Actor } from "../auth/auth.decorators";
import {
  createCatalog,
  updateCatalog,
  deleteCatalog,
} from "../common/catalog-crud";
import { CreateCategoryDto, UpdateCategoryDto } from "./category.dto";

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(Category)
    private readonly categories: Repository<Category>,
  ) {}
  create(dto: CreateCategoryDto, actor: Actor) {
    return createCatalog(this.categories, dto, actor);
  }
  update(id: string, dto: UpdateCategoryDto, actor: Actor) {
    return updateCatalog(this.categories, id, dto, actor);
  }
  delete(id: string, actor: Actor) {
    return deleteCatalog(this.categories, id, actor);
  }
  findAll(): Promise<Category[]> {
    return this.categories.find({ order: { name: "ASC", id: "ASC" } });
  }
}
