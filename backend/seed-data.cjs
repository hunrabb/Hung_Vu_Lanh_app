require('dotenv/config');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Client } = require('pg');

const file = path.join(__dirname,'../database/003_seed_mock_data.sql');
function passwordHash(password) {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password,salt,64,{N:131072,r:8,p:1,maxmem:256*1024*1024});
  return ['$scrypt','131072','8','1',salt.toString('hex'),hash.toString('hex')].join('$');
}

(async () => {
  let sql = fs.readFileSync(file,'utf8');
  if (sql.includes('__BOSS_PASSWORD_HASH__')) {
    sql = sql.replace('__BOSS_PASSWORD_HASH__',passwordHash('boss123'))
      .replace('__MANAGER_PASSWORD_HASH__',passwordHash('admin123'));
    // Materialize the SQL file so it can also be re-run with psql unchanged.
    fs.writeFileSync(file,sql,'utf8');
  }
  const client = new Client({host:process.env.DB_HOST,port:Number(process.env.DB_PORT),database:process.env.DB_NAME,
    user:process.env.DB_USER,password:process.env.DB_PASSWORD,
    ssl:{rejectUnauthorized:true,ca:fs.readFileSync('./ca.pem').toString()}});
  try {
    await client.connect();
    // Validate existing identities first; ON CONFLICT must not bind a different
    // person's credentials/specializations to a colliding ID or email.
    const expected = [
      ['boss-01','boss@example.com','superAdmin',null],
      ['admin-01','admin@example.com','manager','branch-01'],
      ['staff-06','pending@example.com','staff','branch-01'],
    ];
    await client.query('BEGIN');
    await client.query("SELECT pg_advisory_xact_lock(hashtext('ktgk-demo-seed'))");
    for (const [id,email,role,branch] of expected) {
      const found = await client.query('SELECT id,email,role,branch_id FROM users WHERE id=$1 OR email=$2 FOR UPDATE',[id,email]);
      if (found.rows.some(u => u.id!==id || u.email!==email || u.role!==role || u.branch_id!==branch)) {
        throw new Error('Seed identity conflict; existing data preserved');
      }
    }
    // SQL provides its own transaction when run from psql; use the already
    // opened transaction here so collision checks and inserts stay atomic.
    await client.query(sql.replace(/^BEGIN;\s*$/m,'').replace(/^COMMIT;\s*$/m,''));
    await client.query('COMMIT');
    const counts = await client.query("SELECT (SELECT count(*) FROM branches) AS branches,(SELECT count(*) FROM users) AS users,(SELECT count(*) FROM users WHERE role='staff' AND NOT is_approved) AS pending_staff,(SELECT count(*) FROM categories) AS categories,(SELECT count(*) FROM services) AS services");
    console.log('Seed committed: '+JSON.stringify(counts.rows[0]));
  } catch (error) {
    await client.query('ROLLBACK').catch(()=>{});
    console.error('Seed failed; transaction rolled back. Code: '+(error.code ?? 'VALIDATION'));
    process.exitCode=1;
  } finally {await client.end();}
})();
