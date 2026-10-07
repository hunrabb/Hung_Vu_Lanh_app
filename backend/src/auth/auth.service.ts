import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { DataSource, EntityManager } from "typeorm";
import { randomUUID } from "node:crypto";
import { User } from "../users/user.entity";
import { Credential } from "./credential.entity";
import { Actor } from "./auth.decorators";
import { LoginDto, RegisterDto, PasswordDto } from "./auth.dto";
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
    private readonly db: DataSource,
    private readonly jwt: JwtService,
  ) {}
  profile(user: User) {
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      branchId: user.branchId,
      phone: user.phone,
      isApproved: user.isApproved,
      createdAt: user.createdAt,
    };
  }
  async register(dto: RegisterDto) {
    validateNewPassword(dto.password);
    if (!dto.name.trim()) throw new BadRequestException("Name is required");
    const hash = await hashPassword(dto.password);
    try {
      const user = await this.db.transaction(async (manager) => {
        const user = manager.create(User, {
          id: randomUUID(),
          name: dto.name.trim(),
          email: dto.email.trim().toLowerCase(),
          role: "customer",
          branchId: null,
          phone: null,
          isApproved: true,
          createdAt: new Date(),
        });
        await manager.insert(User, user);
        await manager.insert(Credential, {
          userId: user.id,
          passwordHash: hash,
          tokenVersion: 0,
        });
        return user;
      });
      return {
        accessToken: await this.token(user, 0),
        user: this.profile(user),
      };
    } catch (error) {
      if ((error as { code?: string }).code === "23505")
        throw new ConflictException("Email already registered");
      throw error;
    }
  }
  async login(dto: LoginDto) {
    const user = await this.db
      .getRepository(User)
      .findOneBy({ email: dto.email.trim().toLowerCase() });
    if (!user || !user.isApproved)
      throw new UnauthorizedException("Invalid email or password");
    const credential = await this.db.getRepository(Credential).findOne({
      where: { userId: user.id },
      select: { userId: true, passwordHash: true, tokenVersion: true },
    });
    if (
      !credential ||
      !(await verifyPassword(dto.password, credential.passwordHash))
    )
      throw new UnauthorizedException("Invalid email or password");
    let hash = credential.passwordHash;
    if (hash.startsWith("$scrypt$")) {
      // Never truncate a legacy password during bcrypt migration.
      validateNewPassword(dto.password);
      hash = await hashPassword(dto.password);
    }
    return this.db.transaction(async (manager) => {
      const current = await this.lockUser(manager, user.id);
      const stored = await this.lockCredential(manager, user.id);
      if (
        !current.isApproved ||
        stored.passwordHash !== credential.passwordHash ||
        stored.tokenVersion !== credential.tokenVersion
      )
        throw new UnauthorizedException("Account changed; sign in again");
      if (hash !== stored.passwordHash)
        await manager.update(
          Credential,
          { userId: user.id },
          { passwordHash: hash },
        );
      return {
        accessToken: await this.token(current, stored.tokenVersion),
        user: this.profile(current),
      };
    });
  }
  async validateToken(payload: Claims): Promise<Actor> {
    if (typeof payload.sub !== "string" || !Number.isInteger(payload.ver))
      throw new UnauthorizedException();
    const row = await this.db
      .getRepository(User)
      .createQueryBuilder("u")
      .innerJoin(Credential, "c", "c.userId=u.id")
      .where("u.id=:id", { id: payload.sub })
      .andWhere("u.isApproved=TRUE")
      .andWhere("c.tokenVersion=:version", { version: payload.ver })
      .getOne();
    if (!row || row.role !== payload.role || row.branchId !== payload.branchId)
      throw new UnauthorizedException("Token revoked or account changed");
    return { ...row, tokenVersion: payload.ver };
  }
  async password(actor: Actor, dto: PasswordDto) {
    validateNewPassword(dto.newPassword);
    if (dto.oldPassword === dto.newPassword)
      throw new BadRequestException("New password must be different");
    const stored = await this.db.getRepository(Credential).findOne({
      where: { userId: actor.id },
      select: { userId: true, passwordHash: true, tokenVersion: true },
    });
    if (
      !stored ||
      !(await verifyPassword(dto.oldPassword, stored.passwordHash))
    )
      throw new UnauthorizedException("Incorrect current password");
    const hash = await hashPassword(dto.newPassword);
    await this.db.transaction(async (manager) => {
      const current = await this.lockUser(manager, actor.id);
      const locked = await this.lockCredential(manager, actor.id);
      this.assertActor(actor, current, locked);
      if (locked.passwordHash !== stored.passwordHash)
        throw new UnauthorizedException("Credential changed");
      await manager.update(
        Credential,
        { userId: actor.id },
        { passwordHash: hash, tokenVersion: locked.tokenVersion + 1 },
      );
    });
    return { message: "Password updated. Sign in again." };
  }
  async logout(actor: Actor) {
    await this.db.transaction(async (manager) => {
      const current = await this.lockUser(manager, actor.id);
      const credential = await this.lockCredential(manager, actor.id);
      this.assertActor(actor, current, credential);
      await manager.update(
        Credential,
        { userId: actor.id },
        { tokenVersion: credential.tokenVersion + 1 },
      );
    });
    return { message: "All tokens revoked" };
  }
  private token(user: User, version: number) {
    return this.jwt.signAsync({
      sub: user.id,
      role: user.role,
      branchId: user.branchId,
      ver: version,
    });
  }
  private async lockUser(manager: EntityManager, id: string) {
    const user = await manager.findOne(User, {
      where: { id },
      lock: { mode: "pessimistic_write" },
    });
    if (!user) throw new UnauthorizedException();
    return user;
  }
  private async lockCredential(manager: EntityManager, id: string) {
    const credential = await manager.findOne(Credential, {
      where: { userId: id },
      select: { userId: true, passwordHash: true, tokenVersion: true },
      lock: { mode: "pessimistic_write" },
    });
    if (!credential) throw new UnauthorizedException();
    return credential;
  }
  private assertActor(actor: Actor, user: User, credential: Credential) {
    if (
      !user.isApproved ||
      user.role !== actor.role ||
      user.branchId !== actor.branchId ||
      credential.tokenVersion !== actor.tokenVersion
    )
      throw new UnauthorizedException("Token revoked");
  }
}
