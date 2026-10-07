import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { User } from "./user.entity";
import { UsersService } from "./users.service";
import { UsersController } from "./users.controller";
import { StaffSpecialization } from "./staff-specialization.entity";
import { Credential } from "../auth/credential.entity";

@Module({
  imports: [TypeOrmModule.forFeature([User, StaffSpecialization, Credential])],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
