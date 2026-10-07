import { BadRequestException } from "@nestjs/common";
import { hanoiDay } from "../appointments/slot-engine";
const DAY = 86400000;
export function reportPeriods(now = Date.now()) {
  const date = new Date(now + 7 * 3600000).toISOString().slice(0, 10),
    day = hanoiDay(date);
  const month = date.slice(0, 7) + "-01";
  const next = new Date(month + "T00:00:00Z");
  next.setUTCMonth(next.getUTCMonth() + 1);
  return {
    day: { from: new Date(day.start), to: new Date(day.end) },
    month: {
      from: new Date(hanoiDay(month).start),
      to: new Date(hanoiDay(next.toISOString().slice(0, 10)).start),
    },
  };
}
export function reportRange(
  query: { from?: string; to?: string },
  now = Date.now(),
) {
  if (!query.from && !query.to) return reportPeriods(now).month;
  if (!query.from || !query.to)
    throw new BadRequestException("from and to must be supplied together");
  const start = hanoiDay(query.from).start,
    end = hanoiDay(query.to).end;
  if (end <= start || end - start > 366 * DAY)
    throw new BadRequestException("Range must be ordered and at most 366 days");
  return { from: new Date(start), to: new Date(end) };
}
