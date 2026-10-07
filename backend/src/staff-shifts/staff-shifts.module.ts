import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { StaffShift } from "./staff-shift.entity";
import { StaffShiftsService } from "./staff-shifts.service";
import { StaffShiftsController } from "./staff-shifts.controller";
@Module({
  imports: [TypeOrmModule.forFeature([StaffShift])],
  providers: [StaffShiftsService],
  controllers: [StaffShiftsController],
  exports: [StaffShiftsService],
})
export class StaffShiftsModule {}
