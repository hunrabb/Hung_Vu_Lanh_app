import {
  Body,
  Controller,
  Get,
  HttpCode,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { AuthService } from "./auth.service";
import { RegisterDto, LoginDto, PasswordDto } from "./auth.dto";
import { Actor, CurrentUser, Public } from "./auth.decorators";
import { LoginRateGuard } from "./login-rate.guard";
@Controller("auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}
  @Public() @UseGuards(LoginRateGuard) @Post("register") register(
    @Body() dto: RegisterDto,
  ) {
    return this.auth.register(dto);
  }
  @Public() @UseGuards(LoginRateGuard) @HttpCode(200) @Post("login") login(
    @Body() dto: LoginDto,
  ) {
    return this.auth.login(dto);
  }
  @Get("me") me(@CurrentUser() actor: Actor) {
    return this.auth.profile(actor);
  }
  @Patch("password") password(
    @CurrentUser() actor: Actor,
    @Body() dto: PasswordDto,
  ) {
    return this.auth.password(actor, dto);
  }
  @HttpCode(200) @Post("logout") logout(@CurrentUser() actor: Actor) {
    return this.auth.logout(actor);
  }
}
