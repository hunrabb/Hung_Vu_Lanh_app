import { applyDecorators } from "@nestjs/common";
import { Transform } from "class-transformer";
import {
  IsNotEmpty,
  IsString,
  MaxLength,
  ValidateIf,
  registerDecorator,
  ValidationOptions,
} from "class-validator";
export const optional = () => ValidateIf((_o, value) => value !== undefined);
export function TextField(max: number, isOptional = false) {
  return applyDecorators(
    ...(isOptional ? [optional()] : []),
    Transform(({ value }) =>
      typeof value === "string" ? value.trim() : value,
    ),
    IsString(),
    IsNotEmpty(),
    MaxLength(max),
  );
}
export function IsVnd(options?: ValidationOptions) {
  return (target: object, propertyName: string) =>
    registerDecorator({
      name: "isVnd",
      target: target.constructor,
      propertyName,
      options,
      validator: {
        validate(value: unknown) {
          return (
            typeof value === "string" &&
            /^(0|[1-9]\d{0,18})$/.test(value) &&
            BigInt(value) <= 9223372036854775807n
          );
        },
        defaultMessage() {
          return "price must be a nonnegative integer VND amount";
        },
      },
    });
}
