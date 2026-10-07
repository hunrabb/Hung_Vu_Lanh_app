import { BadRequestException } from "@nestjs/common";
export type Span = { start: number; end: number };
const MINUTE = 60000,
  DAY = 86400000,
  OFFSET = 7 * 3600000;
export function hanoiDay(date: string) {
  const midnight = Date.parse(date + "T00:00:00Z");
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
    Number(date.slice(0, 4)) < 1 ||
    !Number.isFinite(midnight) ||
    new Date(midnight).toISOString().slice(0, 10) !== date
  )
    throw new BadRequestException("Invalid Hanoi date");
  return {
    start: midnight - OFFSET,
    end: midnight - OFFSET + DAY,
    weekday: new Date(midnight).getUTCDay() || 7,
  };
}
export function mergeSpans(spans: Span[]): Span[] {
  const merged: Span[] = [];
  for (const span of spans
    .filter((s) => s.end > s.start)
    .map((s) => ({ ...s }))
    .sort((a, b) => a.start - b.start)) {
    const last = merged[merged.length - 1];
    if (last && span.start <= last.end) last.end = Math.max(last.end, span.end);
    else merged.push(span);
  }
  return merged;
}
export function freeSpans(work: Span[], busy: Span[]): Span[] {
  const blocked = mergeSpans(busy),
    result: Span[] = [];
  for (const span of mergeSpans(work)) {
    let cursor = span.start;
    for (const block of blocked) {
      if (block.end <= cursor) continue;
      if (block.start >= span.end) break;
      if (block.start > cursor)
        result.push({ start: cursor, end: Math.min(block.start, span.end) });
      cursor = Math.max(cursor, block.end);
      if (cursor >= span.end) break;
    }
    if (cursor < span.end) result.push({ start: cursor, end: span.end });
  }
  return result;
}
export function calculateSlots(
  open: Span,
  shifts: Span[],
  busy: Span[],
  durationMinutes: number,
  now: number,
) {
  if (
    !Number.isInteger(durationMinutes) ||
    durationMinutes <= 0 ||
    durationMinutes > 1440
  )
    throw new BadRequestException("Invalid total duration");
  const work = shifts.map((s) => ({
    start: Math.max(s.start, open.start),
    end: Math.min(s.end, open.end),
  }));
  const free = freeSpans(work, busy);
  const duration = durationMinutes * MINUTE;
  const slots: { startAt: string; endAt: string }[] = [];
  for (const span of free) {
    const first = Math.ceil(span.start / MINUTE) * MINUTE;
    for (let start = first; start + duration <= span.end; start += duration)
      if (start > now)
        slots.push({
          startAt: new Date(start).toISOString(),
          endAt: new Date(start + duration).toISOString(),
        });
  }
  return { slots, free };
}
