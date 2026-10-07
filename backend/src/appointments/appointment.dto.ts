import { Transform, Type } from "class-transformer";
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsInt,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from "class-validator";
import { Instant } from "../common/calendar.dto";
import { optional, TextField } from "../common/dto";
export class ServiceSelectionDto {
  @Transform(({ value }) =>
    typeof value === "string" ? value.split(",").map((v) => v.trim()) : value,
  )
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(200, { each: true })
  serviceIds!: string[];
  @TextField(200) staffId!: string;
}
export class AvailableSlotsDto extends ServiceSelectionDto {
  @TextField(200) branchId!: string;
  @Matches(/^\d{4}-\d{2}-\d{2}$/) date!: string;
}
export class CreateBookingDto extends ServiceSelectionDto {
  @TextField(200) branchId!: string;
  @Instant() startAt!: string;
}
export class WalkInDto extends ServiceSelectionDto {
  @Instant() startAt!: string;
  // Name/phone supplied as one contact label; persisted in existing snapshot.
  @TextField(300) customerName!: string;
}
export class EligibleStaffDto {
  @TextField(200) serviceId!: string;
}
export class AppointmentQueryDto {
  @TextField(200, true) branchId?: string;
  @optional()
  @IsIn(["pending", "confirmed", "completed", "cancelled", "noShow"])
  status?: string;
  @Instant(true) from?: string;
  @Instant(true) to?: string;
  @optional() @Type(() => Number) @IsInt() @Min(1) @Max(1000000) page: number =
    1;
  @optional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit: number = 50;
}
