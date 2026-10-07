import { Transform } from "class-transformer";
import {
  ArrayNotEmpty,
  ArrayUnique,
  IsArray,
  IsEmail,
  IsIn,
  IsString,
  MaxLength,
  MinLength,
  Matches,
} from "class-validator";
import { optional, TextField } from "../common/dto";
import { CATEGORY_IDS } from "../categories/category.constants";
export class CreateStaffDto {
  @TextField(120) name!: string;
  @Transform(({ value }) =>
    typeof value === "string" ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  @MaxLength(254)
  email!: string;
  @TextField(30) @Matches(/^\+?[0-9]{8,15}$/) phone!: string;
  @TextField(300) address!: string;
  @IsArray()
  @ArrayNotEmpty()
  @ArrayUnique()
  @IsIn(CATEGORY_IDS, { each: true })
  specializedCategoryIds!: string[];
}
export class UpdateStaffDto {
  @TextField(120, true) name?: string;
  @optional()
  @Transform(({ value }) =>
    typeof value === "string" ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  @MaxLength(254)
  email?: string;
  @TextField(30, true) @Matches(/^\+?[0-9]{8,15}$/) phone?: string;
  @TextField(300, true) address?: string;
  @optional()
  @IsArray()
  @ArrayNotEmpty()
  @ArrayUnique()
  @IsIn(CATEGORY_IDS, { each: true })
  specializedCategoryIds?: string[];
}
export class ApproveStaffDto {
  @IsString() @MinLength(8) @MaxLength(72) password!: string;
}
