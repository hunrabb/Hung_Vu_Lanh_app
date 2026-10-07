const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');
const file=path.join(__dirname,'../database/003_seed_mock_data.sql');
const previous=fs.readFileSync(file,'utf8');
const hashes=new Map([...previous.matchAll(/'([^']+)'\s*,\s*'(\$scrypt\$[^']+)'/g)].map(m=>[m[1],m[2]]));
const quote=v=>v===null?'NULL':typeof v==='boolean'?(v?'TRUE':'FALSE'):typeof v==='number'?String(v):"'"+v.replaceAll("'","''")+"'";
const values=rows=>rows.map(r=>' ('+r.map(quote).join(',')+')').join(',\n');
const insert=(table,cols,rows,conflict='ON CONFLICT DO NOTHING')=>`INSERT INTO ${table}(${cols}) VALUES\n${values(rows)}\n${conflict};\n`;
const branches=[
 ['branch-01','Cơ sở Cầu Giấy','123 Cầu Giấy, Hà Nội (địa chỉ mẫu)','0901000001'],
 ['branch-02','Cơ sở Đống Đa','85 Tây Sơn, Đống Đa, Hà Nội (địa chỉ mẫu)','0901000002'],
 ['branch-03','Cơ sở Hai Bà Trưng','210 Bạch Mai, Hai Bà Trưng, Hà Nội (địa chỉ mẫu)','0901000003'],
 ['branch-04','Cơ sở Hà Đông','36 Quang Trung, Hà Đông, Hà Nội (địa chỉ mẫu)','0901000004'],
];
const categories=[['haircut','Cắt tạo kiểu'],['perm','Uốn tóc chuyên nghiệp'],['dye','Nhuộm màu'],['hairWash','Gội massage'],['massage','Massage & chăm sóc da'],['shaving','Dịch vụ phụ trợ']];
const people=[['boss-01','boss@example.com','superAdmin',null,'Boss Demo','0901000010','Hà Nội',true],
 ['admin-01','admin@example.com','manager','branch-01','Manager Cơ sở 1','0901000011','Cầu Giấy, Hà Nội',true]];
for(let i=2;i<=4;i++)people.push([`manager-0${i}`,`manager${i}@example.com`,'manager',`branch-0${i}`,`Quản lý ${branches[i-1][1]}`,`090100002${i}`,branches[i-1][2],true]);
const staffIds=[1,2,3,4,5,7,8,9,10,11];
const staffNames=['Nguyễn Minh Hùng','Trần Ngọc Linh','Alex Nguyễn','Lê Thanh Minh','Phạm Gia An','Đỗ Hoàng Nam','Vũ Thu Hà','Bùi Đức Anh','Hoàng Mai Lan','Nguyễn Tuấn Kiệt'];
staffIds.forEach((id,index)=>{const b=index<3?1:index<6?2:index<8?3:4;people.push([`staff-${String(id).padStart(2,'0')}`,id===1?'staff@exampler.com':`staff${id}@example.com`,'staff',`branch-0${b}`,staffNames[index],`090200${String(id).padStart(4,'0')}`,branches[b-1][2],true]);});
const pending=[['staff-06','pending@example.com','staff','branch-01','Nguyễn Minh An','0901000012','Cầu Giấy, Hà Nội',false]];
for(let id=12;id<=15;id++){const b=id-11;pending.push([`staff-${id}`,`pending${id}@example.com`,'staff',`branch-0${b}`,['Trần Phương Anh','Lê Quang Huy','Vũ Minh Châu','Đỗ Gia Bảo'][b-1],`090300${String(id).padStart(4,'0')}`,branches[b-1][2],false]);}
people.push(...pending);
for(let i=1;i<=3;i++)people.push([`customer-0${i}`,i===1?'customer@example.com':`customer${i}@example.com`,'customer',null,['Nguyễn An Nhiên','Trần Minh Đức','Lê Khánh Linh'][i-1],`090400000${i}`,'Hà Nội',true]);
const offerings=[
 ['haircut','Cắt tóc nam',80000,30],['hairWash','Gội đầu thư giãn',60000,30],['haircut','Combo cắt tóc và gội đầu',130000,45],
 ['haircut','Cắt tạo kiểu nữ',200000,45],['haircut','Tạo kiểu dự tiệc',350000,60],['haircut','Combo VIP cắt tạo kiểu và chăm sóc',900000,120],
 ['perm','Uốn phồng chân tóc',450000,75],['perm','Uốn sóng tự nhiên',850000,120],['perm','Uốn phục hồi cao cấp',1500000,120],
 ['dye','Nhuộm màu cơ bản',550000,90],['dye','Nhuộm thời trang',950000,120],['dye','Nhuộm phủ bạc',300000,60],
 ['hairWash','Gội massage thảo mộc',180000,45],['hairWash','Gội dưỡng sinh chuyên sâu',300000,60],
 ['massage','Chăm sóc da mặt cơ bản',250000,45],['massage','Chăm sóc da mặt chuyên sâu',650000,90],['massage','Massage thư giãn cổ vai gáy',200000,30],
 ['shaving','Cạo râu tạo đường nét',50000,15],['shaving','Tỉa chân mày',70000,15],['shaving','Chăm sóc tóc nhanh',120000,30],
];
const services=offerings.map((s,i)=>[`service-${String(i+1).padStart(2,'0')}`,...s,true]);
const links=people.filter(p=>p[2]==='staff').flatMap((p,i)=>{
 const ids=i%3===0?['haircut','hairWash','shaving']:i%3===1?['perm','dye','haircut']:['hairWash','massage'];
 return ids.map(c=>[p[0],c]);
});
const creds=people.filter(p=>p[7]).map(p=>{
 const pwd=p[2]==='superAdmin'?'boss123':p[2]==='manager'?(p[0]==='admin-01'?'admin123':'manager123'):p[2]==='staff'?'staff123':'customer123';
 if(!hashes.has(p[0])){const salt=crypto.randomBytes(16);const hash=crypto.scryptSync(pwd,salt,64,{N:131072,r:8,p:1,maxmem:256*1024*1024});hashes.set(p[0],['$scrypt','131072','8','1',salt.toString('hex'),hash.toString('hex')].join('$'));}
 return [p[0],hashes.get(p[0])];
});
const expected=values(people.map(p=>[p[0],p[1],p[2],p[3]]));
let sql=`-- Expanded test chain: 4 Hanoi branches, 23 users, 6 enum-compatible categories, 20 services.\n-- Boss uses superAdmin and NULL branch; approved identities have scrypt hashes.\n-- User/credential/service edits are preserved. Branch/category demo labels are refreshed.\nBEGIN;\nSELECT pg_advisory_xact_lock(hashtext('ktgk-demo-seed'));\nDO $$\nBEGIN\n IF EXISTS(SELECT 1 FROM (VALUES\n${expected}\n ) expected(id,email,role,branch_id) JOIN users actual ON actual.id=expected.id OR actual.email=expected.email\n WHERE actual.id<>expected.id OR actual.email<>expected.email OR actual.role<>expected.role\n OR actual.branch_id IS DISTINCT FROM expected.branch_id) THEN RAISE EXCEPTION 'Seed identity conflict; existing data preserved'; END IF;\nEND $$;\n`;
sql+=insert('branches','id,name,address,phone',branches,'ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name,address=EXCLUDED.address,phone=EXCLUDED.phone');
sql+=insert('categories','id,name',categories,'ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name');
sql+=insert('users','id,email,role,branch_id,name,phone,address,is_approved',people);
sql+=insert('auth_credentials','user_id,password_hash',creds);
sql+=insert('staff_specializations','staff_id,category_id',links);
sql+=insert('shop_settings','branch_id,id,opening_minute,closing_minute',branches.map((b,i)=>[b[0],`settings-0${i+1}`,i===1?540:480,i===1?1080:1200]));
sql+=insert('services','id,category_id,name,price_vnd,duration_minutes,is_active',services);
sql+='COMMIT;\n';fs.writeFileSync(file,sql,'utf8');
console.log('Expanded seed SQL generated: branches=4 users=23 approvedStaff=10 pendingStaff=5 categories=6 services=20');
