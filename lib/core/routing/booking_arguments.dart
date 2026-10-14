class BookingArguments {
  const BookingArguments({this.branchId, this.serviceId});
  final String? branchId, serviceId;
}

class ServiceArguments {
  const ServiceArguments({this.branchId, this.categoryId, this.serviceId});
  final String? branchId, categoryId, serviceId;
}
