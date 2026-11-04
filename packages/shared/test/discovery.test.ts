import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseAppleFeed, computeMovements, fastestClimbers, normalizeStoreId, freshness, fetchAppleChart, type ChartSnapshot } from '../src/index.ts';

const meta = { country: 'us', chart: 'top-free' as const, sourceUrl: 'fixture', fetchedAt: '2026-11-04T01:00:00.000Z', rawHash: 'x' };
const fixture = JSON.parse(readFileSync(new URL('../fixtures/apple-us-top-free-25.json', import.meta.url), 'utf8'));

test('parses real Apple fixture with ranks 1..N and unaffiliated flag', () => {
  const s = parseAppleFeed(fixture, meta);
  assert.equal(s.entries.length, fixture.feed.results.length);
  assert.equal(s.entries[0].rank, 1);
  assert.ok(s.apps.every(a => a.unaffiliated && a.key.startsWith('ios:')));
  assert.equal(s.capturedAt, new Date(fixture.feed.updated).toISOString());
});

test('normalizes store ids and rejects garbage', () => {
  assert.equal(normalizeStoreId('id123'), '123');
  assert.equal(normalizeStoreId(' 456 '), '456');
  assert.throws(() => normalizeStoreId('abc'));
});

test('dedupes repeated apps, keeping best rank', () => {
  const r = { id: '1', name: 'A', artistName: 'D' };
  const s = parseAppleFeed({ feed: { results: [r, { id: 'id2', name: 'B', artistName: 'D' }, r] } }, meta);
  assert.deepEqual(s.entries.map(e => e.key), ['ios:1', 'ios:2']);
});

test('rejects malformed payload', () => assert.throws(() => parseAppleFeed({}, meta), /feed.results/));

const snap = (keys: string[]): ChartSnapshot => ({ ...parseAppleFeed({ feed: { results: [] } }, meta), entries: keys.map((key, i) => ({ key, rank: i + 1 })) });

test('movement: climbers, fallers, new entries; no invented data', () => {
  const m = computeMovements(snap(['a', 'b', 'c']), snap(['c', 'a', 'd']));
  const by = Object.fromEntries(m.map(x => [x.key, x]));
  assert.equal(by.c.change, 2);
  assert.equal(by.a.change, -1);
  assert.equal(by.d.change, null);
  assert.equal(by.d.isNew, true);
  assert.deepEqual(fastestClimbers(m).map(x => x.key), ['c']);
});

test('first ever snapshot has no movement and no "new" claims', () => {
  const m = computeMovements(null, snap(['a']));
  assert.equal(m[0].change, null);
  assert.equal(m[0].isNew, false);
});

test('rejects comparing different charts', () => {
  const other = { ...snap(['a']), country: 'gb' };
  assert.throws(() => computeMovements(other, snap(['a'])));
});

test('freshness flags stale data', () => {
  const s = parseAppleFeed(fixture, meta);
  const base = new Date(s.capturedAt).getTime();
  assert.equal(freshness(s, new Date(base + 3_600_000)).stale, false);
  assert.equal(freshness(s, new Date(base + 48 * 3_600_000)).stale, true);
});

test('fetch provider validates input and surfaces HTTP errors', async () => {
  await assert.rejects(fetchAppleChart({ country: 'usa' }), /country/);
  await assert.rejects(fetchAppleChart({ limit: 0 }), /limit/);
  await assert.rejects(fetchAppleChart({ fetchImpl: (async () => new Response('no', { status: 503 })) as any }), /503/);
});

test('fetch provider hashes raw payload and builds snapshot (mocked transport)', async () => {
  const raw = JSON.stringify(fixture);
  const s = await fetchAppleChart({ fetchImpl: (async () => new Response(raw)) as any, now: () => new Date('2026-11-04T02:00:00Z') });
  assert.match(s.rawHash, /^[0-9a-f]{64}$/);
  assert.equal(s.fetchedAt, '2026-11-04T02:00:00.000Z');
});
