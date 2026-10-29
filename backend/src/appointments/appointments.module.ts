import { Module } from "@nestjs/common";
import { BookingService } from "./booking.service";
import { AppointmentsService } from "./appointments.service";
import { AppointmentsController } from "./appointments.controller";
@Module({
  providers: [BookingService, AppointmentsService],
  controllers: [AppointmentsController],
  exports: [BookingService, AppointmentsService],
})
export class AppointmentsModule {}
