import '../models/branch.dart';
import '../models/shop_settings.dart';

abstract final class ChainSeed {
  static const branches = [
    Branch(
      id: 'branch-01',
      name: 'Cơ sở Cầu Giấy',
      address: 'Đường Cầu Giấy, Hà Nội ',
      phone: '0901000001',
    ),
    Branch(
      id: 'branch-02',
      name: 'Cơ sở Đống Đa',
      address: 'Đường Tây Sơn, Hà Nội',
      phone: '0901000002',
    ),
    Branch(
      id: 'branch-03',
      name: 'Cơ sở Hà đông',
      address: 'Đường Dương Nội, Hà Nội',
      phone: '0989609529',
    ),
  ];
  static List<ShopSettings> settings() => [
    ShopSettings(
      branchId: 'branch-01',
      id: 'settings-01',
      openingMinute: 480,
      closingMinute: 1200,
    ),
    ShopSettings(
      branchId: 'branch-02',
      id: 'settings-02',
      openingMinute: 540,
      closingMinute: 1080,
    ),
  ];
}
