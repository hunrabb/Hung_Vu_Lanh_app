import { Module } from "@nestjs/common";
import { StaffShiftsService } from "./staff-shifts.service";
import { StaffShiftsController } from "./staff-shifts.controller";
@Module({
  providers: [StaffShiftsService],
  controllers: [StaffShiftsController],
  exports: [StaffShiftsService],
})
export class StaffShiftsModule {}
