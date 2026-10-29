import { ForbiddenException, Injectable } from "@nestjs/common";
import { Actor } from "../auth/auth.decorators";
import { FirestoreStore, Row, State } from "../firestore/firestore.store";
import { page, requireRole, sorted } from "../firestore/rules";
import { BossReportQueryDto, ReportQueryDto } from "./report.dto";
import { reportPeriods, reportRange } from "./report-period";
type Scope = { branchId: string | null; staffId: string | null };
type Period = { from: Date; to: Date };
const names = ["appointments", "users", "branches"] as const;
const total = (rows: Row[]) =>
  rows.reduce((sum, r) => sum + BigInt(r.totalPriceVnd), 0n);
@Injectable()
export class ReportsService {
  constructor(private readonly db: FirestoreStore) {}
  private scope(
    actor: Actor,
    role: "manager" | "staff" | "superAdmin",
    branchId?: string,
  ): Scope {
    requireRole(actor, [role]);
    if (role !== "superAdmin" && !actor.branchId)
      throw new ForbiddenException("Branch required");
    return {
      branchId: role === "superAdmin" ? (branchId ?? null) : actor.branchId!,
      staffId: role === "staff" ? actor.id : null,
    };
  }
  private rows(s: State, period: Period, scope: Scope) {
    return s.appointments.filter(
      (r) =>
        +r.startAt >= +period.from &&
        +r.startAt < +period.to &&
        (!scope.branchId || r.branchId === scope.branchId) &&
        (!scope.staffId || r.staffId === scope.staffId),
    );
  }
  private metrics(s: State, p: Period, scope: Scope) {
    const rows = this.rows(s, p, scope),
      done = rows.filter((r) => r.status === "completed");
    return {
      revenueVnd: total(done).toString(),
      appointmentCount: rows.length,
      completedCount: done.length,
      cancelledCount: rows.filter((r) => r.status === "cancelled").length,
      customerCount: new Set(
        done.filter((r) => r.customerId !== null).map((r) => r.customerId),
      ).size,
      walkInCount: done.filter((r) => r.customerId === null).length,
    };
  }
  private ledger(
    s: State,
    p: Period,
    scope: Scope,
    q: ReportQueryDto,
    status?: string,
    upcoming = false,
  ) {
    const rows = this.rows(s, p, scope).filter(
      (r) =>
        (!status || r.status === status) &&
        (!upcoming ||
          (["pending", "confirmed"].includes(r.status) &&
            +r.endAt > Date.now())),
    );
    return page(sorted(rows, "startAt", !upcoming), q).map((r) => ({
      id: r.id,
      branchId: r.branchId,
      branchName:
        s.branches.find((b) => b.id === r.branchId)?.name ?? r.branchId,
      staffId: r.staffId,
      staffName: s.users.find((u) => u.id === r.staffId)?.name ?? r.staffId,
      customerId: r.customerId,
      customerName: r.customerName,
      startAt: r.startAt,
      endAt: r.endAt,
      status: r.status,
      totalPriceVnd: String(r.totalPriceVnd),
      services: r.services.map((i: Row) => ({
        serviceId: i.serviceId,
        name: i.serviceNameSnapshot,
      })),
    }));
  }
  private rankings(
    s: State,
    p: Period,
    scope: Scope,
    kind: "staff" | "branch",
    byCount = false,
  ) {
    const rows = this.rows(s, p, scope).filter((r) => r.status === "completed"),
      key = kind === "staff" ? "staffId" : "branchId";
    const result = [...new Set(rows.map((r) => r[key]))].map((id) => {
      const group = rows.filter((r) => r[key] === id);
      return kind === "branch"
        ? {
            branchId: id,
            branchName: s.branches.find((b) => b.id === id)?.name ?? id,
            revenueVnd: total(group).toString(),
            completedCount: group.length,
          }
        : {
            staffId: id,
            staffName: s.users.find((u) => u.id === id)?.name ?? id,
            branches: [...new Set<string>(group.map((r) => r.branchId))]
              .sort()
              .map((branchId) => ({
                branchId,
                branchName:
                  s.branches.find((b) => b.id === branchId)?.name ?? branchId,
              })),
            revenueVnd: total(group).toString(),
            completedCount: group.length,
          };
    });
    return result.sort(
      (a: Row, b: Row) =>
        (byCount ? b.completedCount - a.completedCount : 0) ||
        (BigInt(a.revenueVnd) > BigInt(b.revenueVnd)
          ? -1
          : BigInt(a.revenueVnd) < BigInt(b.revenueVnd)
            ? 1
            : 0) ||
        (!byCount && kind === "staff"
          ? b.completedCount - a.completedCount
          : 0) ||
        String(a[key]).localeCompare(String(b[key])),
    );
  }
  dashboard(actor: Actor, boss = false, branchId?: string) {
    const scope = this.scope(actor, boss ? "superAdmin" : "manager", branchId),
      periods = reportPeriods();
    return this.db.read(names, (s) => ({
      branchId: scope.branchId,
      timezone: "Asia/Ho_Chi_Minh",
      periods,
      today: this.metrics(s, periods.day, scope),
      month: this.metrics(s, periods.month, scope),
      previousMonth: this.metrics(s, periods.previousMonth, scope),
      upcoming: this.ledger(
        s,
        periods.day,
        scope,
        { page: 1, limit: 100 },
        undefined,
        true,
      ),
    }));
  }
  revenue(actor: Actor, q: ReportQueryDto) {
    const scope = this.scope(actor, "manager"),
      period = reportRange(q);
    return this.db.read(names, (s) => ({
      branchId: scope.branchId,
      period,
      ...this.metrics(s, period, scope),
      transactions: this.ledger(s, period, scope, q, "completed"),
      staffRanking: this.rankings(s, period, scope, "staff").slice(0, 100),
      page: q.page,
      limit: q.limit,
    }));
  }
  leaderboards(actor: Actor, q: BossReportQueryDto) {
    const scope = this.scope(actor, "superAdmin", q.branchId),
      period = reportRange(q);
    return this.db.read(names, (s) => ({
      period,
      branches: this.rankings(s, period, scope, "branch").slice(0, q.limit),
      staff: this.rankings(s, period, scope, "staff", true).slice(0, q.limit),
    }));
  }
  masterLedger(actor: Actor, q: BossReportQueryDto) {
    const scope = this.scope(actor, "superAdmin", q.branchId),
      period = reportRange(q);
    return this.db.read(names, (s) => ({
      period,
      page: q.page,
      limit: q.limit,
      appointments: this.ledger(s, period, scope, q, q.status),
    }));
  }
  commissions(actor: Actor, q: BossReportQueryDto) {
    const scope = this.scope(actor, "superAdmin", q.branchId),
      period = reportRange(q);
    return this.db.read(names, (s) => ({
      period,
      ratePercent: 30,
      isEstimate: true,
      staff: page(
        this.rankings(s, period, scope, "staff").sort((a: Row, b: Row) =>
          BigInt(a.revenueVnd) === BigInt(b.revenueVnd)
            ? a.staffId.localeCompare(b.staffId)
            : BigInt(a.revenueVnd) > BigInt(b.revenueVnd)
              ? -1
              : 1,
        ),
        q,
      ).map((r) => ({
        ...r,
        commissionVnd: ((BigInt(r.revenueVnd) * 30n) / 100n).toString(),
      })),
    }));
  }
  earnings(actor: Actor, q: ReportQueryDto) {
    const scope = this.scope(actor, "staff"),
      periods = reportPeriods(),
      period = reportRange(q);
    return this.db.read(names, (s) => ({
      periods,
      today: this.metrics(s, periods.day, scope),
      month: this.metrics(s, periods.month, scope),
      previousMonth: this.metrics(s, periods.previousMonth, scope),
      period,
      transactions: this.ledger(s, period, scope, q, "completed"),
      page: q.page,
      limit: q.limit,
    }));
  }
  profileStats(actor: Actor, q: ReportQueryDto) {
    const scope = this.scope(actor, "staff"),
      month = reportPeriods().month;
    return this.db.read(names, (s) => {
      const rows = s.appointments.filter(
          (r) =>
            r.staffId === scope.staffId &&
            r.branchId === scope.branchId &&
            r.status === "completed",
        ),
        reviews = rows.filter((r) => r.isReviewed && r.rating !== null);
      const customers = [
        ...new Set(
          rows.filter((r) => r.customerId !== null).map((r) => r.customerId),
        ),
      ]
        .map((customerId) => {
          const visits = rows.filter((r) => r.customerId === customerId);
          return {
            customerId,
            customerName:
              s.users.find((u) => u.id === customerId)?.name ?? customerId,
            completedVisits: visits.length,
            totalSpentVnd: total(visits).toString(),
            lastVisitAt: new Date(Math.max(...visits.map((r) => +r.endAt))),
          };
        })
        .sort(
          (a, b) =>
            +b.lastVisitAt - +a.lastVisitAt ||
            a.customerId.localeCompare(b.customerId),
        );
      return {
        month,
        monthly: this.metrics(s, month, scope),
        reviewCount: reviews.length,
        averageRating: reviews.length
          ? reviews.reduce((n, r) => n + r.rating, 0) / reviews.length
          : null,
        registeredCustomerCount: customers.length,
        walkInCompletedCount: rows.filter((r) => r.customerId === null).length,
        customers: page(customers, q),
        page: q.page,
        limit: q.limit,
      };
    });
  }
}
