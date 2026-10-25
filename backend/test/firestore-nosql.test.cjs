const { test } = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');
const { TABLES, timestamp, integer, checksum, buildPlan, writePlan,
  verifyCollections, rowDocument } = require('../firestore-nosql.cjs');
const { readSnapshot } = require('../migrate-firestore.cjs');

const at = '2026-10-25 01:02:03.123456+00';
const end = '2026-10-25 02:02:03.123456+00';
function snapshot() {
  const rows = {
    branches: [{id:'b1',name:'Branch'}],
    categories: [{id:'haircut',name:'Cut'},{id:'dye',name:'Dye'}],
    users: [
      {id:'s1',role:'staff',branch_id:'b1',is_approved:true,name:'Staff',created_at:at},
      {id:'c1',role:'customer',branch_id:null,is_approved:true,name:'Customer',created_at:at},
      {id:'m1',role:'manager',branch_id:'b1',is_approved:true,name:'Manager',created_at:at},
    ],
    auth_credentials: ['s1','c1','m1'].map(user_id => ({user_id,password_hash:'unchanged-hash',token_version:7})),
    services: [
      {id:'v1',name:'New name',category_id:'haircut',price_vnd:'9007199254740993'},
      {id:'v2',name:'Dye',category_id:'dye',price_vnd:'500000'},
    ],
    appointments: [{id:'a1',branch_id:'b1',staff_id:'s1',customer_id:'c1',
      status:'completed',start_at:at,end_at:end,total_price_vnd:'9007199255240993',
      is_hidden_by_customer:true,is_hidden_by_staff:false,is_reviewed:true,rating:4}],
    appointment_services: [
      {appointment_id:'a1',position:1,service_id:'v2',service_name_snapshot:'Old dye name'},
      {appointment_id:'a1',position:0,service_id:'v1',service_name_snapshot:'Historical cut name'},
    ],
    staff_specializations: [{staff_id:'s1',category_id:'dye'},{staff_id:'s1',category_id:'haircut'}],
    shop_settings: [{id:'default',branch_id:'b1',opening_minute:480,closing_minute:1200,
      closed_weekdays:[7],closed_dates:['2026-10-25']}],
    staff_shifts: [{id:'shift1',staff_id:'s1',branch_id:'b1',start_at:at,end_at:end}],
    staff_leave_requests: [{id:'leave1',staff_id:'s1',branch_id:'b1',staff_name:'Snapshot Staff',
      start_at:at,end_at:end,leave_date:'2026-10-25',created_at:at,status:'approved',
      reviewed_by:'m1',reviewed_at:end,reviewed_by_name:'Snapshot Manager',reason:'Reason',note:'Note'}],
    reviews: ['branch','staff'].map(target_type => ({appointment_id:'a1',target_type,
      target_id:target_type === 'branch' ? 'b1' : 's1',customer_id:'c1',rating:4,comment:'Review',created_at:at})),
    promotions: [{id:'p1',title:'Title',subtitle:'Subtitle',image_url:'',is_active:true}],
  };
  const type = key => key.endsWith('_at') ? 'timestamptz' :
    key.endsWith('_vnd') ? 'int8' : key === 'closed_dates' ? '_date' :
    key === 'closed_weekdays' ? '_int2' : key === 'leave_date' ? 'date' : 'text';
  return TABLES.map(name => ({name,keys:[],columns:Object.keys(rows[name][0]).map(column_name =>
    ({column_name,udt_name:type(column_name)})),rows:rows[name].map(data => ({data}))}));
}
const find = (plan, name, id) => plan.collections.find(c => c.name === name).docs.find(d => d.id === id).data;
test('all source tables map to native documents with ordered snapshots and private credentials', () => {
  const source = snapshot();
  const plan = buildPlan(source);
  const appointment = find(plan,'appointments','a1');
  assert.deepEqual(appointment.serviceIds,['v1','v2']);
  assert.equal(appointment.services[0].serviceNameSnapshot,'Historical cut name');
  assert.equal(appointment.isHiddenByCustomer,true);
  assert.equal(appointment.isHiddenByStaff,false);
  assert.equal(appointment.totalPriceVnd,9007199255240993n);
  assert.equal(appointment.startAt.nanoseconds,123456000);
  assert.equal(appointment.startAt.seconds,Timestamp.fromDate(new Date('2026-10-25T01:02:03Z')).seconds);
  assert.deepEqual(find(plan,'users','s1').specializedCategoryIds,['dye','haircut']);
  assert.equal(find(plan,'users','s1').passwordHash,undefined);
  assert.deepEqual(find(plan,'auth_credentials','s1'),{userId:'s1',passwordHash:'unchanged-hash',tokenVersion:7});
  assert.deepEqual(find(plan,'branches','b1').settings.closedDates,['2026-10-25']);
  assert.equal(find(plan,'staff_leave_requests','leave1').reviewedByName,'Snapshot Manager');
  assert.equal(find(plan,'reviews','a1__staff').targetId,'s1');
  // Every source row is represented exactly once, either standalone or embedded.
  const total = source.reduce((sum,table) => sum + table.rows.length,0);
  assert.equal(plan.totalDocs + Object.values(plan.embedded).reduce((a,b) => a+b,0),total);
});
test('unknown tables, missing relationships, missing credentials and unsafe IDs block migration', () => {
  assert.throws(() => buildPlan([...snapshot(),{name:'new_table',rows:[]}]),/table set/);
  const orphan = snapshot();
  orphan.find(t => t.name === 'appointment_services').rows[0].data.service_id = 'missing';
  assert.throws(() => buildPlan(orphan),/Dangling/);
  const missing = snapshot();
  missing.find(t => t.name === 'auth_credentials').rows.pop();
  assert.throws(() => buildPlan(missing),/credential mismatch/);
  const invalid = snapshot();
  invalid.find(t => t.name === 'promotions').rows[0].data.id = 'bad/id';
  assert.throws(() => buildPlan(invalid),/document ID/);
});
test('int64 and timestamp conversion retain precision and reject ambiguous values', () => {
  assert.equal(integer('9223372036854775807'),9223372036854775807n);
  assert.equal(integer('500000'),500000);
  assert.throws(() => integer('9223372036854775808'),/int64/);
  assert.throws(() => timestamp('2026-10-25 01:02:03'),/offset/);
  assert.equal(timestamp('2026-10-25 08:02:03.123456+07').seconds,timestamp(at).seconds);
  assert.equal(timestamp('1969-12-31 23:59:59.123456+00').seconds,-1);
  assert.throws(() => rowDocument({x:new Date()},[{column_name:'x',udt_name:'date'}]),/date/);
});
test('checksum and verifier handle SDK bigint reads, map ordering and tampering', async () => {
  const docs = [{id:'x',data:{price:500000,startAt:timestamp(at),nested:{a:1,b:2}}}];
  const actual = [{id:'x',data:{nested:{b:2n,a:1n},startAt:timestamp(at),price:500000n}}];
  assert.equal(checksum(docs),checksum(actual));
  const summary = [{name:'services',count:1n,checksum:checksum(docs)}];
  const db = {collection:() => ({get:async () => ({size:1,docs:actual.map(d => ({id:d.id,data:() => d.data}))})})};
  await verifyCollections(db,summary);
  actual[0].data.price = 500001n;
  await assert.rejects(verifyCollections(db,summary),/Verification failed/);
});
test('existing collections and migration marker stop writes before committing', async () => {
  const plan = buildPlan(snapshot());
  const existing = {collection:() => ({doc:() => ({get:async () => ({exists:true})})})};
  await assert.rejects(writePlan(existing,plan),/already committed/);
  let commits = 0;
  const notEmpty = {collection:() => ({doc:() => ({get:async () => ({exists:false})}),
    limit:() => ({get:async () => ({empty:false})})}),batch:() => ({commit:async () => commits++})};
  await assert.rejects(writePlan(notEmpty,plan),/not empty/);
  assert.equal(commits,0);
});
test('DATE arrays are read as calendar strings instead of host timezone Date objects', async () => {
  const queries = [];
  const client = {query:async sql => {
    queries.push(sql);
    if (sql.includes('information_schema.tables')) return {rows:[{table_name:'shop_settings'}]};
    if (sql.includes('information_schema.columns')) return {rows:[{column_name:'closed_dates',udt_name:'_date'}]};
    if (sql.includes('pg_index')) return {rows:[{name:'closed_dates'}]};
    if (sql.startsWith('SELECT "closed_dates"')) return {rows:[{closed_dates:['2026-10-25']}]};
    return {rows:[]};
  }};
  await readSnapshot(client);
  assert.ok(queries.includes('SET LOCAL TIME ZONE \'UTC\''));
  assert.ok(queries.some(sql => sql.includes('"closed_dates"::text[] AS "closed_dates"')));
});
