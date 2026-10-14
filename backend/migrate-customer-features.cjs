require("dotenv/config");
const fs = require("node:fs"),
  path = require("node:path");
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
    const duplicates = await client.query(
      "SELECT branch_id FROM users WHERE role='manager' GROUP BY branch_id HAVING count(*)>1",
    );
    if (duplicates.rowCount)
      throw Object.assign(new Error(), { code: "DUPLICATE_BRANCH_MANAGER" });
    await client.query(
      fs.readFileSync(
        path.join(__dirname, "../database/006_reviews_and_branch_manager.sql"),
        "utf8",
      ),
    );
    console.log("Migration 006 committed: reviews and one manager per branch.");
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    console.error(
      "Migration failed; no account/data removed. Code: " + error.code,
    );
    process.exitCode = 1;
  } finally {
    await client.end();
  }
})();
