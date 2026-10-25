require('dotenv/config');
const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');
const { readSnapshot } = require('./migrate-firestore.cjs');
const { buildPlan, assertPrivateRules, writePlan, verifyCollections, MIGRATION_ID } = require('./firestore-nosql.cjs');

async function main() {
  const args = process.argv.slice(2);
  if (args.length > 1 || args.some(arg => !['--write', '--verify'].includes(arg))) {
    throw new Error('Usage: node migrate-nosql.cjs [--write|--verify]');
  }
  let app, db;
  try {
    if (args.length) {
      if (!process.env.FIREBASE_PROJECT_ID || !process.env.FIRESTORE_DATABASE_ID) {
        throw new Error('Explicit Firebase project and database IDs required');
      }
      const { initializeApp, applicationDefault } = require('firebase-admin/app');
      const { getFirestore } = require('firebase-admin/firestore');
      app = initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID, credential: applicationDefault() });
      db = getFirestore(app, process.env.FIRESTORE_DATABASE_ID);
      db.settings({ useBigInt: true });
      await assertPrivateRules(app);
    }
    if (args.includes('--verify')) {
      const marker = db.collection('_migrations').doc(MIGRATION_ID);
      const record = await marker.get();
      if (!record.exists) throw new Error('No committed NoSQL migration');
      await verifyCollections(db, record.data().collections);
      await marker.update({ status: 'verified', verifiedAt: require('firebase-admin/firestore').Timestamp.now() });
      console.log('NoSQL import verified; NestJS still uses PostgreSQL.');
      return;
    }
    const client = new Client({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT),
      database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASSWORD,
      ssl: { rejectUnauthorized: true, ca: fs.readFileSync(path.join(__dirname, 'ca.pem'), 'utf8') } });
    let snapshot;
    try { await client.connect(); snapshot = await readSnapshot(client); }
    finally { await client.end(); }
    const plan = buildPlan(snapshot);
    console.log(JSON.stringify({ source: plan.sourceCounts, target: plan.summary.map(({name,count}) => ({name,count})),
      totalDocuments: plan.totalDocs, embedded: plan.embedded }));
    if (args.includes('--write')) {
      await writePlan(db, plan);
      console.log('NoSQL import complete and verified; NestJS still uses PostgreSQL.');
    } else console.log('Dry run: source is read-only, no Firestore writes.');
  } finally {
    if (app) await require('firebase-admin/app').deleteApp(app);
  }
}
main().catch(error => {
  // Only our validation errors have no code. SDK/SQL errors may contain data.
  console.error('NoSQL migration stopped: ' + (error.code || error.message));
  process.exitCode = 1;
});
