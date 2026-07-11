#!/usr/bin/env node

import { chromium } from 'playwright';
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const BASE_URL = 'https://zmsg1218.readbible365.com/';
const DEFAULT_OUTPUT = 'hymn.db';
const DEFAULT_SQLITE3 =
  'D:\\_devTools\\_supports\\free-reader-env\\android-sdk\\platform-tools\\sqlite3.exe';

const FALLBACK_RANGES = [
  { label: '001-050', start: 1, end: 50 },
  { label: '051-100', start: 51, end: 100 },
  { label: '101-150', start: 101, end: 150 },
  { label: '151-200', start: 151, end: 200 },
  { label: '201-250', start: 201, end: 250 },
  { label: '251-300', start: 251, end: 300 },
  { label: '301-350', start: 301, end: 350 },
  { label: '351-400', start: 351, end: 400 },
  { label: '401-450', start: 401, end: 450 },
  { label: '451-500', start: 451, end: 500 },
  { label: '501-550', start: 501, end: 550 },
  { label: '551-600', start: 551, end: 600 },
  { label: '601-650', start: 601, end: 650 },
  { label: '651-700', start: 651, end: 700 },
  { label: '701-750', start: 701, end: 750 },
  { label: '751-800', start: 751, end: 800 },
  { label: '801-850', start: 801, end: 850 },
  { label: '851-900', start: 851, end: 900 },
  { label: '901-950', start: 901, end: 950 },
  { label: '951-1000', start: 951, end: 1000 },
  { label: '1001-1050', start: 1001, end: 1050 },
  { label: '1051-1100', start: 1051, end: 1100 },
  { label: '1101-1150', start: 1101, end: 1150 },
  { label: '1151-1218', start: 1151, end: 1218 },
];

const args = parseArgs(process.argv.slice(2));
const outputPath = resolve(args.out ?? DEFAULT_OUTPUT);
const sqlite3Path = args.sqlite3 ?? process.env.SQLITE3_PATH ?? DEFAULT_SQLITE3;

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

async function main() {
  console.log(`Opening ${BASE_URL}`);
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
    const ranges = await readRanges(page);
    const scrapedAt = new Date().toISOString();
    const hymns = [];

    for (const range of ranges) {
      const jsonPath = `jsongs_${range.start}_${range.end}.json`;
      const jsonUrl = new URL(jsonPath, BASE_URL).toString();
      console.log(`Fetching ${range.label} ${jsonUrl}`);
      const rows = await page.evaluate(async (url) => {
        const response = await fetch(url, { cache: 'no-store' });
        if (!response.ok) {
          throw new Error(`HTTP ${response.status} ${url}`);
        }
        return response.json();
      }, jsonUrl);

      rows.forEach((song, index) => {
        const hymnNumber = range.start + index;
        const lyrics = pickText(song, [
          'lyrics',
          'lyric',
          'content',
          'text',
          'body',
          'words',
        ]);

        hymns.push({
          id: hymnNumber,
          sourceId: asNullableInteger(song.id),
          title: repairMojibake(pickText(song, ['title', 'name']) || `第${hymnNumber}首`),
          lyrics: repairMojibake(lyrics),
          content: repairMojibake(lyrics),
          audioUrl: pickText(song, ['url', 'audio_url', 'audioUrl', 'mp3']),
          notationUrl: pickText(song, ['nmn_url', 'notation_url', 'notationUrl', 'image']),
          rangeLabel: range.label,
          sourceUrl: jsonUrl,
          scrapedAt,
        });
      });
    }

    await browser.close();

    if (hymns.length === 0) {
      throw new Error('No hymns were scraped.');
    }

    writeDatabase({
      outputPath,
      sqlite3Path,
      ranges,
      hymns,
      scrapedAt,
    });

    const missingLyrics = hymns.filter((hymn) => !hymn.lyrics.trim()).length;
    console.log(`Done: ${outputPath}`);
    console.log(`Hymns: ${hymns.length}`);
    if (missingLyrics > 0) {
      console.warn(
        `Warning: ${missingLyrics} hymns have empty lyrics. The source JSON exposes title/audio/notation URLs but no text lyrics.`,
      );
    }
  } catch (error) {
    await browser.close();
    throw error;
  }
}

async function readRanges(page) {
  try {
    const ranges = await page.evaluate(() => MENU_RANGES);
    if (Array.isArray(ranges) && ranges.length > 0) {
      return ranges.map((range) => ({
        label: String(range.label),
        start: Number(range.start),
        end: Number(range.end),
      }));
    }
  } catch (_) {
    // Some browsers do not expose top-level const bindings to evaluate.
  }

  return FALLBACK_RANGES;
}

function writeDatabase({ outputPath, sqlite3Path, ranges, hymns, scrapedAt }) {
  if (!existsSync(sqlite3Path)) {
    throw new Error(`sqlite3 executable not found: ${sqlite3Path}`);
  }

  mkdirSync(dirname(outputPath), { recursive: true });
  if (existsSync(outputPath)) {
    rmSync(outputPath);
  }

  const sql = [
    'PRAGMA journal_mode = OFF;',
    'PRAGMA synchronous = OFF;',
    'BEGIN TRANSACTION;',
    `CREATE TABLE metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );`,
    `CREATE TABLE catalog (
      id INTEGER PRIMARY KEY,
      label TEXT NOT NULL,
      start_no INTEGER NOT NULL,
      end_no INTEGER NOT NULL
    );`,
    `CREATE TABLE hymn (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      lyrics TEXT NOT NULL DEFAULT '',
      content TEXT NOT NULL DEFAULT '',
      audio_url TEXT,
      notation_url TEXT,
      source_id INTEGER,
      range_label TEXT,
      source_url TEXT,
      scraped_at TEXT NOT NULL
    );`,
    'CREATE INDEX idx_hymn_title ON hymn(title);',
    insert('metadata', {
      key: 'name',
      value: '赞美诗歌1218',
    }),
    insert('metadata', {
      key: 'source',
      value: BASE_URL,
    }),
    insert('metadata', {
      key: 'scraped_at',
      value: scrapedAt,
    }),
    insert('metadata', {
      key: 'lyrics_note',
      value: 'Source JSON currently has no text lyrics field; lyrics/content are empty unless the source adds one later.',
    }),
    ...ranges.map((range, index) =>
      insert('catalog', {
        id: index + 1,
        label: range.label,
        start_no: range.start,
        end_no: range.end,
      }),
    ),
    ...hymns.map((hymn) => insert('hymn', hymn)),
    'COMMIT;',
  ].join('\n');

  const result = spawnSync(sqlite3Path, [outputPath], {
    input: sql,
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 10,
  });

  if (result.status !== 0) {
    throw new Error(
      [
        `sqlite3 failed with exit code ${result.status}`,
        result.stdout,
        result.stderr,
      ]
        .filter(Boolean)
        .join('\n'),
    );
  }
}

function insert(table, values) {
  const keys = Object.keys(values);
  return `INSERT INTO ${table} (${keys.join(', ')}) VALUES (${keys
    .map((key) => sqlValue(values[key]))
    .join(', ')});`;
}

function sqlValue(value) {
  if (value === null || value === undefined) {
    return 'NULL';
  }
  if (typeof value === 'number') {
    return Number.isFinite(value) ? String(value) : 'NULL';
  }
  return `'${String(value).replaceAll("'", "''")}'`;
}

function pickText(object, keys) {
  for (const key of keys) {
    const value = object?.[key];
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  return '';
}

function asNullableInteger(value) {
  const number = Number(value);
  return Number.isInteger(number) ? number : null;
}

function repairMojibake(value) {
  if (!value || !/[åæçèéäöüï¼]/.test(value)) {
    return value ?? '';
  }

  try {
    return Buffer.from(value, 'latin1').toString('utf8');
  } catch (_) {
    return value;
  }
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--out') {
      parsed.out = argv[++i];
    } else if (arg === '--sqlite3') {
      parsed.sqlite3 = argv[++i];
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return parsed;
}

function printHelp() {
  console.log(`Usage:
  node tools/scrape_hymn_1218.mjs [--out hymn.db] [--sqlite3 path/to/sqlite3]

Environment:
  SQLITE3_PATH  Optional sqlite3 executable path.

Notes:
  The target site currently exposes title, audio URL and notation image URL.
  It does not expose text lyrics in the JSON used by the page.
`);
}
