import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { FirestoreModule } from "./firestore/firestore.store";
import { validateEnvironment } from "./config/environment";
import { BranchesModule } from "./branches/branches.module";
import { UsersModule } from "./users/users.module";
import { CategoriesModule } from "./categories/categories.module";
import { ServicesModule } from "./services/services.module";
import { AuthModule } from "./auth/auth.module";
import { StaffShiftsModule } from "./staff-shifts/staff-shifts.module";
import { LeaveRequestsModule } from "./leave-requests/leave-requests.module";
import { AppointmentsModule } from "./appointments/appointments.module";
import { ReportsModule } from "./reports/reports.module";
import { ReviewsModule } from "./reviews/reviews.module";
@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnvironment }),
    FirestoreModule,
    BranchesModule,
    AuthModule,
    UsersModule,
    CategoriesModule,
    ServicesModule,
    StaffShiftsModule,
    LeaveRequestsModule,
    AppointmentsModule,
    ReportsModule,
    ReviewsModule,
  ],
})
export class AppModule {}
