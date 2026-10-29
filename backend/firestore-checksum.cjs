const { Timestamp } = require("firebase-admin/firestore");
const { createHash } = require("node:crypto");
function requireThat(condition, message) {
  if (!condition) throw new Error(message);
}
function canonical(value) {
  if (value instanceof Timestamp)
    return ["timestamp", value.seconds, value.nanoseconds];
  if (typeof value === "bigint") return ["integer", value.toString()];
  if (typeof value === "number" && Number.isInteger(value))
    return ["integer", value.toString()];
  if (Array.isArray(value)) return ["array", value.map(canonical)];
  if (value && typeof value === "object")
    return [
      "map",
      Object.keys(value)
        .sort()
        .map((key) => [key, canonical(value[key])]),
    ];
  return [typeof value, value];
}
function checksum(docs) {
  return createHash("sha256")
    .update(
      JSON.stringify(
        [...docs]
          .sort((a, b) => a.id.localeCompare(b.id))
          .map((doc) => [doc.id, canonical(doc.data)]),
      ),
    )
    .digest("hex");
}
async function verifyCollections(db, summary) {
  for (const collection of summary) {
    const result = await db.collection(collection.name).get();
    const docs = result.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
    requireThat(
      BigInt(result.size) === BigInt(collection.count) &&
        checksum(docs) === collection.checksum,
      "Verification failed for " + collection.name,
    );
    console.log(collection.name + ": " + result.size + " verified");
  }
}

module.exports = { canonical, checksum, verifyCollections };
