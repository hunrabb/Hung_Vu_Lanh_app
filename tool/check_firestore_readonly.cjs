const fs = require('node:fs');
const crypto = require('node:crypto');
async function main() {
  const key = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const now = Math.floor(Date.now()/1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const body = encode({alg:'RS256',typ:'JWT'})+'.'+encode({iss:key.client_email,scope:'https://www.googleapis.com/auth/datastore',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600});
  const assertion = body+'.'+crypto.sign('RSA-SHA256',Buffer.from(body),key.private_key).toString('base64url');
  const auth = await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),signal:AbortSignal.timeout(20000)});
  const token = await auth.json();
  if (!auth.ok) throw new Error('Authentication failed: '+auth.status+' '+(token.error || 'unknown'));
  const root = 'https://firestore.googleapis.com/v1/projects/'+encodeURIComponent(key.project_id)+'/databases/(default)/documents';
  const headers = {Authorization:'Bearer '+token.access_token,'Content-Type':'application/json'};
  for (const name of ['users','auth_credentials','branches','categories','services','appointments','staff_shifts','staff_leave_requests','promotions','reviews']) {
    const response = await fetch(root+':runAggregationQuery',{method:'POST',headers,body:JSON.stringify({structuredAggregationQuery:{structuredQuery:{from:[{collectionId:name}]},aggregations:[{alias:'total',count:{}}]}}),signal:AbortSignal.timeout(20000)});
    const result = await response.json();
    if (!response.ok) throw new Error('Firestore count failed: '+response.status+' '+(result.error?.status || 'unknown'));
    console.log(name+': '+(result[0]?.result?.aggregateFields?.total?.integerValue ?? 'unknown'));
  }
  const response = await fetch(root+'/_migrations/aiven-nosql-v1',{headers,signal:AbortSignal.timeout(20000)});
  const marker = await response.json();
  if (response.ok) console.log(JSON.stringify({migrationExists:true,status:marker.fields?.status?.stringValue,backendCutover:marker.fields?.backendCutover?.booleanValue}));
  else console.log('Migration marker status: '+response.status);
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
