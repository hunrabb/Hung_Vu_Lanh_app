import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule, TypeOrmModuleOptions } from "@nestjs/typeorm";
import * as fs from "node:fs";
import { BranchesModule } from "./branches/branches.module";
import { UsersModule } from "./users/users.module";
import { CategoriesModule } from "./categories/categories.module";
import { ServicesModule } from "./services/services.module";
import { AuthModule } from "./auth/auth.module";
import { validateEnvironment } from "./config/environment";
import { StaffShiftsModule } from "./staff-shifts/staff-shifts.module";
import { LeaveRequestsModule } from "./leave-requests/leave-requests.module";
import { AppointmentsModule } from "./appointments/appointments.module";
import { ReportsModule } from "./reports/reports.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnvironment }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService): TypeOrmModuleOptions => ({
        type: "postgres",
        host: config.getOrThrow<string>("DB_HOST"),
        port: config.getOrThrow<number>("DB_PORT"),
        database: config.getOrThrow<string>("DB_NAME"),
        username: config.getOrThrow<string>("DB_USER"),
        password: config.getOrThrow<string>("DB_PASSWORD"),
        ssl: {
          rejectUnauthorized: true,
          ca: fs.readFileSync("./ca.pem").toString(),
        },
        autoLoadEntities: true,
        synchronize: false,
        dropSchema: false,
        migrationsRun: false,
        logging: false,
      }),
    }),
    BranchesModule,
    AuthModule,
    UsersModule,
    CategoriesModule,
    ServicesModule,
    StaffShiftsModule,
    LeaveRequestsModule,
    AppointmentsModule,
    ReportsModule,
  ],
})
export class AppModule {}
