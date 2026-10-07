import { Type } from "class-transformer";
import { IsDateString, IsIn, IsInt, Matches, Max, Min } from "class-validator";
import { optional, TextField } from "../common/dto";
export class ReportQueryDto {
  @optional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  @IsDateString({ strict: true })
  from?: string;
  @optional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  @IsDateString({ strict: true })
  to?: string;
  @optional() @Type(() => Number) @IsInt() @Min(1) @Max(1000000) page: number =
    1;
  @optional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit: number = 50;
}
export class BossReportQueryDto extends ReportQueryDto {
  @TextField(200, true) branchId?: string;
  @optional()
  @IsIn(["pending", "confirmed", "completed", "cancelled", "noShow"])
  status?: string;
}
