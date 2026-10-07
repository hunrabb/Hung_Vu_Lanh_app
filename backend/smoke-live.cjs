require('reflect-metadata');
const { NestFactory } = require('@nestjs/core');
const { AppModule } = require('./dist/app.module');
(async () => {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix('api');
  try {
    await app.listen(0, '127.0.0.1');
    const base = await app.getUrl();
    const login=await fetch(base+'/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'boss@example.com',password:process.env.SEED_BOSS_PASSWORD??'boss123'})});
    if(login.status!==200)throw new Error('Boss login failed');
    const {accessToken}=await login.json();
    for (const path of ['/api/branches','/api/users/pending','/api/users/branch/branch-01','/api/categories','/api/services']) {
      const response = await fetch(base + path,{headers:{Authorization:'Bearer '+accessToken}});
      const body = await response.json();
      console.log(`${path}: HTTP ${response.status}; rows=${Array.isArray(body) ? body.length : 'not-an-array'}`);
      if (response.status !== 200 || !Array.isArray(body)) throw new Error('Unexpected API response');
    }
  } finally { await app.close(); }
})().catch(() => {console.error('Live smoke test failed');process.exitCode=1;});
