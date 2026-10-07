import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Branch } from "./branch.entity";
import { Actor } from "../auth/auth.decorators";
import { scopedMutation } from "../common/mutations";
import { defined, updateCatalog } from "../common/catalog-crud";
import {
  CreateBranchDto,
  UpdateBranchDto,
  UpdateSettingsDto,
} from "./branch.dto";
import { ShopSettings } from "./shop-settings.entity";
import { randomUUID } from "node:crypto";

@Injectable()
export class BranchesService {
  constructor(
    @InjectRepository(Branch)
    private readonly branches: Repository<Branch>,
  ) {}

  create(dto: CreateBranchDto, actor: Actor) {
    return scopedMutation(
      this.branches,
      actor,
      ["superAdmin"],
      async (manager) => {
        const branch = manager.create(Branch, { id: randomUUID(), ...dto });
        await manager.insert(Branch, branch);
        await manager.insert(ShopSettings, {
          branchId: branch.id,
          id: "settings-" + branch.id,
          openingMinute: 480,
          closingMinute: 1200,
          closedWeekdays: [],
          closedDates: [],
        });
        return branch;
      },
    );
  }
  update(id: string, dto: UpdateBranchDto, actor: Actor) {
    return updateCatalog(this.branches, id, dto, actor);
  }
  delete(id: string, actor: Actor) {
    return scopedMutation(
      this.branches,
      actor,
      ["superAdmin"],
      async (manager) => {
        const branch = await manager.findOne(Branch, {
          where: { id },
          lock: { mode: "pessimistic_write" },
        });
        if (!branch) throw new NotFoundException();
        // Foreign keys protect all linked people/appointments/shifts/leave history.
        await manager.delete(ShopSettings, { branchId: id });
        await manager.delete(Branch, { id });
        return { message: "Branch deleted" };
      },
      async (manager) => {
        // Calendar writers hold settings before taking Staff/FK locks on Branch.
        // Taking Branch first can deadlock with a concurrent shift/leave insert.
        await manager.findOne(ShopSettings, {
          where: { branchId: id },
          lock: { mode: "pessimistic_write" },
        });
      },
    );
  }
  settings(id: string, dto: UpdateSettingsDto, actor: Actor) {
    const fields = defined(dto);
    if (!Object.keys(fields).length)
      throw new BadRequestException("Empty update");
    return scopedMutation(
      this.branches,
      actor,
      ["superAdmin", "manager"],
      async (manager, current) => {
        if (current.role === "manager" && current.branchId !== id)
          throw new ForbiddenException("Branch access denied");
        const settings = await manager.findOne(ShopSettings, {
          where: { branchId: id },
          lock: { mode: "pessimistic_write" },
        });
        if (!settings) throw new NotFoundException("Branch settings not found");
        Object.assign(settings, fields);
        if (settings.closingMinute <= settings.openingMinute)
          throw new BadRequestException("Closing must follow opening");
        return manager.save(ShopSettings, settings);
      },
    );
  }

  findAll(): Promise<Branch[]> {
    return this.branches.find({
      select: { id: true, name: true, address: true, phone: true },
      order: { name: "ASC", id: "ASC" },
    });
  }
}
