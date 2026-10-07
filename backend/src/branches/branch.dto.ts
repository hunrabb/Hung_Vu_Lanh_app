import {
  ArrayUnique,
  IsArray,
  IsDateString,
  IsInt,
  Matches,
  Max,
  Min,
} from "class-validator";
import { optional, TextField } from "../common/dto";
export class CreateBranchDto {
  @TextField(120) name!: string;
  @TextField(300) address!: string;
  @TextField(30) @Matches(/^\+?[0-9]{8,15}$/) phone!: string;
}
export class UpdateBranchDto {
  @TextField(120, true) name?: string;
  @TextField(300, true) address?: string;
  @TextField(30, true) @Matches(/^\+?[0-9]{8,15}$/) phone?: string;
}
export class UpdateSettingsDto {
  @optional() @IsInt() @Min(0) @Max(1439) openingMinute?: number;
  @optional() @IsInt() @Min(1) @Max(1440) closingMinute?: number;
  @optional()
  @IsArray()
  @ArrayUnique()
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(7, { each: true })
  closedWeekdays?: number[];
  @optional()
  @IsArray()
  @ArrayUnique()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { each: true })
  @IsDateString({ strict: true }, { each: true })
  closedDates?: string[];
}
