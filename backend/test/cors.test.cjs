const { test } = require("node:test");
const assert = require("node:assert/strict");
const { corsOrigin } = require("../dist/config/cors");
test("CORS keeps local defaults and validates explicit deployment origins", () => {
  assert.equal(corsOrigin(undefined), true);
  assert.deepEqual(corsOrigin("https://app.example.com, http://localhost:8080,https://app.example.com"), ["https://app.example.com", "http://localhost:8080"]);
  for (const invalid of ["*", "https://app.example.com/path", "https://app.example.com/", "file:///tmp", " , "]) {
    assert.throws(() => corsOrigin(invalid));
  }
});
