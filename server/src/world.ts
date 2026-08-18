import mapData from "../../client/data/world_map.json";

export interface Point { x: number; y: number; }
interface Rect extends Point { width: number; height: number; }

export const WORLD_BOUNDS: Rect = mapData.bounds;
export const WORLD_WALLS: Rect[] = mapData.walls;
export const PLAYER_RADIUS = 13;
export const ZOMBIE_RADIUS = 12;

export function moveWithCollision(position: Point, delta: Point, radius: number): Point {
  const steps = Math.max(1, Math.ceil(Math.max(Math.abs(delta.x), Math.abs(delta.y)) / Math.max(1, radius / 2)));
  let current = { ...position };
  for (let step = 0; step < steps; step += 1) {
    const horizontal = clampToBounds({ x: current.x + delta.x / steps, y: current.y }, radius);
    if (!collides(horizontal, radius)) current.x = horizontal.x;
    const vertical = clampToBounds({ x: current.x, y: current.y + delta.y / steps }, radius);
    if (!collides(vertical, radius)) current.y = vertical.y;
  }
  return current;
}

export function isWalkable(position: Point, radius: number): boolean {
  const clamped = clampToBounds(position, radius);
  return clamped.x === position.x && clamped.y === position.y && !collides(position, radius);
}

export function repairPosition(position: Point, fallback: Point, radius: number): Point {
  if (isWalkable(position, radius)) return position;
  if (isWalkable(fallback, radius)) return fallback;
  throw new Error("Invalid world fallback position");
}

function clampToBounds(position: Point, radius: number): Point {
  return {
    x: Math.max(WORLD_BOUNDS.x + radius, Math.min(WORLD_BOUNDS.x + WORLD_BOUNDS.width - radius, position.x)),
    y: Math.max(WORLD_BOUNDS.y + radius, Math.min(WORLD_BOUNDS.y + WORLD_BOUNDS.height - radius, position.y))
  };
}

function collides(position: Point, radius: number): boolean {
  return WORLD_WALLS.some((wall) => {
    const nearestX = Math.max(wall.x, Math.min(wall.x + wall.width, position.x));
    const nearestY = Math.max(wall.y, Math.min(wall.y + wall.height, position.y));
    const dx = position.x - nearestX;
    const dy = position.y - nearestY;
    return dx * dx + dy * dy < radius * radius;
  });
}
