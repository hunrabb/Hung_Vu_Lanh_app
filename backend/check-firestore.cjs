require('dotenv/config');
const { initializeApp, applicationDefault, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getSecurityRules } = require('firebase-admin/security-rules');

(async () => {
  if (!process.env.FIREBASE_PROJECT_ID || !process.env.FIRESTORE_DATABASE_ID) {
    throw new Error('Set FIREBASE_PROJECT_ID and FIRESTORE_DATABASE_ID');
  }
  const app = initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID,
    credential: applicationDefault() });
  try {
    const { v1 } = require('@google-cloud/firestore');
    const admin = new v1.FirestoreAdminClient();
    try {
      const [databases] = await admin.listDatabases({ parent: 'projects/' + process.env.FIREBASE_PROJECT_ID });
      console.log('Available databases: ' + JSON.stringify(databases.databases?.map(database => ({
        name: database.name, type: database.type, state: database.state,
      }))));
    } catch (error) {
      console.error('Database metadata check failed: ' + error.code + ' ' + error.message);
    } finally { await admin.close(); }
    try {
      const rules = await getSecurityRules(app).getFirestoreRuleset();
      for (const file of rules.source) console.log(file.content);
    } catch (error) {
      console.error('Rules check failed: ' + error.code + ' ' + error.message);
    }
    const db = getFirestore(app, process.env.FIRESTORE_DATABASE_ID);
    const sample = await db.collection('aiven_imports').limit(1).get();
    console.log('Firestore connection OK; prior staging runs sampled: ' + sample.size);
  } finally { await deleteApp(app); }
})().catch(error => {
  console.error('Firebase check failed: ' + error.code + ' ' + error.message);
  process.exitCode = 1;
});
