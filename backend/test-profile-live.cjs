require('dotenv/config');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const fs=require('node:fs');
const {Client}=require('pg');
const base='http://localhost:3000/api';
async function request(path,method='GET',body,token){
  const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{})});
  return {status:r.status,body:await r.json()};
}
(async()=>{
  const db=new Client({host:process.env.DB_HOST,port:Number(process.env.DB_PORT),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD,
    ssl:{rejectUnauthorized:true,ca:fs.readFileSync('./ca.pem').toString()}});
  let id;
  try{
    await db.connect();
    const email='profile-'+randomUUID()+'@example.com';
    const registered=await request('/auth/register','POST',{name:'Profile test temporary',email,password:'ProfileTest123!'});
    assert.equal(registered.status,201);id=registered.body.user.id;
    const token=registered.body.accessToken;
    const fields={name:'Khách kiểm thử',email,phone:'0901234567',address:'Hà Nội'};
    assert.equal((await request('/auth/me','PATCH',fields)).status,401);
    const saved=await request('/auth/me','PATCH',fields,token);
    assert.equal(saved.status,200);assert.equal(saved.body.address,fields.address);
    const read=await request('/auth/me','GET',undefined,token);
    for(const key of Object.keys(fields))assert.equal(read.body[key],fields[key]);
    const row=(await db.query('SELECT name,email,phone,address,role FROM users WHERE id=$1',[id])).rows[0];
    assert.equal(row.address,fields.address);assert.equal(row.role,'customer');
    assert.equal((await request('/auth/me','PATCH',{...fields,role:'superAdmin'},token)).status,400);
    assert.equal((await request('/auth/me','PATCH',{...fields,email:'boss@example.com'},token)).status,409);
    assert.equal((await request('/auth/me','GET',undefined,token)).body.email,email);
    await request('/auth/logout','POST',undefined,token);
    assert.equal((await request('/auth/me','PATCH',fields,token)).status,401);
    console.log('Live profile: PATCH 200, GET and PostgreSQL persistence, 400 injection, 409 duplicate email, 401 revoked session passed.');
  }finally{
    if(id)await db.query("DELETE FROM users WHERE id=$1 AND role='customer'",[id]);
    await db.end();
  }
})().catch(error=>{console.error('Live profile failed:',error.message);process.exitCode=1;});
