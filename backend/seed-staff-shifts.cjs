require("dotenv/config");
const fs = require("node:fs");
const { Client } = require("pg");
const db = new Client({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: true, ca: fs.readFileSync("./ca.pem", "utf8") },
});
(async () => {
  try {
    await db.connect();
    let inserted = 0;
    const { rows: staff } = await db.query(
      "SELECT id,branch_id FROM users WHERE role='staff' AND is_approved ORDER BY branch_id,id",
    );
    for (const user of staff) {
      await db.query("BEGIN");
      const {
        rows: [settings],
      } = await db.query(
        "SELECT opening_minute,closing_minute,closed_dates::text[] AS closed_dates,closed_weekdays FROM shop_settings WHERE branch_id=$1 FOR SHARE",
        [user.branch_id],
      );
      await db.query("SELECT id FROM users WHERE id=$1 FOR UPDATE", [user.id]);
      for (let day = 1; day <= 7; day++) {
        const date = new Date(Date.now() + 7 * 3600000 + day * 86400000)
          .toISOString()
          .slice(0, 10);
        if (
          settings.closed_dates.includes(date) ||
          settings.closed_weekdays.includes(
            new Date(date + "T00:00:00Z").getUTCDay() || 7,
          )
        )
          continue;
        const clock = (minutes) =>
          String(Math.floor(minutes / 60)).padStart(2, "0") +
          ":" +
          String(minutes % 60).padStart(2, "0") +
          ":00";
        const start = date + "T" + clock(settings.opening_minute) + "+07:00",
          end = date + "T" + clock(settings.closing_minute) + "+07:00";
        const r = await db.query(
          "INSERT INTO staff_shifts(id,staff_id,branch_id,start_at,end_at) SELECT $1,$2,$3,$4,$5 WHERE NOT EXISTS(SELECT 1 FROM staff_shifts WHERE staff_id=$2 AND start_at<$5 AND end_at>$4) ON CONFLICT DO NOTHING",
          [
            "seed-shift-" + user.id + "-" + date,
            user.id,
            user.branch_id,
            start,
            end,
          ],
        );
        inserted += r.rowCount;
      }
      await db.query("COMMIT");
    }
    console.log(
      JSON.stringify({
        inserted,
        staff: staff.length,
        distribution: (
          await db.query(
            "SELECT branch_id,count(*)::int AS shifts FROM staff_shifts GROUP BY branch_id ORDER BY branch_id",
          )
        ).rows,
      }),
    );
  } catch (e) {
    await db.query("ROLLBACK").catch(() => {});
    console.error("Seed failed: " + e.code);
    process.exitCode = 1;
  } finally {
    await db.end();
  }
})();
