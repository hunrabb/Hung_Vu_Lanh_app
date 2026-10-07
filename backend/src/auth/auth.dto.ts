import { IsEmail, IsString, MaxLength, MinLength } from "class-validator";
import { Transform } from "class-transformer";
const normalizeEmail = ({ value }: { value: unknown }) =>
  typeof value === "string" ? value.trim().toLowerCase() : value;
export class LoginDto {
  @Transform(normalizeEmail) @IsEmail() @MaxLength(254) email!: string;
  @IsString() @MinLength(1) @MaxLength(256) password!: string;
}
export class RegisterDto {
  @IsString() @MinLength(1) @MaxLength(120) name!: string;
  @Transform(normalizeEmail) @IsEmail() @MaxLength(254) email!: string;
  @IsString() @MinLength(8) @MaxLength(72) password!: string;
}
export class PasswordDto {
  @IsString() @MinLength(1) @MaxLength(256) oldPassword!: string;
  @IsString() @MinLength(8) @MaxLength(72) newPassword!: string;
}
