/// Parse money without going through double (including Flutter Web).
abstract final class ApiMoney {
  static String formatVnd(Object value) =>
      '${bigInt(value).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} VND';
  static BigInt bigInt(Object value) {
    if (value is! String || !RegExp(r'^\d+$').hasMatch(value)) {
      throw const FormatException('VND must be an integer string');
    }
    return BigInt.parse(value);
  }

  static int safeInt(Object value) {
    final amount = bigInt(value);
    if (amount > BigInt.from(9007199254740991)) {
      throw const FormatException(
        'Use BigInt for VND beyond the cross-platform safe integer range',
      );
    }
    return amount.toInt();
  }
}
