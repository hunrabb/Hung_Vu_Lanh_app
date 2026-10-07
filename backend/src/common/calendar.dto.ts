import { applyDecorators } from "@nestjs/common";
import { IsISO8601, Matches } from "class-validator";
import { optional } from "./dto";
export function Instant(isOptional = false) {
  return applyDecorators(
    ...(isOptional ? [optional()] : []),
    IsISO8601({ strict: true }),
    Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/),
  );
}
