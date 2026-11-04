import { createHash } from 'node:crypto';
import { parseAppleFeed, type ChartSnapshot, type ChartType } from './discovery.ts';

export interface FetchOpts { country?: string; chart?: ChartType; limit?: number; fetchImpl?: typeof fetch; now?: () => Date }

/** Live Apple public chart provider (no credentials needed). */
export async function fetchAppleChart(o: FetchOpts = {}): Promise<ChartSnapshot> {
  const country = (o.country ?? 'us').toLowerCase();
  const chart = o.chart ?? 'top-free';
  const limit = o.limit ?? 25;
  if (!/^[a-z]{2}$/.test(country)) throw new Error('country must be a 2-letter code');
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) throw new Error('limit must be 1-100');
  const url = `https://rss.marketingtools.apple.com/api/v2/${country}/apps/${chart}/${limit}/apps.json`;
  const res = await (o.fetchImpl ?? fetch)(url);
  if (!res.ok) throw new Error(`Apple feed HTTP ${res.status}`);
  const raw = await res.text();
  return parseAppleFeed(JSON.parse(raw), {
    country, chart, sourceUrl: url, fetchedAt: (o.now?.() ?? new Date()).toISOString(),
    rawHash: createHash('sha256').update(raw).digest('hex'),
  });
}
