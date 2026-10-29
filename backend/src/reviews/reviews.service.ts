import {
  ConflictException,
  ForbiddenException,
  Injectable,
} from "@nestjs/common";
import { Actor } from "../auth/auth.decorators";
import { FirestoreStore, wire } from "../firestore/firestore.store";
import { get, mutation, sorted } from "../firestore/rules";
import { CreateReviewDto, ReviewQueryDto } from "./review.dto";
@Injectable()
export class ReviewsService {
  constructor(private readonly db: FirestoreStore) {}
  async create(id: string, dto: CreateReviewDto, actor: Actor) {
    return mutation(
      this.db,
      ["appointments", "reviews"],
      actor,
      ["customer"],
      (s, current) => {
        const appointment = get(s, "appointments", id);
        if (appointment.customerId !== current.id)
          throw new ForbiddenException("Only the booking owner may review");
        if (appointment.status !== "completed")
          throw new ConflictException(
            "Only completed appointments may be reviewed",
          );
        if (
          s.reviews.some(
            (r) => r.appointmentId === id && r.targetType === dto.target,
          )
        )
          throw new ConflictException(
            "You already reviewed this target for this appointment",
          );
        const review = {
          appointmentId: id,
          targetType: dto.target,
          targetId:
            dto.target === "branch"
              ? appointment.branchId
              : appointment.staffId,
          customerId: current.id,
          rating: dto.rating,
          comment: dto.comment?.trim() ?? "",
          createdAt: new Date(),
        };
        s.reviews.push(review);
        if (dto.target === "staff")
          Object.assign(appointment, { isReviewed: true, rating: dto.rating });
        return wire("reviews", review);
      },
    );
  }
  list(q: ReviewQueryDto) {
    return this.db.read(["reviews", "users"], (s) => {
      const rows = sorted(
        s.reviews.filter(
          (r) => r.targetType === q.target && r.targetId === q.targetId,
        ),
        "createdAt",
        true,
      );
      return {
        count: rows.length,
        average: rows.length
          ? rows.reduce((n, r) => n + r.rating, 0) / rows.length
          : 0,
        items: rows.slice((q.page - 1) * 20, q.page * 20).map((r) => {
          const { customerId, ...item } = wire("reviews", r);
          return {
            ...item,
            customerName: s.users.find((u) => u.id === customerId)?.name ?? "",
          };
        }),
      };
    });
  }
}
