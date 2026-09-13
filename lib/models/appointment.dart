class Appointment {
  String id;
  String customerId;
  String employeeId;
  String serviceId;
  DateTime dateTime;
  String status;

  Appointment(
    this.id,
    this.customerId,
    this.employeeId,
    this.serviceId,
    this.dateTime,
    this.status,
  );

  void createAppointment() {
    status = "confirmed";
  }

  void cancelAppointment() {
    status = "cancelled";
  }

  void reschedule(DateTime newDateTime) {
    dateTime = newDateTime;
  }

  bool isValid() {
    return dateTime.isAfter(DateTime.now());
  }
}