import assert from "node:assert/strict";
import test from "node:test";
import { parseMoveInput } from "../src/movement";

const bytes = (value: string) => new TextEncoder().encode(value);

test("normalizes forged movement vectors", () => {
  const input = parseMoveInput(bytes('{"x":999,"y":999,"sequence":1}'))!;
  assert.ok(Math.hypot(input.x, input.y) <= 1.000001);
});

test("rejects malformed and non-finite movement", () => {
  assert.equal(parseMoveInput(bytes("not-json")), null);
  assert.equal(parseMoveInput(bytes('{"x":1,"sequence":1}')), null);
  assert.equal(parseMoveInput(bytes('{"x":1e999,"y":0,"sequence":1}')), null);
  assert.equal(parseMoveInput(bytes("x".repeat(257))), null);
});
