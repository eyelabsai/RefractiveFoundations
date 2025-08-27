const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Cloud Function to send push notifications
exports.sendNotification = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snap, context) => {
      try {
        const notification = snap.data();

        // Get the recipient's FCM token
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(notification.recipientId)
            .get();

        if (!userDoc.exists) {
          console.log("User document not found:", notification.recipientId);
          return;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (!fcmToken) {
          console.log("No FCM token for user:", notification.recipientId);
          return;
        }

        // Create the push notification payload (FCM v1 API format)
        const payload = {
          notification: {
            title: notification.title,
            body: notification.message,
          },
          data: {
            notificationId: context.params.notificationId,
            type: notification.type,
            ...(notification.metadata && notification.metadata.postId &&
                {postId: notification.metadata.postId}),
            ...(notification.metadata && notification.metadata.conversationId &&
                {conversationId: notification.metadata.conversationId}),
            ...(notification.metadata && notification.metadata.commentId &&
                {commentId: notification.metadata.commentId}),
          },
          apns: {
            payload: {
              aps: {
                "alert": {
                  "title": notification.title,
                  "body": notification.message,
                },
                "sound": "default",
                "badge": 1,
                "content-available": 1,
              },
            },
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
          },
          token: fcmToken,
        };

        // Send the notification
        const response = await admin.messaging().send(payload);
        console.log("Successfully sent notification:", response);

        return response;
      } catch (error) {
        console.error("Error sending notification:", error);
        throw error;
      }
    });

// Manual test function (callable via HTTP trigger)
exports.testNotification = functions.https.onCall(async (data, context) => {
  try {
    const {userId, title, body} = data;

    if (!userId || !title || !body) {
      throw new functions.https.HttpsError("invalid-argument",
          "Missing required parameters: userId, title, body");
    }

    // Get user's FCM token
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "User not found");
    }

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      throw new functions.https.HttpsError("failed-precondition",
          "User has no FCM token");
    }

    const payload = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "test",
        timestamp: Date.now().toString(),
      },
      apns: {
        payload: {
          aps: {
            "alert": {
              "title": title,
              "body": body,
            },
            "sound": "default",
            "badge": 1,
            "content-available": 1,
          },
        },
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
      },
      token: fcmToken,
    };

    const response = await admin.messaging().send(payload);
    return {success: true, messageId: response};
  } catch (error) {
    console.error("Error in testNotification:", error);
    throw error;
  }
});

// Admin-only user creation function
exports.createUser = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated and has admin privileges
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated",
          "User must be authenticated");
    }

    // Check if user is admin
    // (you can implement custom claims or check admin collection)
    const adminDoc = await admin.firestore()
        .collection("admins")
        .doc(context.auth.uid)
        .get();

    if (!adminDoc.exists) {
      throw new functions.https.HttpsError("permission-denied",
          "User does not have admin privileges");
    }

    const {email, firstName, lastName, practiceName, tempPassword} = data;

    // Validate required fields
    if (!email || !firstName || !lastName || !tempPassword) {
      throw new functions.https.HttpsError("invalid-argument",
          "Missing required: email, firstName, lastName, tempPassword");
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new functions.https.HttpsError("invalid-argument",
          "Invalid email format");
    }

    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: tempPassword,
      displayName: `${firstName} ${lastName}`,
    });

    console.log("Created Firebase Auth user:", userRecord.uid);

    // Create user document in Firestore
    const userData = {
      credential: "",
      email: email,
      firstName: firstName,
      lastName: lastName,
      position: "",
      specialty: "General Ophthalmology",
      state: "",
      suffix: "",
      uid: userRecord.uid,
      avatarUrl: null,
      exchangeUsername: "",
      favoriteLenses: [],
      savedPosts: [],
      dateJoined: admin.firestore.FieldValue.serverTimestamp(),
      practiceLocation: "",
      practiceName: practiceName || "",
      hasCompletedOnboarding: false,
      notificationPreferences: {
        comments: true,
        directMessages: true,
        posts: true,
        mentions: true,
      },
    };

    await admin.firestore()
        .collection("users")
        .doc(userRecord.uid)
        .set(userData);

    console.log("Created Firestore document for user:", userRecord.uid);

    return {
      success: true,
      uid: userRecord.uid,
      email: email,
      name: `${firstName} ${lastName}`,
      message: "User created successfully",
    };
  } catch (error) {
    console.error("Error in createUser:", error);

    // Handle specific Firebase Auth errors
    if (error.code === "auth/email-already-exists") {
      throw new functions.https.HttpsError("already-exists",
          "User with this email already exists");
    }

    // Re-throw HttpsError as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Wrap other errors
    throw new functions.https.HttpsError("internal",
        `Failed to create user: ${error.message}`);
  }
});

// Bulk user creation function
exports.createBulkUsers = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication and admin privileges
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

    const {users} = data;

    if (!users || !Array.isArray(users) || users.length === 0) {
      throw new functions.https.HttpsError("invalid-argument",
          "Users array is required and must not be empty");
    }

    if (users.length > 50) {
      throw new functions.https.HttpsError("invalid-argument",
          "Maximum 50 users can be created in one batch");
    }

    const results = [];
    const batch = admin.firestore().batch();

    for (const userData of users) {
      try {
        const {email, firstName, lastName, practiceName} = userData;

        // Generate temporary password
        const tempPassword = generateTempPassword();

        // Create user in Firebase Auth
        const userRecord = await admin.auth().createUser({
          email: email,
          password: tempPassword,
          displayName: `${firstName} ${lastName}`,
        });

        // Prepare Firestore document
        const firestoreData = {
          credential: "",
          email: email,
          firstName: firstName,
          lastName: lastName,
          position: "",
          specialty: "General Ophthalmology",
          state: "",
          suffix: "",
          uid: userRecord.uid,
          avatarUrl: null,
          exchangeUsername: "",
          favoriteLenses: [],
          savedPosts: [],
          dateJoined: admin.firestore.FieldValue.serverTimestamp(),
          practiceLocation: "",
          practiceName: practiceName || "",
          hasCompletedOnboarding: false,
          notificationPreferences: {
            comments: true,
            directMessages: true,
            posts: true,
            mentions: true,
          },
        };

        // Add to batch
        const userRef = admin.firestore()
            .collection("users").doc(userRecord.uid);
        batch.set(userRef, firestoreData);

        results.push({
          success: true,
          email: email,
          uid: userRecord.uid,
          tempPassword: tempPassword,
          name: `${firstName} ${lastName}`,
        });
      } catch (error) {
        console.error(`Failed to create user ${userData.email}:`, error);
        results.push({
          success: false,
          email: userData.email,
          error: error.message,
          name: `${userData.firstName} ${userData.lastName}`,
        });
      }
    }

    // Commit batch write for Firestore documents
    await batch.commit();

    const successful = results.filter((r) => r.success);
    const failed = results.filter((r) => !r.success);

    return {
      success: true,
      totalProcessed: results.length,
      successful: successful.length,
      failed: failed.length,
      results: results,
    };
  } catch (error) {
    console.error("Error in createBulkUsers:", error);
    throw new functions.https.HttpsError("internal",
        `Bulk user creation failed: ${error.message}`);
  }
});

/**
 * Helper function to generate temporary password
 * @param {number} length - Length of password (unused, returns fixed password)
 * @return {string} Fixed temporary password
 */
function generateTempPassword(length = 12) {
  // Use fixed password for easier distribution
  return "RefractiveFoundations";
}

// Cloud Function to send push-only notifications (for DMs and Group Messages)
exports.sendPushOnlyNotification = functions.firestore
    .document("pushOnlyNotifications/{notificationId}")
    .onCreate(async (snap, context) => {
      try {
        const notification = snap.data();

        // Get the recipient's FCM token
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(notification.recipientId)
            .get();

        if (!userDoc.exists) {
          console.log("User document not found:", notification.recipientId);
          return;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (!fcmToken) {
          console.log("No FCM token for user:", notification.recipientId);
          return;
        }

        // Create the push notification payload (FCM v1 API format)
        const payload = {
          notification: {
            title: notification.title,
            body: notification.message,
          },
          data: {
            notificationId: context.params.notificationId,
            type: notification.type,
            ...(notification.metadata && notification.metadata.conversationId &&
                {conversationId: notification.metadata.conversationId}),
            ...(notification.metadata && notification.metadata.groupChatId &&
                {groupChatId: notification.metadata.groupChatId}),
          },
          apns: {
            payload: {
              aps: {
                badge: 1,
                sound: "default",
              },
            },
          },
          android: {
            notification: {
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          token: fcmToken,
        };

        // Send the notification
        const response = await admin.messaging().send(payload);
        console.log("Push-only notification sent successfully:", response);

        // Delete the temporary notification document after processing
        await snap.ref.delete();
        console.log("Temporary push-only notification document deleted");
      } catch (error) {
        console.error("Error sending push-only notification:", error);
      }
    });

// Import and export the fix function
const {fixUserProfiles} = require("./fixUserProfiles");
exports.fixUserProfiles = fixUserProfiles;
