import { Type } from "class-transformer";
import { IsIn, IsInt, Min, Max } from "class-validator";
import { TextField, optional } from "../common/dto";
export class CreateReviewDto {
  @IsIn(["branch", "staff"]) target!: "branch" | "staff";
  @IsInt() @Min(1) @Max(5) rating!: number;
  @TextField(1000, true) comment?: string;
}
export class ReviewQueryDto {
  @IsIn(["branch", "staff"]) target!: "branch" | "staff";
  @TextField(200) targetId!: string;
  @optional() @Type(() => Number) @IsInt() @Min(1) @Max(10000) page = 1;
}
