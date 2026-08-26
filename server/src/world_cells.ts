import mapData from "../../client/data/world_map.json";

export interface Point { x: number; y: number; }
export interface Rect extends Point { width: number; height: number; }
export interface WorldCell { id: string; x: number; y: number; districtId: string; }
export interface District { id: string; materialFamily: string; landmark: string; threatProfile: string; resourceProfile: string; }
export interface WorldDescriptorV2 {
  schemaVersion: 2;
  worldId: string;
  cellSize: number;
  bounds: Rect;
  cells: WorldCell[];
  districts: District[];
  walls: Rect[];
  spawnPoints: Point[];
  pointsOfInterest: Point[];
}

const legacy = mapData as typeof mapData & { schemaVersion?: number; worldId?: string; cellSize?: number; cells?: WorldCell[]; districts?: District[]; spawnPoints?: Point[]; pointsOfInterest?: Point[] };
export const WORLD_CELL_SIZE = legacy.cellSize ?? 32;

export function getCellId(x: number, y: number): string {
  return `${Math.floor(x / WORLD_CELL_SIZE)}:${Math.floor(y / WORLD_CELL_SIZE)}`;
}

export function getCellDescriptor(id: string): WorldCell | undefined {
  return normalizeWorldDescriptor().cells.find((cell) => cell.id === id);
}

export function normalizeWorldDescriptor(): WorldDescriptorV2 {
  const cells = legacy.cells ?? [];
  const districts = legacy.districts ?? [{ id: "legacy", materialFamily: "concrete", landmark: "legacy-world", threatProfile: "mixed", resourceProfile: "mixed" }];
  return {
    schemaVersion: 2,
    worldId: legacy.worldId ?? "deadworld-main",
    cellSize: WORLD_CELL_SIZE,
    bounds: legacy.bounds,
    cells,
    districts,
    walls: legacy.walls,
    spawnPoints: legacy.spawnPoints ?? [],
    pointsOfInterest: legacy.pointsOfInterest ?? []
  };
}
