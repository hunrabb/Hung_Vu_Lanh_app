export class Review {
  appointmentId!: string;
  target!: "branch" | "staff";
  targetId!: string;
  customerId!: string;
  rating!: number;
  comment!: string;
  createdAt!: Date;
}
