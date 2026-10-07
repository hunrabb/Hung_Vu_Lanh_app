import { TextField } from "../common/dto";
import { Instant } from "../common/calendar.dto";
export class CreateShiftDto {
  @TextField(200) staffId!: string;
  @Instant() startAt!: string;
  @Instant() endAt!: string;
}
export class UpdateShiftDto {
  @Instant(true) startAt?: string;
  @Instant(true) endAt?: string;
}
