class Customer {
  String id;
  String name;
  String phone;
  String email;
  String birthday;
  String notes;
  bool isVip;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.birthday = '',
    this.notes = '',
    this.isVip = false,
  });

  void updateInfo(String name, String phone, String email) {
    this.name = name;
    this.phone = phone;
    this.email = email;
  }

  void updateNotes(String notes) {
    this.notes = notes;
  }

  void setVip(bool value) {
    isVip = value;
  }
}
