// Copies a consistent PostgreSQL snapshot into an isolated Firestore staging run.
// Does not switch the API database or modify PostgreSQL.
require('dotenv/config');
const fs = require('node:fs');
const path = require('node:path');
const { createHash, randomUUID } = require('node:crypto');
const { Client, types } = require('pg');
const { isDeepStrictEqual } = require('node:util');

// Preserve microseconds, timezone offsets, BIGINT and NUMERIC exactly as text.
// PostgreSQL dates are deliberately not passed through JavaScript Date/Number.
for (const oid of [1082, 1114, 1184, 20, 1700]) types.setTypeParser(oid, value => value);
const quote = value => '"' + value.replaceAll('"', '""') + '"';
function documentId(row, keys) {
  if (!keys.length || keys.some(key => row[key] == null)) {
    throw new Error('Every source table requires a non-null primary key');
  }
  return createHash('sha256').update(JSON.stringify(keys.map(key => row[key]))).digest('hex');
}
function validateValue(value) {
  if (typeof value === 'number' && (!Number.isFinite(value) ||
      (Number.isInteger(value) && !Number.isSafeInteger(value)))) {
    throw new Error('Unsafe numeric value; source was not copied');
  }
  if (Buffer.isBuffer(value)) throw new Error('Binary columns require an explicit mapping');
  if (Array.isArray(value)) {
    if (value.some(Array.isArray)) throw new Error('Nested arrays require an explicit mapping');
    value.forEach(validateValue);
  } else if (value && typeof value === 'object') {
    Object.values(value).forEach(validateValue);
  }
}
async function readSnapshot(client) {
  await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  try {
    await client.query("SET LOCAL TIME ZONE 'UTC'");
    const tables = await client.query(`SELECT table_name FROM information_schema.tables
      WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name`);
    const snapshot = [];
    for (const { table_name: name } of tables.rows) {
      const columns = await client.query(`SELECT column_name, data_type, udt_name
        FROM information_schema.columns WHERE table_schema='public' AND table_name=$1
        ORDER BY ordinal_position`, [name]);
      const primary = await client.query(`SELECT a.attname AS name
        FROM pg_index i
        CROSS JOIN LATERAL unnest(i.indkey) WITH ORDINALITY AS k(attnum, position)
        JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=k.attnum
        WHERE i.indrelid=$1::regclass AND i.indisprimary ORDER BY k.position`,
      ['public.' + quote(name)]);
      const keys = primary.rows.map(row => row.name);
      if (!keys.length) throw new Error('Source table has no primary key: ' + name);
      // pg otherwise turns DATE[] into JavaScript Date objects in local time.
      const projection = columns.rows.map(column => {
        const field = quote(column.column_name);
        return ['_date', '_timestamp', '_timestamptz'].includes(column.udt_name)
          ? field + '::text[] AS ' + field : field;
      }).join(', ');
      const result = await client.query('SELECT ' + projection + ' FROM public.' + quote(name));
      const rows = result.rows.map(row => {
        validateValue(row);
        return { id: documentId(row, keys), data: row };
      });
      snapshot.push({ name, keys, columns: columns.rows, rows });
    }
    await client.query('COMMIT');
    return snapshot;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  }
}
async function copySnapshot(db, runId, snapshot) {
  const run = db.collection('aiven_imports').doc(runId);
  // create() refuses to overwrite a previous run, including a partial import.
  await run.create({ status: 'copying', createdAt: new Date().toISOString(),
    tables: snapshot.map(table => ({ name: table.name, primaryKey: table.keys,
      columns: table.columns, count: table.rows.length })) });
  for (const table of snapshot) {
    const collection = run.collection(table.name);
    for (let offset = 0; offset < table.rows.length; offset += 100) {
      const batch = db.batch();
      for (const row of table.rows.slice(offset, offset + 100)) {
        batch.create(collection.doc(row.id), row.data);
      }
      await batch.commit();
    }
    const copied = await collection.get();
    const expected = new Map(table.rows.map(row => [row.id, row.data]));
    if (copied.size !== expected.size || copied.docs.some(doc =>
      !isDeepStrictEqual(doc.data(), expected.get(doc.id)))) {
      throw new Error('Verification failed for table: ' + table.name);
    }
    console.log(table.name + ': ' + copied.size + ' verified');
  }
  await run.update({ status: 'verified', verifiedAt: new Date().toISOString() });
}
async function main() {
  const args = process.argv.slice(2);
  if (args.some(arg => arg !== '--write')) throw new Error('Usage: node migrate-firestore.cjs [--write]');
  const write = args.includes('--write');
  let db;
  let app;
  if (write) {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const databaseId = process.env.FIRESTORE_DATABASE_ID;
    if (!projectId || !databaseId) throw new Error('Set FIREBASE_PROJECT_ID and FIRESTORE_DATABASE_ID explicitly');
    const { initializeApp, applicationDefault } = require('firebase-admin/app');
    const { getFirestore } = require('firebase-admin/firestore');
    app = initializeApp({ projectId, credential: applicationDefault() });
    db = getFirestore(app, databaseId);
    // Check credentials/database before reading source customer data.
    await db.collection('aiven_imports').limit(1).get();
  }
  const client = new Client({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT),
    database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASSWORD,
    ssl: { rejectUnauthorized: true, ca: fs.readFileSync(path.join(__dirname, 'ca.pem'), 'utf8') } });
  try {
    await client.connect();
    const snapshot = await readSnapshot(client);
    console.log(JSON.stringify(snapshot.map(table => ({ table: table.name, count: table.rows.length }))));
    if (write) {
      const runId = randomUUID();
      console.log('Staging run: ' + runId);
      await copySnapshot(db, runId, snapshot);
      console.log('Snapshot verified. NestJS still uses PostgreSQL.');
    } else console.log('Dry run completed; no Firestore writes.');
  } finally {
    await client.end();
    if (app) await require('firebase-admin/app').deleteApp(app);
  }
}
module.exports = { documentId, validateValue, readSnapshot, copySnapshot };
if (require.main === module) main().catch(error => {
  // Avoid logging connection strings, row contents or credential material.
  console.error('Migration stopped: ' + (error.code || 'VALIDATION_OR_CONFIGURATION'));
  process.exitCode = 1;
});
