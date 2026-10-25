const { Timestamp } = require('firebase-admin/firestore');
const { createHash } = require('node:crypto');

const TABLES = ['appointment_services', 'appointments', 'auth_credentials', 'branches',
  'categories', 'promotions', 'reviews', 'services', 'shop_settings',
  'staff_leave_requests', 'staff_shifts', 'staff_specializations', 'users'];
const COLLECTIONS = ['users', 'auth_credentials', 'branches', 'categories', 'services',
  'appointments', 'staff_shifts', 'staff_leave_requests', 'promotions', 'reviews'];
const MIGRATION_ID = 'aiven-nosql-v1';
const camel = key => key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
function requireThat(condition, message) {
  if (!condition) throw new Error(message);
}
function safeId(value) {
  requireThat(typeof value === 'string' && value.length > 0 &&
    !value.includes('/') && !['.', '..'].includes(value) && !/^__.*__$/.test(value) &&
    Buffer.byteLength(value) <= 1500, 'Invalid Firestore document ID');
  return value;
}
function timestamp(value) {
  // Snapshot SET TIME ZONE UTC makes every TIMESTAMPTZ explicit; retain all six
  // PostgreSQL fractional digits instead of truncating through Date milliseconds.
  requireThat(typeof value === 'string', 'Timestamp must be PostgreSQL text');
  const match = /^(\d{4}-\d\d-\d\d)[ T](\d\d:\d\d:\d\d)(?:\.(\d{1,6}))?(Z|[+-]\d\d(?::?\d\d)?)$/.exec(value);
  requireThat(match, 'Timestamp requires an explicit UTC offset');
  const zone = match[4].length === 3 ? match[4] + ':00' : match[4];
  const seconds = Date.parse(match[1] + 'T' + match[2] + zone) / 1000;
  requireThat(Number.isSafeInteger(seconds), 'Invalid timestamp');
  return new Timestamp(seconds, Number((match[3] || '').padEnd(9, '0')));
}
function integer(value) {
  requireThat(typeof value === 'string' && /^-?\d+$/.test(value), 'Invalid BIGINT');
  const exact = BigInt(value);
  requireThat(exact >= -(1n << 63n) && exact < (1n << 63n), 'BIGINT outside int64');
  return exact >= BigInt(Number.MIN_SAFE_INTEGER) && exact <= BigInt(Number.MAX_SAFE_INTEGER)
    ? Number(exact) : exact;
}
function convert(value, column) {
  if (value === null) return null;
  switch (column.udt_name) {
    case 'timestamptz': return timestamp(value);
    case 'timestamp': throw new Error('Timezone-free timestamps require an explicit timezone mapping');
    case 'date':
      requireThat(typeof value === 'string' && /^\d{4}-\d\d-\d\d$/.test(value), 'Invalid calendar date');
      return value;
    case 'int8': return integer(value);
    case 'numeric':
      // No NUMERIC columns currently; preserve exact decimal text if introduced.
      requireThat(typeof value === 'string', 'Decimal must remain exact text');
      return value;
    default:
      if (column.udt_name.startsWith('_')) {
        requireThat(Array.isArray(value), 'SQL array expected');
        return value.map(item => convert(item, { udt_name: column.udt_name.slice(1) }));
      }
      requireThat(!(value instanceof Date), 'Unexpected Date object would lose source precision');
      return value;
  }
}
function rowDocument(row, columns) {
  requireThat(columns.length === Object.keys(row).length, 'Schema/row column mismatch');
  const document = {};
  for (const column of columns) {
    requireThat(Object.hasOwn(row, column.column_name), 'Missing source column');
    const key = camel(column.column_name);
    requireThat(!Object.hasOwn(document, key), 'Column mapping collision');
    document[key] = convert(row[column.column_name], column);
  }
  return document;
}
function canonical(value) {
  if (value instanceof Timestamp) return ['timestamp', value.seconds, value.nanoseconds];
  if (typeof value === 'bigint') return ['integer', value.toString()];
  if (typeof value === 'number' && Number.isInteger(value)) return ['integer', value.toString()];
  if (Array.isArray(value)) return ['array', value.map(canonical)];
  if (value && typeof value === 'object') return ['map', Object.keys(value).sort().map(key => [key, canonical(value[key])])];
  return [typeof value, value];
}
function checksum(docs) {
  return createHash('sha256').update(JSON.stringify([...docs]
    .sort((a, b) => a.id.localeCompare(b.id)).map(doc => [doc.id, canonical(doc.data)]))).digest('hex');
}
function buildPlan(snapshot) {
  requireThat(snapshot.length === TABLES.length &&
    TABLES.every(name => snapshot.filter(table => table.name === name).length === 1),
  'Unexpected source table set: refusing to omit data');
  const source = Object.fromEntries(snapshot.map(table => [table.name,
    table.rows.map(row => rowDocument(row.data, table.columns))]));
  const maps = Object.fromEntries(COLLECTIONS.map(name => [name, new Map()]));
  function add(collection, id, data) {
    safeId(id);
    requireThat(!maps[collection].has(id), 'Duplicate target document identity');
    maps[collection].set(id, data);
  }
  for (const name of ['users', 'branches', 'categories', 'services', 'appointments',
    'staff_shifts', 'staff_leave_requests', 'promotions']) {
    for (const row of source[name]) add(name, row.id, row);
  }
  const user = id => {
    const found = maps.users.get(id);
    requireThat(found, 'Dangling user reference');
    return found;
  };
  const branch = id => requireThat(maps.branches.has(id), 'Dangling branch reference');
  const category = id => requireThat(maps.categories.has(id), 'Dangling category reference');
  for (const person of maps.users.values()) {
    requireThat(!Object.hasOwn(person, 'specializedCategoryIds'), 'Reserved user field collision');
    person.specializedCategoryIds = [];
    if (person.branchId !== null) branch(person.branchId);
    requireThat((['staff', 'manager'].includes(person.role)) === (person.branchId !== null), 'User role/branch mismatch');
  }
  for (const row of source.staff_specializations) {
    const person = user(row.staffId);
    category(row.categoryId);
    requireThat(person.role === 'staff' && !person.specializedCategoryIds.includes(row.categoryId), 'Invalid specialization');
    person.specializedCategoryIds.push(row.categoryId);
  }
  for (const person of maps.users.values()) person.specializedCategoryIds.sort();
  for (const row of source.auth_credentials) {
    requireThat(user(row.userId).isApproved && typeof row.passwordHash === 'string' &&
      row.passwordHash.length > 0 && Number.isInteger(row.tokenVersion) && row.tokenVersion >= 0, 'Invalid credential');
    add('auth_credentials', row.userId, row);
  }
  for (const person of maps.users.values()) {
    requireThat(person.isApproved === maps.auth_credentials.has(person.id), 'Approval/credential mismatch');
  }
  for (const row of source.shop_settings) {
    branch(row.branchId);
    const found = maps.branches.get(row.branchId);
    requireThat(!found.settings, 'Duplicate branch settings');
    found.settings = row;
  }
  for (const row of maps.services.values()) category(row.categoryId);
  for (const row of maps.appointments.values()) {
    requireThat(!Object.hasOwn(row, 'services') && !Object.hasOwn(row, 'serviceIds'), 'Reserved appointment field collision');
    branch(row.branchId);
    requireThat(user(row.staffId).role === 'staff', 'Invalid appointment staff');
    if (row.customerId !== null) requireThat(user(row.customerId).role === 'customer', 'Invalid customer');
    requireThat(row.endAt.valueOf() > row.startAt.valueOf(), 'Invalid appointment interval');
    row.services = [];
    row.serviceIds = [];
  }
  for (const row of source.appointment_services) {
    const appointment = maps.appointments.get(row.appointmentId);
    requireThat(appointment && maps.services.has(row.serviceId), 'Dangling appointment service reference');
    requireThat(!appointment.services.some(item => item.position === row.position), 'Duplicate service position');
    appointment.services.push(row);
  }
  for (const appointment of maps.appointments.values()) {
    requireThat(appointment.services.length > 0, 'Appointment without services');
    appointment.services.sort((a, b) => a.position - b.position);
    appointment.serviceIds = appointment.services.map(item => item.serviceId);
  }
  for (const row of source.reviews) {
    const appointment = maps.appointments.get(row.appointmentId);
    requireThat(appointment && appointment.status === 'completed' &&
      appointment.customerId === row.customerId && ['branch', 'staff'].includes(row.targetType) &&
      row.targetId === (row.targetType === 'branch' ? appointment.branchId : appointment.staffId), 'Invalid review reference');
    add('reviews', row.appointmentId + '__' + row.targetType, row);
  }
  for (const name of ['staff_shifts', 'staff_leave_requests']) {
    for (const row of maps[name].values()) {
      branch(row.branchId);
      requireThat(user(row.staffId).role === 'staff' && row.endAt.valueOf() > row.startAt.valueOf(), 'Invalid workspace interval');
      if (name === 'staff_leave_requests' && row.reviewedBy !== null) user(row.reviewedBy);
    }
  }
  const collections = COLLECTIONS.map(name => ({ name,
    docs: [...maps[name]].map(([id, data]) => ({ id, data })) }));
  const summary = collections.map(collection => ({ name: collection.name,
    count: collection.docs.length, checksum: checksum(collection.docs) }));
  const totalDocs = summary.reduce((total, collection) => total + collection.count, 0);
  requireThat(totalDocs <= 450, 'Dataset exceeds single atomic migration limit (450 docs)');
  return { collections, summary, totalDocs,
    sourceCounts: snapshot.map(table => ({ name: table.name, count: table.rows.length })),
    embedded: { appointmentServices: source.appointment_services.length,
      specializations: source.staff_specializations.length, branchSettings: source.shop_settings.length } };
}
async function assertPrivateRules(app) {
  const { getSecurityRules } = require('firebase-admin/security-rules');
  const rules = await getSecurityRules(app).getFirestoreRuleset();
  const source = rules.source.map(file => file.content).join('\n')
    .replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '').replace(/\s/g, '');
  const expected = "rules_version='2';servicecloud.firestore{match/databases/{database}/documents{match/{document=**}{allowread,write:iffalse;}}}";
  requireThat(source === expected, 'Expected deny-all client rules before importing private data');
}
async function verifyCollections(db, summary) {
  for (const collection of summary) {
    const result = await db.collection(collection.name).get();
    const docs = result.docs.map(doc => ({ id: doc.id, data: doc.data() }));
    requireThat(BigInt(result.size) === BigInt(collection.count) && checksum(docs) === collection.checksum,
      'Verification failed for ' + collection.name);
    console.log(collection.name + ': ' + result.size + ' verified');
  }
}
async function writePlan(db, plan) {
  const marker = db.collection('_migrations').doc(MIGRATION_ID);
  requireThat(!(await marker.get()).exists, 'Migration already committed; use --verify');
  // Initial import only: do not overwrite any operational data.
  for (const collection of plan.collections) {
    requireThat((await db.collection(collection.name).limit(1).get()).empty,
      'Target collection is not empty: ' + collection.name);
  }
  const batch = db.batch();
  batch.create(marker, { schemaVersion: 1, status: 'committed',
    createdAt: Timestamp.now(), source: 'Aiven PostgreSQL public schema',
    collections: plan.summary, sourceCounts: plan.sourceCounts, embedded: plan.embedded,
    totalDocuments: plan.totalDocs, backendCutover: false });
  for (const collection of plan.collections) {
    for (const doc of collection.docs) batch.create(db.collection(collection.name).doc(doc.id), doc.data);
  }
  await batch.commit();
  await verifyCollections(db, plan.summary);
  await marker.update({ status: 'verified', verifiedAt: Timestamp.now() });
}
module.exports = { TABLES, COLLECTIONS, MIGRATION_ID, timestamp, integer, rowDocument,
  canonical, checksum, buildPlan, assertPrivateRules, verifyCollections, writePlan };
