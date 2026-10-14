import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { Actor, CurrentUser, Public, Roles } from "../auth/auth.decorators";
import { CreateReviewDto, ReviewQueryDto } from "./review.dto";
import { ReviewsService } from "./reviews.service";
@Controller()
export class ReviewsController {
  constructor(private readonly reviews: ReviewsService) {}
  @Public() @Get("reviews") list(@Query() query: ReviewQueryDto) {
    return this.reviews.list(query);
  }
  @Roles("customer") @Post("appointments/:id/reviews") create(
    @Param("id") id: string,
    @Body() dto: CreateReviewDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.reviews.create(id, dto, actor);
  }
}
