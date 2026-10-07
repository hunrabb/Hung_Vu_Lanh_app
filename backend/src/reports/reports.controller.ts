import { Controller, Get, Query } from "@nestjs/common";
import { Actor, CurrentUser, Roles } from "../auth/auth.decorators";
import { BossReportQueryDto, ReportQueryDto } from "./report.dto";
import { ReportsService } from "./reports.service";
@Controller()
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}
  @Roles("manager") @Get("manager/dashboard") managerDashboard(
    @CurrentUser() actor: Actor,
  ) {
    return this.reports.dashboard(actor);
  }
  @Roles("manager") @Get("manager/revenue") revenue(
    @CurrentUser() actor: Actor,
    @Query() q: ReportQueryDto,
  ) {
    return this.reports.revenue(actor, q);
  }
  @Roles("boss") @Get("boss/dashboard") bossDashboard(
    @CurrentUser() actor: Actor,
    @Query() q: BossReportQueryDto,
  ) {
    return this.reports.dashboard(actor, true, q.branchId);
  }
  @Roles("boss") @Get("boss/leaderboards") leaderboards(
    @CurrentUser() actor: Actor,
    @Query() q: BossReportQueryDto,
  ) {
    return this.reports.leaderboards(actor, q);
  }
  @Roles("boss") @Get("boss/appointments") ledger(
    @CurrentUser() actor: Actor,
    @Query() q: BossReportQueryDto,
  ) {
    return this.reports.masterLedger(actor, q);
  }
  @Roles("boss") @Get("boss/commissions") commissions(
    @CurrentUser() actor: Actor,
    @Query() q: BossReportQueryDto,
  ) {
    return this.reports.commissions(actor, q);
  }
  @Roles("staff") @Get("staff/me/earnings") earnings(
    @CurrentUser() actor: Actor,
    @Query() q: ReportQueryDto,
  ) {
    return this.reports.earnings(actor, q);
  }
  @Roles("staff") @Get("staff/me/profile-stats") profile(
    @CurrentUser() actor: Actor,
    @Query() q: ReportQueryDto,
  ) {
    return this.reports.profileStats(actor, q);
  }
}
