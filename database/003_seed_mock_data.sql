-- Expanded test chain: 4 Hanoi branches, 23 users, 6 enum-compatible categories, 20 services.
-- Boss uses superAdmin and NULL branch; approved identities have scrypt hashes.
-- User/credential/service edits are preserved. Branch/category demo labels are refreshed.
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('ktgk-demo-seed'));
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM (VALUES
 ('boss-01','boss@example.com','superAdmin',NULL),
 ('admin-01','admin@example.com','manager','branch-01'),
 ('manager-02','manager2@example.com','manager','branch-02'),
 ('manager-03','manager3@example.com','manager','branch-03'),
 ('manager-04','manager4@example.com','manager','branch-04'),
 ('staff-01','staff@exampler.com','staff','branch-01'),
 ('staff-02','staff2@example.com','staff','branch-01'),
 ('staff-03','staff3@example.com','staff','branch-01'),
 ('staff-04','staff4@example.com','staff','branch-02'),
 ('staff-05','staff5@example.com','staff','branch-02'),
 ('staff-07','staff7@example.com','staff','branch-02'),
 ('staff-08','staff8@example.com','staff','branch-03'),
 ('staff-09','staff9@example.com','staff','branch-03'),
 ('staff-10','staff10@example.com','staff','branch-04'),
 ('staff-11','staff11@example.com','staff','branch-04'),
 ('staff-06','pending@example.com','staff','branch-01'),
 ('staff-12','pending12@example.com','staff','branch-01'),
 ('staff-13','pending13@example.com','staff','branch-02'),
 ('staff-14','pending14@example.com','staff','branch-03'),
 ('staff-15','pending15@example.com','staff','branch-04'),
 ('customer-01','customer@example.com','customer',NULL),
 ('customer-02','customer2@example.com','customer',NULL),
 ('customer-03','customer3@example.com','customer',NULL)
 ) expected(id,email,role,branch_id) JOIN users actual ON actual.id=expected.id OR actual.email=expected.email
 WHERE actual.id<>expected.id OR actual.email<>expected.email OR actual.role<>expected.role
 OR actual.branch_id IS DISTINCT FROM expected.branch_id) THEN RAISE EXCEPTION 'Seed identity conflict; existing data preserved'; END IF;
END $$;
INSERT INTO branches(id,name,address,phone) VALUES
 ('branch-01','Cơ sở Cầu Giấy','123 Cầu Giấy, Hà Nội (địa chỉ mẫu)','0901000001'),
 ('branch-02','Cơ sở Đống Đa','85 Tây Sơn, Đống Đa, Hà Nội (địa chỉ mẫu)','0901000002'),
 ('branch-03','Cơ sở Hai Bà Trưng','210 Bạch Mai, Hai Bà Trưng, Hà Nội (địa chỉ mẫu)','0901000003'),
 ('branch-04','Cơ sở Hà Đông','36 Quang Trung, Hà Đông, Hà Nội (địa chỉ mẫu)','0901000004')
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name,address=EXCLUDED.address,phone=EXCLUDED.phone;
INSERT INTO categories(id,name) VALUES
 ('haircut','Cắt tạo kiểu'),
 ('perm','Uốn tóc chuyên nghiệp'),
 ('dye','Nhuộm màu'),
 ('hairWash','Gội massage'),
 ('massage','Massage & chăm sóc da'),
 ('shaving','Dịch vụ phụ trợ')
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name;
INSERT INTO users(id,email,role,branch_id,name,phone,address,is_approved) VALUES
 ('boss-01','boss@example.com','superAdmin',NULL,'Boss Demo','0901000010','Hà Nội',TRUE),
 ('admin-01','admin@example.com','manager','branch-01','Manager Cơ sở 1','0901000011','Cầu Giấy, Hà Nội',TRUE),
 ('manager-02','manager2@example.com','manager','branch-02','Quản lý Cơ sở Đống Đa','0901000022','85 Tây Sơn, Đống Đa, Hà Nội (địa chỉ mẫu)',TRUE),
 ('manager-03','manager3@example.com','manager','branch-03','Quản lý Cơ sở Hai Bà Trưng','0901000023','210 Bạch Mai, Hai Bà Trưng, Hà Nội (địa chỉ mẫu)',TRUE),
 ('manager-04','manager4@example.com','manager','branch-04','Quản lý Cơ sở Hà Đông','0901000024','36 Quang Trung, Hà Đông, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-01','staff@exampler.com','staff','branch-01','Nguyễn Minh Hùng','0902000001','123 Cầu Giấy, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-02','staff2@example.com','staff','branch-01','Trần Ngọc Linh','0902000002','123 Cầu Giấy, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-03','staff3@example.com','staff','branch-01','Alex Nguyễn','0902000003','123 Cầu Giấy, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-04','staff4@example.com','staff','branch-02','Lê Thanh Minh','0902000004','85 Tây Sơn, Đống Đa, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-05','staff5@example.com','staff','branch-02','Phạm Gia An','0902000005','85 Tây Sơn, Đống Đa, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-07','staff7@example.com','staff','branch-02','Đỗ Hoàng Nam','0902000007','85 Tây Sơn, Đống Đa, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-08','staff8@example.com','staff','branch-03','Vũ Thu Hà','0902000008','210 Bạch Mai, Hai Bà Trưng, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-09','staff9@example.com','staff','branch-03','Bùi Đức Anh','0902000009','210 Bạch Mai, Hai Bà Trưng, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-10','staff10@example.com','staff','branch-04','Hoàng Mai Lan','0902000010','36 Quang Trung, Hà Đông, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-11','staff11@example.com','staff','branch-04','Nguyễn Tuấn Kiệt','0902000011','36 Quang Trung, Hà Đông, Hà Nội (địa chỉ mẫu)',TRUE),
 ('staff-06','pending@example.com','staff','branch-01','Nguyễn Minh An','0901000012','Cầu Giấy, Hà Nội',FALSE),
 ('staff-12','pending12@example.com','staff','branch-01','Trần Phương Anh','0903000012','123 Cầu Giấy, Hà Nội (địa chỉ mẫu)',FALSE),
 ('staff-13','pending13@example.com','staff','branch-02','Lê Quang Huy','0903000013','85 Tây Sơn, Đống Đa, Hà Nội (địa chỉ mẫu)',FALSE),
 ('staff-14','pending14@example.com','staff','branch-03','Vũ Minh Châu','0903000014','210 Bạch Mai, Hai Bà Trưng, Hà Nội (địa chỉ mẫu)',FALSE),
 ('staff-15','pending15@example.com','staff','branch-04','Đỗ Gia Bảo','0903000015','36 Quang Trung, Hà Đông, Hà Nội (địa chỉ mẫu)',FALSE),
 ('customer-01','customer@example.com','customer',NULL,'Nguyễn An Nhiên','0904000001','Hà Nội',TRUE),
 ('customer-02','customer2@example.com','customer',NULL,'Trần Minh Đức','0904000002','Hà Nội',TRUE),
 ('customer-03','customer3@example.com','customer',NULL,'Lê Khánh Linh','0904000003','Hà Nội',TRUE)
ON CONFLICT DO NOTHING;
INSERT INTO auth_credentials(user_id,password_hash) VALUES
 ('boss-01','$scrypt$131072$8$1$2abc1ed34baec04deb80ce25773d1cf1$496c83fce7b491aeb0127c2fd61428a1bbc33f76bcc8072c6e4692848472d42edb8b0ff617b70da4a37f334b30057343f48b0b0fcba74bade3bee15b805e663e'),
 ('admin-01','$scrypt$131072$8$1$979379fb7ce7a4f75b3373cef5eb0277$c4e58d6955dab1484c3061d6c7905d19b6cd76cec01995a245bb9c4447ca0f69d3529a78c2a01ddb45ce1698d9ad6f24ec339879484ad4815b90e414c6f39443'),
 ('manager-02','$scrypt$131072$8$1$650c2bd90e2ba44d8a559d3e9fea428a$408269da2b5c70d56ca11ee8a746081780295a0364717637f2670ee45ee3da9229ba17b8126730cd8ac85e73da30cbc3dfc8a42b1570c327fffaba1e247af128'),
 ('manager-03','$scrypt$131072$8$1$903cd8ca8917c12745d18599a5d38a8c$5440334665148136649fb61d4d2837461a5160db9c1a33635c902ae0f37d9e7ddfc3d77fe64b0441d8abe56f0fdb3d36279ea3feb9f8e2ec7f0877aa2a68208f'),
 ('manager-04','$scrypt$131072$8$1$ee472a41c94a6163fbb4751da6c46642$59cfdd67dffec06bb647bd3886bfbef5572d89382a21fbc7221c342ae5c9c0e1ddc9e2d83d26858e8fbce8e17b408fe9631df6fb54c32f7eb48eef779b4fa947'),
 ('staff-01','$scrypt$131072$8$1$6fa8d8420bb4b8eff6d7cc85bb26072d$aa2beb66411fb6009089aa7bf9ccf28672542a2364effd9d4a4834b57bcb6290dc4a7e1595cda2db14c2793620cad99c8b204bf838240f698d4835c8a978cd16'),
 ('staff-02','$scrypt$131072$8$1$dd10455aaad5c6537a5936bbbcdee386$0a43834c9f4f5e0a30fb4d4179b968663c7bdb921410a8d4f110e56695f06c58905a163b912641a9700f0f42682abd3d6806fa8a69b58a7fbc4108b81a458a1f'),
 ('staff-03','$scrypt$131072$8$1$69e29a814928a4f7e5c164111df30db2$b04c2e58f3785ef0e93f13f8556e27a32a7df203b5eee047031231ffac932b4931592c3c8fdd30356ab47a0a61df13eada4ed6360a621147656e25406230f82c'),
 ('staff-04','$scrypt$131072$8$1$f560278cc6fd0bf4e11b32081d0a3a8f$abc1942fb68010d7d775f94a8d1a3729e70ba4e45c98eb5a02b220e77db8faf0a135f65a810c34ef1cae3644440d7a3961b8dfbbead17e064825b5aede6df369'),
 ('staff-05','$scrypt$131072$8$1$f5eff6946605d1d95ecf6601e4e22e6b$4ae6956243d3ddaf520862133f3372c796ce86a1304efe4af712abc2d02a808aee2af8d89d6d14b430bc75adc44635d184d35ee1f3700f175937549b4e5fdb16'),
 ('staff-07','$scrypt$131072$8$1$8dea45a68f1e999fa994f7fc6f63fea9$b42bd8ea3dcddbb7930afe3ff3156ef887c24943335ffa76073053134e73483786e8ee5143547ea85ac2dbc12ed1caf28300e1e15064487ee207adb0c06a0243'),
 ('staff-08','$scrypt$131072$8$1$cd608a1a5855cf6ee343e1e761b81a2a$2eb304ba316147a83be6a44d1b81777ef825c6856d0904c673de1e7ec8fa76fd46069a540b2e8a276b1c6a1f2304f8f944606ce22d33fa2033498de537131b96'),
 ('staff-09','$scrypt$131072$8$1$787c88f8b6c1de2d411f036615dddbb4$79d6f8283efe758887cdddf909d92741f9173d3fe2df75c32ad76be6e26ada60233d5479b089208a0d69860a1ec3c99122939418cdff4cd9330dd0766403a6d6'),
 ('staff-10','$scrypt$131072$8$1$af6de9791f0bd8be67332349e8713044$ddcdf223b13e880c81af27e3919bf5b3596dcc96ce0475eafec91c868ad0f5d665f92c3bcb4977cd5a2a727829fdfe16115c091303d7e522bfbdf384ab6f5f06'),
 ('staff-11','$scrypt$131072$8$1$473a9e1979eeadb93ef092387d865c7a$a2405d8a7bdd17af6e3bff4aa34667f06f9aa682a1c0e132f88802a2aa1568e05685c127ba85f744ab3be00a5cccce2686f0c51bf4ae449c295f3f9c19b9398d'),
 ('customer-01','$scrypt$131072$8$1$d7a75a69ec2e1ba29441c49b22a82376$fa5e1c642f08e406aff67a2c302e09a06a78b507a20ff0bfb7890037f77fa51403292ad221fe99a85bfb984e275f9eb3b0bc30d54151f151bb81eaa35e829da2'),
 ('customer-02','$scrypt$131072$8$1$da9a684b02934f13cdb6e2f3f32757c0$351bc14530589d287c591f035ab7e13778e5afa3f7a33dbb40d26ea8a12710bbdc8f60076eae6d9e4636df4ba7300dec9c5a72cbf13a73ef78ae84df03c00567'),
 ('customer-03','$scrypt$131072$8$1$7b3b54d8917b306361a7b75cc1377440$8e2f5a2ecf7687fff6448bede142c449aa1505c68c4fbe92ad781f60afc0ea7af6cd9f9d5462097223798e84e60b286370fdcd0af9aa8818b70af7e39c68ae1b')
ON CONFLICT DO NOTHING;
INSERT INTO staff_specializations(staff_id,category_id) VALUES
 ('staff-01','haircut'),
 ('staff-01','hairWash'),
 ('staff-01','shaving'),
 ('staff-02','perm'),
 ('staff-02','dye'),
 ('staff-02','haircut'),
 ('staff-03','hairWash'),
 ('staff-03','massage'),
 ('staff-04','haircut'),
 ('staff-04','hairWash'),
 ('staff-04','shaving'),
 ('staff-05','perm'),
 ('staff-05','dye'),
 ('staff-05','haircut'),
 ('staff-07','hairWash'),
 ('staff-07','massage'),
 ('staff-08','haircut'),
 ('staff-08','hairWash'),
 ('staff-08','shaving'),
 ('staff-09','perm'),
 ('staff-09','dye'),
 ('staff-09','haircut'),
 ('staff-10','hairWash'),
 ('staff-10','massage'),
 ('staff-11','haircut'),
 ('staff-11','hairWash'),
 ('staff-11','shaving'),
 ('staff-06','perm'),
 ('staff-06','dye'),
 ('staff-06','haircut'),
 ('staff-12','hairWash'),
 ('staff-12','massage'),
 ('staff-13','haircut'),
 ('staff-13','hairWash'),
 ('staff-13','shaving'),
 ('staff-14','perm'),
 ('staff-14','dye'),
 ('staff-14','haircut'),
 ('staff-15','hairWash'),
 ('staff-15','massage')
ON CONFLICT DO NOTHING;
INSERT INTO shop_settings(branch_id,id,opening_minute,closing_minute) VALUES
 ('branch-01','settings-01',480,1200),
 ('branch-02','settings-02',540,1080),
 ('branch-03','settings-03',480,1200),
 ('branch-04','settings-04',480,1200)
ON CONFLICT DO NOTHING;
INSERT INTO services(id,category_id,name,price_vnd,duration_minutes,is_active) VALUES
 ('service-01','haircut','Cắt tóc nam',80000,30,TRUE),
 ('service-02','hairWash','Gội đầu thư giãn',60000,30,TRUE),
 ('service-03','haircut','Combo cắt tóc và gội đầu',130000,45,TRUE),
 ('service-04','haircut','Cắt tạo kiểu nữ',200000,45,TRUE),
 ('service-05','haircut','Tạo kiểu dự tiệc',350000,60,TRUE),
 ('service-06','haircut','Combo VIP cắt tạo kiểu và chăm sóc',900000,120,TRUE),
 ('service-07','perm','Uốn phồng chân tóc',450000,75,TRUE),
 ('service-08','perm','Uốn sóng tự nhiên',850000,120,TRUE),
 ('service-09','perm','Uốn phục hồi cao cấp',1500000,120,TRUE),
 ('service-10','dye','Nhuộm màu cơ bản',550000,90,TRUE),
 ('service-11','dye','Nhuộm thời trang',950000,120,TRUE),
 ('service-12','dye','Nhuộm phủ bạc',300000,60,TRUE),
 ('service-13','hairWash','Gội massage thảo mộc',180000,45,TRUE),
 ('service-14','hairWash','Gội dưỡng sinh chuyên sâu',300000,60,TRUE),
 ('service-15','massage','Chăm sóc da mặt cơ bản',250000,45,TRUE),
 ('service-16','massage','Chăm sóc da mặt chuyên sâu',650000,90,TRUE),
 ('service-17','massage','Massage thư giãn cổ vai gáy',200000,30,TRUE),
 ('service-18','shaving','Cạo râu tạo đường nét',50000,15,TRUE),
 ('service-19','shaving','Tỉa chân mày',70000,15,TRUE),
 ('service-20','shaving','Chăm sóc tóc nhanh',120000,30,TRUE)
ON CONFLICT DO NOTHING;
COMMIT;
