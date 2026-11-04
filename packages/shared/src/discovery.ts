export type Platform = 'ios' | 'android';
export type ChartType = 'top-free' | 'top-paid';

export interface AppRecord {
  /** Canonical key: `${platform}:${storeId}` */
  key: string;
  platform: Platform;
  storeId: string;
  name: string;
  developer: string;
  genres: string[];
  releaseDate?: string;
  iconUrl?: string;
  storeUrl?: string;
  /** Always true for discovered third-party apps. */
  unaffiliated: boolean;
}

export interface RankEntry { key: string; rank: number }

export interface ChartSnapshot {
  provider: string;
  country: string;
  chart: ChartType;
  capturedAt: string; // ISO, from the source's own "updated" time when present
  fetchedAt: string;
  sourceUrl: string;
  entries: RankEntry[];
  apps: AppRecord[];
  /** sha-256 of the raw payload, for evidence */
  rawHash: string;
}

export interface Movement {
  key: string;
  currentRank: number | null;
  previousRank: number | null;
  /** positive = climbed. null when not in both snapshots (new entry or dropped). */
  change: number | null;
  isNew: boolean;
}

export function normalizeStoreId(raw: unknown): string {
  const s = String(raw ?? '').trim().replace(/^id/i, '');
  if (!/^\d+$/.test(s)) throw new Error(`Invalid Apple store id: ${JSON.stringify(raw)}`);
  return s;
}

interface AppleResult {
  id: string; name: string; artistName: string; releaseDate?: string;
  artworkUrl100?: string; url?: string; genres?: { name: string }[];
}

/** Pure: convert an Apple RSS v2 payload into a snapshot. Deduplicates by canonical key, keeping best rank. */
export function parseAppleFeed(
  payload: any, meta: { country: string; chart: ChartType; sourceUrl: string; fetchedAt: string; rawHash: string },
): ChartSnapshot {
  const results: AppleResult[] | undefined = payload?.feed?.results;
  if (!Array.isArray(results)) throw new Error('Unexpected Apple feed shape: feed.results missing');
  const updated = payload.feed.updated ? new Date(payload.feed.updated) : null;
  const capturedAt = updated && !isNaN(updated.getTime()) ? updated.toISOString() : meta.fetchedAt;
  const seen = new Set<string>();
  const entries: RankEntry[] = [];
  const apps: AppRecord[] = [];
  results.forEach((r, i) => {
    const storeId = normalizeStoreId(r.id);
    const key = `ios:${storeId}`;
    if (seen.has(key)) return;
    seen.add(key);
    entries.push({ key, rank: entries.length + 1 });
    apps.push({
      key, platform: 'ios', storeId, name: r.name, developer: r.artistName,
      genres: (r.genres ?? []).map(g => g.name), releaseDate: r.releaseDate,
      iconUrl: r.artworkUrl100, storeUrl: r.url, unaffiliated: true,
    });
    void i;
  });
  return { ...meta, provider: 'apple-rss', capturedAt, entries, apps };
}

/** Compare two snapshots of the same chart. Never invents data: apps absent from either side get change=null. */
export function computeMovements(previous: ChartSnapshot | null, current: ChartSnapshot): Movement[] {
  if (previous && (previous.country !== current.country || previous.chart !== current.chart)) {
    throw new Error('Snapshots are from different charts');
  }
  const prev = new Map(previous?.entries.map(e => [e.key, e.rank]));
  return current.entries.map(e => {
    const p = prev.get(e.key) ?? null;
    return { key: e.key, currentRank: e.rank, previousRank: p, change: p === null ? null : p - e.rank, isNew: previous !== null && p === null };
  });
}

/** Fastest climbers = largest positive change among apps present in both snapshots. */
export function fastestClimbers(movements: Movement[], limit = 10): Movement[] {
  return movements.filter(m => m.change !== null && m.change > 0)
    .sort((a, b) => (b.change! - a.change!) || (a.currentRank! - b.currentRank!)).slice(0, limit);
}

export function freshness(snapshot: ChartSnapshot, now: Date, staleAfterHours = 26): { ageHours: number; stale: boolean } {
  const ageHours = (now.getTime() - new Date(snapshot.capturedAt).getTime()) / 3_600_000;
  return { ageHours, stale: ageHours > staleAfterHours };
}
