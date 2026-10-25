const { test } = require('node:test');
const assert = require('node:assert/strict');
const { documentId, validateValue, readSnapshot, copySnapshot } = require('../migrate-firestore.cjs');
test('composite keys and precision safeguards', () => {
  assert.notEqual(documentId({a:'a/b',b:'c'}, ['a','b']), documentId({a:'a',b:'b/c'}, ['a','b']));
  assert.throws(() => documentId({}, []));
  validateValue({ money: '9007199254740993', at: '2026-10-25 01:02:03.123456+00' });
  assert.throws(() => validateValue({ money: 9007199254740992 }));
  assert.throws(() => validateValue([[1]]));
});
test('snapshot rolls back rather than skipping tables without primary keys', async () => {
  const queries = [];
  const client = { query: async sql => {
    queries.push(sql);
    return { rows: sql.includes('information_schema.tables') ? [{table_name:'unknown'}] : [] };
  }};
  await assert.rejects(readSnapshot(client), /no primary key/);
  assert.equal(queries[0], 'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  assert.equal(queries.at(-1), 'ROLLBACK');
});
function target(corrupt = false) {
  const stored = new Map(), states = [];
  const collection = { doc: id => ({id}), get: async () => ({size:stored.size,
    docs:[...stored].map(([id,data]) => ({id, data:() => corrupt ? {...data,price:'0'} : data}))}) };
  const db = {collection:() => ({doc:() => ({create:async v => states.push(v.status),
    update:async v => states.push(v.status),collection:() => collection})}),
    batch:() => ({create:(ref,data) => stored.set(ref.id,data),commit:async () => {}})};
  return {db,states};
}
test('copy verifies field contents before declaring success', async () => {
  const snapshot = [{name:'services',keys:['id'],columns:[],
    rows:[{id:'hash',data:{id:'s1',price:'9007199254740993'}}]}];
  const ok = target();
  await copySnapshot(ok.db,'run',snapshot);
  assert.deepEqual(ok.states,['copying','verified']);
  const broken = target(true);
  await assert.rejects(copySnapshot(broken.db,'run',snapshot), /Verification failed/);
  assert.deepEqual(broken.states,['copying']);
});
