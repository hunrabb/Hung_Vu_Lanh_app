import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { randomUUID } from "node:crypto";
import { FirestoreStore, Row } from "../firestore/firestore.store";
import { authorize, emailUnique, mutation } from "../firestore/rules";
import { Actor } from "./auth.decorators";
import { LoginDto, RegisterDto, PasswordDto, ProfileDto } from "./auth.dto";
import { hashPassword, validateNewPassword, verifyPassword } from "./passwords";
export interface Claims {
  sub: string;
  ver: number;
  role: string;
  branchId: string | null;
}
@Injectable()
export class AuthService {
  constructor(
    private readonly db: FirestoreStore,
    private readonly jwt: JwtService,
  ) {}
  profile(user: Row) {
    const {
      id,
      email,
      name,
      role,
      branchId,
      phone,
      address,
      isApproved,
      createdAt,
    } = user;
    return {
      id,
      email,
      name,
      role,
      branchId,
      phone,
      address,
      isApproved,
      createdAt,
    };
  }
  updateProfile(actor: Actor, dto: ProfileDto) {
    if (!dto.name.trim()) throw new BadRequestException("Name is required");
    return mutation(
      this.db,
      [],
      actor,
      ["customer", "staff", "manager", "superAdmin"],
      (s, user) => {
        emailUnique(s, dto.email, user.id);
        Object.assign(user, {
          name: dto.name.trim(),
          email: dto.email.trim().toLowerCase(),
          phone: dto.phone.trim(),
          address: dto.address.trim(),
        });
        return this.profile(user);
      },
    );
  }
  async register(dto: RegisterDto) {
    validateNewPassword(dto.password);
    if (!dto.name.trim()) throw new BadRequestException("Name is required");
    const passwordHash = await hashPassword(dto.password);
    const user = await this.db.mutate([], (s) => {
      emailUnique(s, dto.email);
      const user = {
        id: randomUUID(),
        name: dto.name.trim(),
        email: dto.email.trim().toLowerCase(),
        role: "customer",
        branchId: null,
        phone: null,
        address: null,
        isApproved: true,
        specializedCategoryIds: [],
        createdAt: new Date(),
      };
      s.users.push(user);
      s.auth_credentials.push({
        userId: user.id,
        passwordHash,
        tokenVersion: 0,
      });
      return user;
    });
    return { accessToken: await this.token(user, 0), user: this.profile(user) };
  }
  async login(dto: LoginDto) {
    const prior = await this.db.read(["users", "auth_credentials"], (s) => {
      const user = s.users.find(
        (u) => u.email === dto.email.trim().toLowerCase(),
      );
      return {
        user,
        credential: s.auth_credentials.find((c) => c.userId === user?.id),
      };
    });
    if (
      !prior.user?.isApproved ||
      !prior.credential ||
      !(await verifyPassword(dto.password, prior.credential.passwordHash))
    )
      throw new UnauthorizedException("Invalid email or password");
    let hash = prior.credential.passwordHash;
    if (hash.startsWith("$scrypt$")) {
      validateNewPassword(dto.password);
      hash = await hashPassword(dto.password);
    }
    const result = await this.db.mutate([], (s) => {
      const user = s.users.find((u) => u.id === prior.user!.id),
        credential = s.auth_credentials.find((c) => c.userId === user?.id);
      if (
        !user?.isApproved ||
        !credential ||
        credential.passwordHash !== prior.credential!.passwordHash ||
        credential.tokenVersion !== prior.credential!.tokenVersion
      )
        throw new UnauthorizedException("Account changed; sign in again");
      credential.passwordHash = hash;
      return { user, version: credential.tokenVersion };
    });
    return {
      accessToken: await this.token(result.user, result.version),
      user: this.profile(result.user),
    };
  }
  async validateToken(payload: Claims): Promise<Actor> {
    if (typeof payload.sub !== "string" || !Number.isInteger(payload.ver))
      throw new UnauthorizedException();
    return this.db.read(["users", "auth_credentials"], (s) => {
      const actor = {
        id: payload.sub,
        role: payload.role,
        branchId: payload.branchId,
        tokenVersion: payload.ver,
      } as Actor;
      return {
        ...authorize(s, actor, ["customer", "staff", "manager", "superAdmin"]),
        tokenVersion: payload.ver,
      } as Actor;
    });
  }
  async password(actor: Actor, dto: PasswordDto) {
    validateNewPassword(dto.newPassword);
    if (dto.oldPassword === dto.newPassword)
      throw new BadRequestException("New password must be different");
    const prior = await this.db.read(["auth_credentials"], (s) =>
      s.auth_credentials.find((c) => c.userId === actor.id),
    );
    if (!prior || !(await verifyPassword(dto.oldPassword, prior.passwordHash)))
      throw new UnauthorizedException("Incorrect current password");
    const hash = await hashPassword(dto.newPassword);
    await mutation(
      this.db,
      [],
      actor,
      ["customer", "staff", "manager", "superAdmin"],
      (s) => {
        const c = s.auth_credentials.find((c) => c.userId === actor.id)!;
        if (c.passwordHash !== prior.passwordHash)
          throw new UnauthorizedException("Credential changed");
        c.passwordHash = hash;
        c.tokenVersion++;
      },
    );
    return { message: "Password updated. Sign in again." };
  }
  async logout(actor: Actor) {
    await mutation(
      this.db,
      [],
      actor,
      ["customer", "staff", "manager", "superAdmin"],
      (s) => {
        s.auth_credentials.find((c) => c.userId === actor.id)!.tokenVersion++;
      },
    );
    return { message: "All tokens revoked" };
  }
  private token(user: Row, ver: number) {
    return this.jwt.signAsync({
      sub: user.id,
      role: user.role,
      branchId: user.branchId,
      ver,
    });
  }
}
