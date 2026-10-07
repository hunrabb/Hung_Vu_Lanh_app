import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { Appointment, AppointmentServiceItem } from "./appointment.entity";
import { BookingService } from "./booking.service";
import { AppointmentsService } from "./appointments.service";
import { AppointmentsController } from "./appointments.controller";
@Module({
  imports: [TypeOrmModule.forFeature([Appointment, AppointmentServiceItem])],
  providers: [BookingService, AppointmentsService],
  controllers: [AppointmentsController],
  exports: [BookingService, AppointmentsService],
})
export class AppointmentsModule {}
