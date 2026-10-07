import { Column, Entity, PrimaryColumn } from "typeorm";
// pg parses DATE[] as local-midnight Date objects, unlike a scalar TypeORM date.
// Preserve calendar parts; converting to UTC ISO would shift dates on UTC+7 hosts.
export const calendarDates = {
  to: (value: string[]) => value,
  from: (value: (Date | string)[]) =>
    value.map((date) =>
      typeof date === "string"
        ? date
        : `${String(date.getFullYear()).padStart(4, "0")}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`,
    ),
};
@Entity({ name: "shop_settings", schema: "public" })
export class ShopSettings {
  @PrimaryColumn({ name: "branch_id", type: "text" }) branchId!: string;
  @Column({ type: "text" }) id!: string;
  @Column({ name: "opening_minute", type: "smallint" }) openingMinute!: number;
  @Column({ name: "closing_minute", type: "smallint" }) closingMinute!: number;
  @Column({ name: "closed_weekdays", type: "smallint", array: true })
  closedWeekdays!: number[];
  @Column({
    name: "closed_dates",
    type: "date",
    array: true,
    transformer: calendarDates,
  })
  closedDates!: string[];
}
