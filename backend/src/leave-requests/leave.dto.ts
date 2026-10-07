import { IsIn } from "class-validator";
import { Instant } from "../common/calendar.dto";
import { TextField } from "../common/dto";
export class CreateLeaveDto {
  @Instant() startAt!: string;
  @Instant() endAt!: string;
  @TextField(1000) reason!: string;
}
export class DecisionDto {
  @IsIn(["approved", "rejected"]) status!: "approved" | "rejected";
  @TextField(1000, true) note?: string;
}
