require("dotenv/config");
const fs = require("node:fs");
const path = require("node:path");
const { Client } = require("pg");
(async () => {
  const c = new Client({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    ssl: {
      rejectUnauthorized: true,
      ca: fs.readFileSync("./ca.pem").toString(),
    },
  });
  try {
    await c.connect();
    await c.query(
      fs.readFileSync(
        path.join(__dirname, "../database/005_leave_intervals.sql"),
        "utf8",
      ),
    );
    console.log("Approved Phase 3 migration committed");
  } catch (e) {
    await c.query("ROLLBACK").catch(() => {});
    console.error("Migration rolled back: " + e.code);
    process.exitCode = 1;
  } finally {
    await c.end();
  }
})();
