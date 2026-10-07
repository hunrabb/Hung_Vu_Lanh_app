import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { Branch } from "./branch.entity";
import { BranchesService } from "./branches.service";
import { BranchesController } from "./branches.controller";
import { ShopSettings } from "./shop-settings.entity";

@Module({
  imports: [TypeOrmModule.forFeature([Branch, ShopSettings])],
  controllers: [BranchesController],
  providers: [BranchesService],
  exports: [BranchesService],
})
export class BranchesModule {}
