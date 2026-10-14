// Verifies the configured database without leaving test reviews/accounts behind.
require("dotenv/config");
const fs = require("node:fs"),
  path = require("node:path"),
  assert = require("node:assert/strict");
const { Client } = require("pg");
(async () => {
  const client = new Client({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    ssl: {
      rejectUnauthorized: true,
      ca: fs.readFileSync(path.join(__dirname, "ca.pem"), "utf8"),
    },
  });
  try {
    await client.connect();
    const invalid =
      await client.query(`SELECT b.id FROM branches b LEFT JOIN users u
      ON u.branch_id=b.id AND u.role='manager' GROUP BY b.id HAVING count(u.id)<>1`);
    assert.equal(
      invalid.rowCount,
      0,
      "Every existing branch must have exactly one manager",
    );
    console.log("Verified: every existing branch has one separate Manager.");
    await client.query("BEGIN");
    const {
      rows: [a],
    } = await client.query(
      "SELECT id,branch_id,customer_id FROM appointments WHERE status='completed' AND customer_id IS NOT NULL LIMIT 1",
    );
    if (a) {
      await client.query(
        `INSERT INTO reviews(appointment_id,target_type,target_id,customer_id,rating,comment)
        VALUES($1,'branch',$2,$3,5,'verification - rolled back') ON CONFLICT DO NOTHING`,
        [a.id, a.branch_id, a.customer_id],
      );
      for (const [targetId, expected] of [
        [a.branch_id, "23505"],
        ["invalid-target", "23514"],
      ]) {
        await client.query("SAVEPOINT review_check");
        let code;
        try {
          await client.query(
            `INSERT INTO reviews(appointment_id,target_type,target_id,customer_id,rating)
          VALUES($1,'branch',$2,$3,5)`,
            [a.id, targetId, a.customer_id],
          );
        } catch (error) {
          code = error.code;
        }
        await client.query("ROLLBACK TO SAVEPOINT review_check");
        assert.equal(code, expected);
      }
      console.log(
        "Verified: real PostgreSQL review insert, duplicate guard and target integrity; all test writes rolled back.",
      );
    } else {
      console.log(
        "No completed appointment available for transactional insert verification.",
      );
    }
    await client.query("ROLLBACK");
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    console.error("Verification failed: " + (error.code ?? error.message));
    process.exitCode = 1;
  } finally {
    await client.end();
  }
})();
