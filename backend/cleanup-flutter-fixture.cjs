// Removes only the explicitly owned temporary fixture from the opt-in Flutter test.
function ownsFixture(user, id) {
  return (
    !!user &&
    user.id === id &&
    user.name === "Phase6 Flutter fixture" &&
    /^phase6-\d+@example\.com$/.test(user.email)
  );
}
async function cleanup(db, id, appointmentIds) {
  const root = db.collection("users").doc(id),
    fence = db.doc("_runtime/constraints");
  return db.runTransaction(async (tx) => {
    await tx.get(fence);
    const user = await tx.get(root);
    if (!user.exists || !ownsFixture(user.data(), id))
      throw new Error("Refusing to delete an unowned fixture");
    const rows = {};
    for (const name of ["appointments", "staff_shifts", "staff_leave_requests"])
      rows[name] = (
        await tx.get(db.collection(name).where("staffId", "==", id))
      ).docs;
    const appointmentSet = new Set(appointmentIds);
    if (rows.appointments.some((doc) => !appointmentSet.has(doc.id)))
      throw new Error("Fixture has unexpected appointments; cleanup refused");
    const ownedAppointmentIds = new Set(rows.appointments.map((doc) => doc.id));
    const reviews = (await tx.get(db.collection("reviews"))).docs.filter(
      (doc) => ownedAppointmentIds.has(doc.data().appointmentId),
    );
    for (const docs of Object.values(rows))
      for (const doc of docs) tx.delete(doc.ref);
    for (const doc of reviews) tx.delete(doc.ref);
    tx.delete(db.collection("auth_credentials").doc(id));
    tx.delete(root);
    tx.set(fence, {
      changedAt: require("firebase-admin/firestore").Timestamp.now(),
    });
  });
}
async function main() {
  require("dotenv/config");
  const {
    initializeApp,
    applicationDefault,
    deleteApp,
  } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const id = process.argv[2],
    ids = JSON.parse(process.argv[3] || "[]");
  if (
    !id ||
    id.includes("/") ||
    !Array.isArray(ids) ||
    ids.some((id) => typeof id !== "string" || !id || id.includes("/"))
  )
    throw new Error("Invalid cleanup arguments");
  if (!process.env.FIREBASE_PROJECT_ID || !process.env.FIRESTORE_DATABASE_ID)
    throw new Error("Firebase project and database required");
  const app = initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID,
    credential: applicationDefault(),
  });
  try {
    await cleanup(
      getFirestore(app, process.env.FIRESTORE_DATABASE_ID),
      id,
      ids,
    );
  } finally {
    await deleteApp(app);
  }
}
module.exports = { ownsFixture, cleanup };
if (require.main === module)
  main().catch((error) => {
    console.error(error.code || error.message);
    process.exitCode = 1;
  });
