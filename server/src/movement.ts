export interface MoveInput { x: number; y: number; sequence: number; }

export function parseMoveInput(data: Uint8Array): MoveInput | null {
  if (data.byteLength === 0 || data.byteLength > 256) return null;
  try {
    const value = JSON.parse(String.fromCharCode.apply(null, Array.from(data))) as Record<string, unknown>;
    if (typeof value.x !== "number" || typeof value.y !== "number" || typeof value.sequence !== "number") return null;
    if (!Number.isFinite(value.x) || !Number.isFinite(value.y) || !Number.isSafeInteger(value.sequence) || value.sequence < 0) return null;
    let x = Math.max(-1, Math.min(1, value.x));
    let y = Math.max(-1, Math.min(1, value.y));
    const magnitude = Math.sqrt(x * x + y * y);
    if (magnitude > 1) { x /= magnitude; y /= magnitude; }
    return { x, y, sequence: value.sequence };
  } catch (_) {
    return null;
  }
}
