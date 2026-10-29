const { collections } = require("../../dist/firestore/firestore.store");
class MemoryFirestore {
  constructor(seed = {}) {
    this.state = Object.assign(
      Object.fromEntries(collections.map((n) => [n, []])),
      structuredClone(seed),
    );
    this.tail = Promise.resolve();
  }
  async read(names, work) {
    return work(structuredClone(this.state));
  }
  mutate(names, work) {
    const result = this.tail.then(async () => {
      const next = structuredClone(this.state);
      const result = await work(next);
      this.state = next;
      return structuredClone(result);
    });
    this.tail = result.catch(() => {});
    return result;
  }
}
module.exports = { MemoryFirestore };
