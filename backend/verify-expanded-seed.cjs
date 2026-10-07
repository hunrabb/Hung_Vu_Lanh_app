require('dotenv/config');
const fs=require('node:fs');const {Client}=require('pg');
(async()=>{
 const c=new Client({host:process.env.DB_HOST,port:Number(process.env.DB_PORT),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD,ssl:{rejectUnauthorized:true,ca:fs.readFileSync('./ca.pem').toString()}});
 try{await c.connect();
 console.log('Totals: '+JSON.stringify((await c.query("SELECT (SELECT count(*) FROM branches) branches,(SELECT count(*) FROM users) users,(SELECT count(*) FROM categories) categories,(SELECT count(*) FROM services) services,(SELECT count(*) FROM users WHERE role='superAdmin') bosses,(SELECT count(*) FROM users WHERE role='manager') managers,(SELECT count(*) FROM users WHERE role='staff' AND is_approved) approved_staff,(SELECT count(*) FROM users WHERE role='staff' AND NOT is_approved) pending_staff,(SELECT count(*) FROM users WHERE role='customer') customers")).rows[0]));
 console.log('Distribution: '+JSON.stringify((await c.query("SELECT branch_id, count(*) FILTER (WHERE role='manager') managers,count(*) FILTER (WHERE role='staff' AND is_approved) approved_staff,count(*) FILTER (WHERE role='staff' AND NOT is_approved) pending_staff FROM users WHERE branch_id IS NOT NULL GROUP BY branch_id ORDER BY branch_id")).rows));
 const pendingCredentialCount=(await c.query("SELECT count(*) FROM auth_credentials a JOIN users u ON u.id=a.user_id WHERE u.role='staff' AND NOT u.is_approved")).rows[0].count;
 if(pendingCredentialCount!=='0')throw Error('Pending Staff has credentials');
 const login=await fetch('http://localhost:3000/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'boss@example.com',password:process.env.SEED_BOSS_PASSWORD??'boss123'})});
 if(login.status!==200)throw Error('Boss login failed');const {accessToken}=await login.json();
 for(const p of ['/api/users/pending','/api/services']){const r=await fetch('http://localhost:3000'+p,{headers:{Authorization:'Bearer '+accessToken}});const rows=await r.json();console.log(JSON.stringify({path:p,status:r.status,count:rows.length,ids:rows.map(x=>x.id)}));if(r.status!==200||rows.length!==(p.includes('pending')?5:20))throw Error('Unexpected API result');}
 }finally{await c.end();}
})().catch(()=>{console.error('Expanded seed verification failed');process.exitCode=1;});
