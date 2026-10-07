import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
} from "@nestjs/common";
import { ServicesService } from "./services.service";
import { Public, Roles, CurrentUser, Actor } from "../auth/auth.decorators";
import { CreateServiceDto, UpdateServiceDto } from "./service.dto";

@Controller("services")
export class ServicesController {
  constructor(private readonly services: ServicesService) {}
  @Roles("boss") @Post() create(
    @Body() dto: CreateServiceDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.services.create(dto, actor);
  }
  @Roles("boss") @Patch(":id") update(
    @Param("id") id: string,
    @Body() dto: UpdateServiceDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.services.update(id, dto, actor);
  }
  @Roles("boss") @Delete(":id") delete(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.services.delete(id, actor);
  }
  @Get()
  @Public()
  findAll() {
    return this.services.findAll();
  }
}
