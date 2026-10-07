import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
} from "@nestjs/common";
import { BranchesService } from "./branches.service";
import { Branch } from "./branch.entity";
import { Public, Roles, CurrentUser, Actor } from "../auth/auth.decorators";
import {
  CreateBranchDto,
  UpdateBranchDto,
  UpdateSettingsDto,
} from "./branch.dto";

@Controller("branches")
export class BranchesController {
  constructor(private readonly branches: BranchesService) {}
  @Roles("boss") @Post() create(
    @Body() dto: CreateBranchDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.branches.create(dto, actor);
  }
  @Roles("boss") @Patch(":id") update(
    @Param("id") id: string,
    @Body() dto: UpdateBranchDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.branches.update(id, dto, actor);
  }
  @Roles("boss") @Delete(":id") delete(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.branches.delete(id, actor);
  }
  @Roles("boss", "manager") @Patch(":branchId/settings") settings(
    @Param("branchId") id: string,
    @Body() dto: UpdateSettingsDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.branches.settings(id, dto, actor);
  }

  @Get()
  @Public()
  findAll(): Promise<Branch[]> {
    return this.branches.findAll();
  }
}
