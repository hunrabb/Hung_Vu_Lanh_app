import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PassportStrategy } from "@nestjs/passport";
import { ExtractJwt, Strategy } from "passport-jwt";
import { AuthService, Claims } from "./auth.service";
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private readonly auth: AuthService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.getOrThrow<string>("JWT_SECRET"),
      algorithms: ["HS256"],
      issuer: "ktgk-api",
      audience: "ktgk-flutter",
      ignoreExpiration: false,
    });
  }
  validate(payload: Claims) {
    return this.auth.validateToken(payload);
  }
}
