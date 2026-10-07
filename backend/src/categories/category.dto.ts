import { IsIn } from "class-validator";
import { TextField } from "../common/dto";
import { CATEGORY_IDS } from "./category.constants";
export class CreateCategoryDto {
  @IsIn(CATEGORY_IDS) id!: string;
  @TextField(120) name!: string;
}
export class UpdateCategoryDto {
  @TextField(120) name!: string;
}
