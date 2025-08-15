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

        // Create the push notification payload
        const payload = {
          notification: {
            title: notification.title,
            body: notification.message,
            sound: "default",
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
        sound: "default",
      },
      data: {
        type: "test",
        timestamp: Date.now().toString(),
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
