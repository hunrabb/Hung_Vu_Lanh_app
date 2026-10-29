export type AppointmentStatus =
  "pending" | "confirmed" | "completed" | "cancelled" | "noShow";
export class Appointment {
  id!: string;
  branchId!: string;
  staffId!: string;
  customerId!: string | null;
  customerName!: string;
  startAt!: Date;
  endAt!: Date;
  totalPriceVnd!: string;
  status!: AppointmentStatus;
  isHiddenByCustomer!: boolean;
  isHiddenByStaff!: boolean;
  isReviewed!: boolean;
  rating!: number | null;
}
export class AppointmentServiceItem {
  appointmentId!: string;
  position!: number;
  serviceId!: string;
  serviceNameSnapshot!: string;
}
