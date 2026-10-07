import { Transform } from "class-transformer";
import { IsBoolean, IsInt, Max, Min } from "class-validator";
import { IsVnd, optional, TextField } from "../common/dto";
const priceInput = ({ value }: { value: unknown }) =>
  typeof value === "number" && Number.isSafeInteger(value)
    ? String(value)
    : typeof value === "string"
      ? value.trim()
      : value;
export class CreateServiceDto {
  @TextField(120) name!: string;
  @TextField(200) categoryId!: string;
  @Transform(priceInput) @IsVnd() price!: string;
  @IsInt() @Min(1) @Max(1440) duration!: number;
  @optional() @IsBoolean() isActive?: boolean;
}
export class UpdateServiceDto {
  @TextField(120, true) name?: string;
  @TextField(200, true) categoryId?: string;
  @optional() @Transform(priceInput) @IsVnd() price?: string;
  @optional() @IsInt() @Min(1) @Max(1440) duration?: number;
  @optional() @IsBoolean() isActive?: boolean;
}
