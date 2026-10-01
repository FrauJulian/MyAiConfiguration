import { test } from 'node:test';
import assert from 'node:assert/strict';
import { overlaps } from '../src/booking.ts';

test('back-to-back bookings do not overlap', () => {
  assert.equal(overlaps({ start: 9, end: 10 }, { start: 10, end: 11 }), false);
  assert.equal(overlaps({ start: 10, end: 11 }, { start: 9, end: 10 }), false);
});

test('real overlaps are detected', () => {
  assert.equal(overlaps({ start: 9, end: 11 }, { start: 10, end: 12 }), true);
  assert.equal(overlaps({ start: 9, end: 12 }, { start: 10, end: 11 }), true);
  assert.equal(overlaps({ start: 9, end: 10 }, { start: 11, end: 12 }), false);
});
