const { onCall } = require("firebase-functions/v2/https");
const functions = require("firebase-functions");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

exports.processCaption = onCall(async (request) => {
  try {
    const { text, roomId } = request.data;

    if (!text || !roomId) {
      throw new Error("text and roomId are required");
    }

    const deepgramApiKey = process.env.DEEPGRAM_API_KEY;

    if (!deepgramApiKey) {
      throw new Error("DEEPGRAM_API_KEY missing in environment");
    }

    await admin
      .firestore()
      .collection("rooms")
      .doc(roomId)
      .collection("liveCaption")
      .doc("current")
      .set(
        {
          text: text,
          processedBy: "firebase-function",
          deepgramAttached: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    logger.info("Caption processed", { roomId, text });

    return {
      success: true,
      message: "Caption saved successfully",
    };
  } catch (error) {
    logger.error("processCaption failed", error);
    throw new Error(error.message || "Unknown error");
  }
});
exports.sendCallNotification = functions.firestore
  .document('calls/{calleeUid}')
  .onWrite(async (change, context) => {
    const data = change.after.data();
    if (!data || data.status !== 'ringing') return;

    const calleeUid = context.params.calleeUid;

    const userDoc = await admin.firestore()
      .collection('users')
      .doc(calleeUid)
      .get();

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      android: {
        priority: 'high',
        notification: {
          channelId: 'call_channel',
          priority: 'max',
          defaultVibrateTimings: true,
        },
      },
      data: {
        type: 'incoming_call',
        fromUid: data.fromUid ?? '',
        fromNumber: data.fromNumber ?? '',
        roomId: data.roomId ?? '',
        callerName: data.fromNumber ?? 'Unknown',
      },
    });
  });