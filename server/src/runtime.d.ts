declare namespace nkruntime {
  interface Context { userId?: string; }
  interface Logger { info(message: string, ...args: unknown[]): void; warn(message: string, ...args: unknown[]): void; }
  interface StorageObject { value: Record<string, unknown>; version: string; }
  interface StorageWriteRequest { collection: string; key: string; userId: string; value: Record<string, unknown>; version?: string; permissionRead: number; permissionWrite: number; }
  interface StorageWriteAck { version: string; }
  interface Nakama { matchList(limit: number, authoritative: boolean, label?: string | null, minSize?: number, maxSize?: number, query?: string): Match[]; matchGet(matchId: string): Match | null; matchCreate(module: string, params?: Record<string, unknown>): string; matchSignal(matchId: string, data: string): string; storageRead(objects: { collection: string; key: string; userId: string }[]): StorageObject[]; storageWrite(objects: StorageWriteRequest[]): StorageWriteAck[]; storageDelete(objects: { collection: string; key: string; userId: string; version?: string }[]): void; uuidv4(): string; }
  interface Initializer { registerMatch(name: string, handler: MatchHandler): void; registerRpc(name: string, fn: RpcFunction): void; }
  interface Match { matchId: string; }
  interface Presence { userId: string; sessionId: string; username: string; }
  interface MatchMessage { opCode: number; data: string | ArrayBuffer | Uint8Array; sender: Presence; }
  interface MatchDispatcher { broadcastMessage(opCode: number, data: string, presences?: Presence[] | null, sender?: Presence | null, reliable?: boolean): void; matchLabelUpdate(label: string): void; }
  interface MatchState { [key: string]: unknown; }
  interface MatchHandler {
    matchInit(ctx: Context, logger: Logger, nk: Nakama, params: Record<string, unknown>): { state: MatchState; tickRate: number; label: string };
    matchJoinAttempt(ctx: Context, logger: Logger, nk: Nakama, dispatcher: MatchDispatcher, tick: number, state: MatchState, presence: Presence, metadata: Record<string, unknown>): { state: MatchState; accept: boolean; rejectMessage?: string } | null;
    matchJoin(ctx: Context, logger: Logger, nk: Nakama, dispatcher: MatchDispatcher, tick: number, state: MatchState, presences: Presence[]): { state: MatchState } | null;
    matchLeave(ctx: Context, logger: Logger, nk: Nakama, dispatcher: MatchDispatcher, tick: number, state: MatchState, presences: Presence[]): { state: MatchState } | null;
    matchLoop(ctx: Context, logger: Logger, nk: Nakama, dispatcher: MatchDispatcher, tick: number, state: MatchState, messages: MatchMessage[]): { state: MatchState } | null;
    matchTerminate(ctx: Context, logger: Logger, nk: Nakama, dispatcher: MatchDispatcher, tick: number, state: MatchState, graceSeconds: number): { state: MatchState } | null;
    matchSignal(ctx: Context, logger: Logger, nk: Nakama, dispatcher: MatchDispatcher, tick: number, state: MatchState, data: string): { state: MatchState; data?: string } | null;
  }
  type RpcFunction = (ctx: Context, logger: Logger, nk: Nakama, payload: string) => string;
}

declare let InitModule: (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, initializer: nkruntime.Initializer) => void;
