const functions = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * Cloud Function to fix user profiles that show "User" instead of real names
 * This fixes the issue caused by Firestore rules blocking user creation
 * @param {object} data - Function data
 * @param {object} context - Function context
 * @return {object} Results of the fix operation
 */
exports.fixUserProfiles = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated and has admin privileges
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated",
          "User must be authenticated");
    }

    const adminDoc = await admin.firestore()
        .collection("admins")
        .doc(context.auth.uid)
        .get();

    if (!adminDoc.exists) {
      throw new functions.https.HttpsError("permission-denied",
          "User does not have admin privileges");
    }

    console.log("🔧 Starting user profile fix process...");

    // Get all users from Firestore with firstName "User"
    const usersSnapshot = await admin.firestore()
        .collection("users")
        .where("firstName", "==", "User")
        .get();

    if (usersSnapshot.empty) {
      console.log("✅ No users found with firstName User");
      return {
        success: true,
        message: "No users need fixing",
        usersFixed: 0,
      };
    }

    console.log(`🔍 Found ${usersSnapshot.size} users with firstName User`);

    const batch = admin.firestore().batch();
    const results = [];
    let fixedCount = 0;

    for (const doc of usersSnapshot.docs) {
      try {
        const userData = doc.data();
        const uid = userData.uid;

        // Get user from Firebase Auth to get their display name
        const authUser = await admin.auth().getUser(uid);

        // Extract name from display name if available
        let firstName = "User";
        let lastName = "";

        if (authUser.displayName) {
          const nameParts = authUser.displayName.trim().split(" ");
          firstName = nameParts[0] || "User";
          lastName = nameParts.slice(1).join(" ") || "";
        } else if (authUser.email) {
          // Use email prefix as fallback
          const emailPrefix = authUser.email.split("@")[0];
          firstName = emailPrefix.charAt(0).toUpperCase() +
              emailPrefix.slice(1);
        }

        // Update the user document
        const userRef = admin.firestore().collection("users").doc(uid);
        batch.update(userRef, {
          firstName: firstName,
          lastName: lastName,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });

        results.push({
          uid: uid,
          email: authUser.email,
          oldName: "User",
          newName: `${firstName} ${lastName}`.trim(),
          success: true,
        });

        fixedCount++;
        console.log(`✅ Prepared fix for user: ${authUser.email} -> ` +
            `${firstName} ${lastName}`);
      } catch (error) {
        console.error(`❌ Error processing user ${doc.id}:`, error);
        results.push({
          uid: doc.id,
          error: error.message,
          success: false,
        });
      }
    }

    // Commit all changes at once
    await batch.commit();

    console.log(`✅ Successfully fixed ${fixedCount} user profiles`);

    return {
      success: true,
      message: `Fixed ${fixedCount} user profiles`,
      usersFixed: fixedCount,
      totalProcessed: usersSnapshot.size,
      results: results,
    };
  } catch (error) {
    console.error("❌ Error in fixUserProfiles:", error);
    throw new functions.https.HttpsError("internal",
        `Failed to fix user profiles: ${error.message}`);
  }
});
