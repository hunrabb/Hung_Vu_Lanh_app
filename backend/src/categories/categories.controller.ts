import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
} from "@nestjs/common";
import { CategoriesService } from "./categories.service";
import { Public, Roles, CurrentUser, Actor } from "../auth/auth.decorators";
import { CreateCategoryDto, UpdateCategoryDto } from "./category.dto";

@Controller("categories")
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}
  @Roles("boss") @Post() create(
    @Body() dto: CreateCategoryDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.categories.create(dto, actor);
  }
  @Roles("boss") @Patch(":id") update(
    @Param("id") id: string,
    @Body() dto: UpdateCategoryDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.categories.update(id, dto, actor);
  }
  @Roles("boss") @Delete(":id") delete(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.categories.delete(id, actor);
  }
  @Get()
  @Public()
  findAll() {
    return this.categories.findAll();
  }
}
