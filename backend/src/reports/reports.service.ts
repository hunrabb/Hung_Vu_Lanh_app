import { ForbiddenException, Injectable } from "@nestjs/common";
import { DataSource, EntityManager } from "typeorm";
import { Actor } from "../auth/auth.decorators";
import { requireRole } from "../common/mutations";
import { BossReportQueryDto, ReportQueryDto } from "./report.dto";
import { reportPeriods, reportRange } from "./report-period";
type Scope = { branchId: string | null; staffId: string | null };
type Period = { from: Date; to: Date };
// Aggregate the one-row-per-appointment source BEFORE any service-item enrichment.
const BASE =
  "FROM appointments a WHERE a.start_at >= $1 AND a.start_at < $2 AND ($3::text IS NULL OR a.branch_id=$3) AND ($4::text IS NULL OR a.staff_id=$4)";
const BRANCH_TAGS =
  "(SELECT jsonb_agg(jsonb_build_object('branchId',b.id,'branchName',b.name) ORDER BY b.id) FROM branches b WHERE b.id=ANY(t.branch_ids))";
@Injectable()
export class ReportsService {
  constructor(private readonly db: DataSource) {}
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
  private read<T>(work: (manager: EntityManager) => Promise<T>) {
    return this.db.transaction("REPEATABLE READ", work);
  }
  private args(period: Period, scope: Scope) {
    return [period.from, period.to, scope.branchId, scope.staffId];
  }
  private async metrics(m: EntityManager, period: Period, scope: Scope) {
    const [row] = await m.query(
      `SELECT COALESCE(SUM(a.total_price_vnd) FILTER(WHERE a.status='completed'),0)::text AS "revenueVnd",COUNT(*)::int AS "appointmentCount",COUNT(*) FILTER(WHERE a.status='completed')::int AS "completedCount",COUNT(*) FILTER(WHERE a.status='cancelled')::int AS "cancelledCount" ${BASE}`,
      this.args(period, scope),
    );
    return row;
  }
  private ledger(
    m: EntityManager,
    period: Period,
    scope: Scope,
    q: ReportQueryDto,
    status: string | null = null,
    upcoming = false,
  ) {
    // Correlated JSON subquery returns one column per appointment, never multiplying rows.
    return m.query(
      `SELECT a.id,a.branch_id AS "branchId",b.name AS "branchName",a.staff_id AS "staffId",s.name AS "staffName",a.customer_id AS "customerId",a.customer_name AS "customerName",a.start_at AS "startAt",a.end_at AS "endAt",a.status,a.total_price_vnd::text AS "totalPriceVnd",COALESCE((SELECT jsonb_agg(jsonb_build_object('serviceId',i.service_id,'name',i.service_name_snapshot) ORDER BY i.position) FROM appointment_services i WHERE i.appointment_id=a.id),'[]'::jsonb) AS services
   FROM appointments a JOIN branches b ON b.id=a.branch_id JOIN users s ON s.id=a.staff_id
   WHERE a.start_at >= $1 AND a.start_at < $2 AND ($3::text IS NULL OR a.branch_id=$3) AND ($4::text IS NULL OR a.staff_id=$4) AND ($5::text IS NULL OR a.status=$5) ${upcoming ? "AND a.status IN ('pending','confirmed') AND a.end_at>$8" : ""}
   ORDER BY a.start_at ${upcoming ? "ASC" : "DESC"},a.id ASC LIMIT $6 OFFSET $7`,
      [
        ...this.args(period, scope),
        status,
        q.limit,
        (q.page - 1) * q.limit,
        ...(upcoming ? [new Date()] : []),
      ],
    );
  }
  private staffRanking(
    m: EntityManager,
    period: Period,
    scope: Scope,
    limit = 100,
    byCount = false,
  ) {
    return m.query(
      `WITH totals AS (SELECT a.staff_id,array_agg(DISTINCT a.branch_id) AS branch_ids,COUNT(*)::int AS completed_count,SUM(a.total_price_vnd)::text AS revenue ${BASE} AND a.status='completed' GROUP BY a.staff_id)
   SELECT t.staff_id AS "staffId",s.name AS "staffName",${BRANCH_TAGS} AS branches,t.completed_count AS "completedCount",t.revenue AS "revenueVnd" FROM totals t JOIN users s ON s.id=t.staff_id ORDER BY ${byCount ? "t.completed_count DESC,t.revenue::numeric DESC" : "t.revenue::numeric DESC,t.completed_count DESC"},t.staff_id LIMIT $5`,
      [...this.args(period, scope), limit],
    );
  }
  dashboard(actor: Actor, boss = false, branchId?: string) {
    const scope = this.scope(actor, boss ? "superAdmin" : "manager", branchId),
      periods = reportPeriods();
    return this.read(async (m) => ({
      branchId: scope.branchId,
      timezone: "Asia/Ho_Chi_Minh",
      periods,
      today: await this.metrics(m, periods.day, scope),
      month: await this.metrics(m, periods.month, scope),
      upcoming: await this.ledger(
        m,
        periods.day,
        scope,
        { page: 1, limit: 100 },
        null,
        true,
      ),
    }));
  }
  revenue(actor: Actor, q: ReportQueryDto) {
    const scope = this.scope(actor, "manager"),
      period = reportRange(q);
    return this.read(async (m) => ({
      branchId: scope.branchId,
      period,
      ...(await this.metrics(m, period, scope)),
      transactions: await this.ledger(m, period, scope, q, "completed"),
      staffRanking: await this.staffRanking(m, period, scope),
      page: q.page,
      limit: q.limit,
    }));
  }
  leaderboards(actor: Actor, q: BossReportQueryDto) {
    const scope = this.scope(actor, "superAdmin", q.branchId),
      period = reportRange(q);
    return this.read(async (m) => ({
      period,
      branches: await m.query(
        `WITH totals AS (SELECT a.branch_id,SUM(a.total_price_vnd)::text AS revenue,COUNT(*)::int AS completed_count ${BASE} AND a.status='completed' GROUP BY a.branch_id) SELECT b.id AS "branchId",b.name AS "branchName",t.revenue AS "revenueVnd",t.completed_count AS "completedCount" FROM totals t JOIN branches b ON b.id=t.branch_id ORDER BY t.revenue::numeric DESC,b.id LIMIT $5`,
        [...this.args(period, scope), q.limit],
      ),
      staff: await this.staffRanking(m, period, scope, q.limit, true),
    }));
  }
  masterLedger(actor: Actor, q: BossReportQueryDto) {
    const scope = this.scope(actor, "superAdmin", q.branchId),
      period = reportRange(q);
    return this.read(async (m) => ({
      period,
      page: q.page,
      limit: q.limit,
      appointments: await this.ledger(m, period, scope, q, q.status ?? null),
    }));
  }
  commissions(actor: Actor, q: BossReportQueryDto) {
    const scope = this.scope(actor, "superAdmin", q.branchId),
      period = reportRange(q);
    return this.read(async (m) => ({
      period,
      ratePercent: 30,
      isEstimate: true,
      staff: await m.query(
        `WITH totals AS (SELECT a.staff_id,array_agg(DISTINCT a.branch_id) AS branch_ids,COUNT(*)::int AS completed_count,SUM(a.total_price_vnd) AS revenue ${BASE} AND a.status='completed' GROUP BY a.staff_id) SELECT t.staff_id AS "staffId",s.name AS "staffName",${BRANCH_TAGS} AS branches,t.completed_count AS "completedCount",t.revenue::text AS "revenueVnd",floor(t.revenue*30/100)::text AS "commissionVnd" FROM totals t JOIN users s ON s.id=t.staff_id ORDER BY t.revenue DESC,t.staff_id LIMIT $5 OFFSET $6`,
        [...this.args(period, scope), q.limit, (q.page - 1) * q.limit],
      ),
    }));
  }
  earnings(actor: Actor, q: ReportQueryDto) {
    const scope = this.scope(actor, "staff"),
      periods = reportPeriods(),
      period = reportRange(q);
    return this.read(async (m) => ({
      periods,
      today: await this.metrics(m, periods.day, scope),
      month: await this.metrics(m, periods.month, scope),
      period,
      transactions: await this.ledger(m, period, scope, q, "completed"),
      page: q.page,
      limit: q.limit,
    }));
  }
  profileStats(actor: Actor, q: ReportQueryDto) {
    const scope = this.scope(actor, "staff"),
      month = reportPeriods().month;
    return this.read(async (m) => {
      const [reviews] = await m.query(
        `SELECT COUNT(*)::int AS "reviewCount",AVG(a.rating)::float8 AS "averageRating" FROM appointments a WHERE a.staff_id=$1 AND a.branch_id=$2 AND a.status='completed' AND a.is_reviewed AND a.rating IS NOT NULL`,
        [scope.staffId, scope.branchId],
      );
      const [customers] = await m.query(
        `SELECT COUNT(DISTINCT customer_id)::int AS "registeredCustomerCount",COUNT(*) FILTER(WHERE customer_id IS NULL)::int AS "walkInCompletedCount" FROM appointments WHERE staff_id=$1 AND branch_id=$2 AND status='completed'`,
        [scope.staffId, scope.branchId],
      );
      const list = await m.query(
        `WITH totals AS (SELECT customer_id,COUNT(*)::int AS visits,SUM(total_price_vnd)::text AS revenue,MAX(end_at) AS last_visit FROM appointments WHERE staff_id=$1 AND branch_id=$2 AND status='completed' AND customer_id IS NOT NULL GROUP BY customer_id) SELECT t.customer_id AS "customerId",u.name AS "customerName",t.visits AS "completedVisits",t.revenue AS "totalSpentVnd",t.last_visit AS "lastVisitAt" FROM totals t JOIN users u ON u.id=t.customer_id ORDER BY t.last_visit DESC,t.customer_id LIMIT $3 OFFSET $4`,
        [scope.staffId, scope.branchId, q.limit, (q.page - 1) * q.limit],
      );
      return {
        month,
        monthly: await this.metrics(m, month, scope),
        ...reviews,
        ...customers,
        customers: list,
        page: q.page,
        limit: q.limit,
      };
    });
  }
}
