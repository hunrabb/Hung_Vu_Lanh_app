class Customer {
  int id;
  String fullName;
  String phone;
  String email;
  String address;
  String note;

  Customer({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.address,
    required this.note,
  });

  void updateInfo(String newName, String newPhone, String newEmail) {
    fullName = newName;
    phone = newPhone;
    email = newEmail;
  }
}
