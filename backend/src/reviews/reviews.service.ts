import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Actor } from "../auth/auth.decorators";
import { scopedMutation } from "../common/mutations";
import { Appointment } from "../appointments/appointment.entity";
import { Review } from "./review.entity";
import { CreateReviewDto, ReviewQueryDto } from "./review.dto";

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(Review) private readonly reviews: Repository<Review>,
  ) {}
  async create(id: string, dto: CreateReviewDto, actor: Actor) {
    return scopedMutation(
      this.reviews,
      actor,
      ["customer"],
      async (manager, current) => {
        const appointment = await manager.findOne(Appointment, {
          where: { id },
          lock: { mode: "pessimistic_write" },
        });
        if (!appointment) throw new NotFoundException("Appointment not found");
        if (appointment.customerId !== current.id)
          throw new ForbiddenException("Only the booking owner may review");
        if (appointment.status !== "completed")
          throw new ConflictException(
            "Only completed appointments may be reviewed",
          );
        const existing = await manager.findOne(Review, {
          where: { appointmentId: id, target: dto.target },
        });
        if (existing)
          throw new ConflictException(
            "You already reviewed this target for this appointment",
          );
        const review = manager.create(Review, {
          appointmentId: id,
          target: dto.target,
          targetId:
            dto.target === "branch"
              ? appointment.branchId
              : appointment.staffId,
          customerId: current.id,
          rating: dto.rating,
          comment: dto.comment?.trim() ?? "",
          createdAt: new Date(),
        });
        await manager.insert(Review, review);
        if (dto.target === "staff") {
          await manager.update(
            Appointment,
            { id },
            { isReviewed: true, rating: dto.rating },
          );
        }
        return review;
      },
    );
  }
  async list(query: ReviewQueryDto) {
    const parameters = [query.target, query.targetId];
    const [summary] = await this.reviews.manager.query(
      `SELECT count(*)::int AS count, coalesce(avg(rating),0)::float8 AS average
       FROM reviews WHERE target_type=$1 AND target_id=$2`,
      parameters,
    );
    const items = await this.reviews.manager.query(
      `SELECT r.appointment_id AS "appointmentId", r.target_type AS target,
        r.target_id AS "targetId", r.rating, r.comment, r.created_at AS "createdAt", u.name AS "customerName"
       FROM reviews r JOIN users u ON u.id=r.customer_id
       WHERE r.target_type=$1 AND r.target_id=$2
       ORDER BY r.created_at DESC, r.appointment_id LIMIT 20 OFFSET $3`,
      [...parameters, (query.page - 1) * 20],
    );
    return { ...summary, items };
  }
}
