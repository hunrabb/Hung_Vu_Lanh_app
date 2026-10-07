import {
  CanActivate,
  ExecutionContext,
  HttpException,
  Injectable,
} from "@nestjs/common";
@Injectable()
export class LoginRateGuard implements CanActivate {
  private readonly buckets = new Map<
    string,
    { count: number; until: number }
  >();
  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    const key = String(request.ip);
    const now = Date.now();
    for (const [ip, bucket] of this.buckets)
      if (bucket.until <= now) this.buckets.delete(ip);
    if (!this.buckets.has(key) && this.buckets.size >= 10000)
      throw new HttpException("Try again later", 429);
    const bucket = this.buckets.get(key) ?? { count: 0, until: now + 60000 };
    if (++bucket.count > 20)
      throw new HttpException("Too many authentication requests", 429);
    this.buckets.set(key, bucket);
    return true;
  }
}
