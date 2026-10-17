require('reflect-metadata');
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {Test}=require('@nestjs/testing');
const {ValidationPipe}=require('@nestjs/common');
const {AuthController}=require('../dist/auth/auth.controller');
const {AuthService}=require('../dist/auth/auth.service');
const {User}=require('../dist/users/user.entity');
test('PATCH /api/auth/me exists, validates input and excludes privilege injection',async()=>{
  let body;
  const module=await Test.createTestingModule({controllers:[AuthController],providers:[
    {provide:AuthService,useValue:{updateProfile:async(actor,dto)=>{body=dto;return {...dto,id:actor.id,role:'customer'};}}}
  ]}).compile();
  const app=module.createNestApplication({logger:false});
  app.setGlobalPrefix('api');
  app.use((req,res,next)=>{req.user={id:'owner',role:'customer'};next();});
  app.useGlobalPipes(new ValidationPipe({transform:true,whitelist:true,forbidNonWhitelisted:true}));
  try{
    await app.listen(0,'127.0.0.1');
    const url=(await app.getUrl())+'/api/auth/me';
    const send=data=>fetch(url,{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
    const valid={name:' New name ',email:'NEW@example.com',phone:'123',address:'Hanoi'};
    const r=await send(valid);assert.equal(r.status,200);
    assert.equal((await r.json()).id,'owner');assert.equal(body.name,'New name');assert.equal(body.email,'new@example.com');
    for(const bad of [{role:'superAdmin'},{id:'other'},{name:'   '},{email:'bad'},{phone:null},{address:null}])
      assert.equal((await send({...valid,...bad})).status,400);
  }finally{await app.close();}
});
test('profile writes own fields only and rejects revoked token before update',async()=>{
  const actor={id:'owner',role:'customer',branchId:null,isApproved:true,tokenVersion:2};
  let version=2,writes=0;
  const service=new AuthService({transaction:async work=>work({
    findOne:async(entity,opts)=>{assert.equal(opts.lock.mode,'pessimistic_write');return entity===User?actor:{tokenVersion:version};},
    update:async(entity,where,data)=>{assert.deepEqual(where,{id:'owner'});assert.equal(data.role,undefined);writes++;}
  })},{});
  const dto={name:'Name',email:'n@example.com',phone:'123',address:'Hanoi'};
  assert.equal((await service.updateProfile(actor,dto)).address,'Hanoi');
  version=3;await assert.rejects(service.updateProfile(actor,dto),{status:401});assert.equal(writes,1);
});
