export interface MoveInput { x: number; y: number; sequence: number; }

export function movementPayloadText(data: string | ArrayBuffer | Uint8Array): string {
  if (typeof data === "string") return data;
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
  return String.fromCharCode.apply(null, Array.from(bytes));
}

export function parseMoveInput(data: string | ArrayBuffer | Uint8Array): MoveInput | null {
  const payload = movementPayloadText(data);
  if (payload.length === 0 || payload.length > 256) return null;
  try {
    const value = JSON.parse(payload) as Record<string, unknown>;
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
