export interface Booking {
  start: number;
  end: number;
}

export function overlaps(a: Booking, b: Booking): boolean {
  return a.start <= b.end && b.start <= a.end;
}
