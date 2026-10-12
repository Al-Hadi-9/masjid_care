"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteMasjid = void 0;
const app_1 = require("firebase-admin/app");
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
/** Delete one masjid and all of its linked admin authentication accounts. */
exports.deleteMasjid = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    const masjidToken = String(request.data?.masjidToken ?? "")
        .trim()
        .toUpperCase();
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "Sign in to delete a masjid.");
    }
    if (!/^[A-Z0-9]{6}$/.test(masjidToken)) {
        throw new https_1.HttpsError("invalid-argument", "Invalid masjid token.");
    }
    const adminSnapshot = await db.collection("admins")
        .where("masjidToken", "==", masjidToken).get();
    const masjidRef = db.collection("masjids").doc(masjidToken);
    const masjidSnapshot = await masjidRef.get();
    const owner = adminSnapshot.docs.find((doc) => {
        const data = doc.data();
        return data.authUid === callerUid && data.isOwner === true &&
            data.status === "approved";
    });
    if (!owner || !masjidSnapshot.exists ||
        masjidSnapshot.data()?.ownerUid !== callerUid) {
        throw new https_1.HttpsError("permission-denied", "Only this masjid's creator can delete it.");
    }
    const auth = (0, auth_1.getAuth)();
    const userUids = new Set([callerUid]);
    for (const doc of adminSnapshot.docs) {
        const uid = String(doc.data().authUid ?? "").trim();
        if (uid)
            userUids.add(uid);
    }
    // Remove Auth accounts first. Missing/deleted users are safe to retry.
    for (const uid of userUids) {
        try {
            await auth.deleteUser(uid);
        }
        catch (error) {
            const code = error.code;
            if (code !== "auth/user-not-found") {
                throw new https_1.HttpsError("internal", `Could not delete a linked admin authentication account (${code ?? "unknown"}).`);
            }
        }
    }
    await db.recursiveDelete(masjidRef);
    const batch = db.batch();
    for (const doc of adminSnapshot.docs)
        batch.delete(doc.ref);
    if (adminSnapshot.size > 0)
        await batch.commit();
    return { deletedAuthAccounts: userUids.size, deletedMasjid: true };
});
//# sourceMappingURL=index.js.map