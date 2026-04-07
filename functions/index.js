const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");

admin.initializeApp();

/**
 * Sends an OTP SMS to a given phone number.
 * This is a HTTPS Callable function.
 */
exports.sendOTP = functions.https.onCall(async (data, context) => {
  const phoneNumber = data.phoneNumber; // Format: 0771234567 or 94771234567

  if (!phoneNumber) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a phoneNumber."
    );
  }

  // 1. Generate a 6-digit OTP
  const otpCode = Math.floor(100000 + Math.random() * 900000).toString();

  try {
    // 2. Save OTP to Firestore with expiration (5 minutes)
    await admin.firestore().collection("otps").doc(phoneNumber).set({
      code: otpCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: Date.now() + 5 * 60 * 1000, 
    });

    // 3. Send SMS via Gateway (Example using a generic axios call)
    // IMPORTANT: Replace with your actual SMS Gateway API details (e.g., Twilio, Dialog, Mobitel)
    /*
    await axios.get('https://sms-gateway.com/send', {
      params: {
        api_key: 'YOUR_API_KEY',
        to: phoneNumber,
        message: `Your GovEase OTP is: ${otpCode}. Valid for 5 minutes.`
      }
    });
    */

    // OTP logic finished
    // Do NOT print or leak the generated OTP in production environments

    return { 
        success: true, 
        message: "OTP sent successfully!"
    };

  } catch (error) {
    console.error("Error sending OTP:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to send OTP. Please try again later."
    );
  }
});

/**
 * Verifies the OTP provided by the user.
 */
exports.verifyOTP = functions.https.onCall(async (data, context) => {
  const { phoneNumber, code } = data;

  if (!phoneNumber || !code) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Required fields: phoneNumber and code."
    );
  }

  const otpDoc = await admin.firestore().collection("otps").doc(phoneNumber).get();

  if (!otpDoc.exists) {
    return { success: false, message: "No OTP found for this number." };
  }

  const otpData = otpDoc.data();

  // Check expiration
  if (Date.now() > otpData.expiresAt) {
    await otpDoc.ref.delete();
    return { success: false, message: "OTP has expired." };
  }

    // Check code
    if (otpData.code === code) {
      console.log(`OTP matched for ${phoneNumber}`);
      // OTP verified - delete it so it can't be reused
      await otpDoc.ref.delete();

      try {
        // 1. Get or create user in Firebase Auth
        let userRecord;
        try {
          userRecord = await admin.auth().getUserByPhoneNumber(phoneNumber);
          console.log(`Found existing user for ${phoneNumber}: ${userRecord.uid}`);
        } catch (error) {
          if (error.code === 'auth/user-not-found') {
            console.log(`User not found for ${phoneNumber}, creating new user...`);
            userRecord = await admin.auth().createUser({
              phoneNumber: phoneNumber,
            });
            console.log(`User created: ${userRecord.uid}`);
          } else {
            console.error("Error getting user by phone number:", error);
            throw error;
          }
        }

        // 2. Create Custom Token for this user
        console.log(`Creating custom token for user: ${userRecord.uid}`);
        
        try {
          const customToken = await admin.auth().createCustomToken(userRecord.uid);
          console.log(`Custom token created!`);
          return { 
            success: true, 
            message: "OTP verified!",
            token: customToken
          };
        } catch (tokenError) {
          console.error("TOKEN CREATION ERROR:", tokenError);
          if (tokenError.message.includes("signBlob")) {
            throw new functions.https.HttpsError(
              "internal", 
              "SERVER_PERMISSION_MISSING: Please grant 'Service Account Token Creator' role to the service account in Google Cloud IAM."
            );
          }
          throw tokenError;
        }
      } catch (error) {
        console.error("Final catch error:", error);
        throw new functions.https.HttpsError("internal", error.message);
      }
    } else {
      console.log(`Invalid code: ${code} (expected ${otpData.code}) for ${phoneNumber}`);
      return { success: false, message: "Invalid OTP code." };
    }
});

/**
 * PayHere server-to-server notification endpoint.
 * Expected URL path (function endpoint): /payhereNotify
 */
exports.payhereNotify = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  try {
    const body = _normalizeNotifyBody(req.body);
    const orderId = String(body.order_id || "").trim();
    const paymentId = String(body.payment_id || "").trim();
    const statusCode = String(body.status_code || "").trim();
    const statusMessage = String(body.status_message || "").trim();
    const md5sig = String(body.md5sig || "").trim().toUpperCase();
    const receivedAt = admin.firestore.FieldValue.serverTimestamp();

    const signatureCheck = _verifyPayHereSignature(body, md5sig);

    await admin
      .firestore()
      .collection("payhere_notifications")
      .add({
        orderId,
        paymentId,
        statusCode,
        statusMessage,
        md5sig,
        signatureVerified: signatureCheck.verified,
        signatureReason: signatureCheck.reason,
        payload: body,
        receivedAt,
      });

    if (orderId) {
      const updatePayload = {
        paymentStatus: statusCode === "2" ? "paid" : "failed",
        paymentProvider: "payhere",
        paymentId: paymentId || null,
        payhereStatusCode: statusCode,
        payhereStatusMessage: statusMessage,
        payhereSignatureVerified: signatureCheck.verified,
        updatedAt: receivedAt,
      };

      await admin.firestore().collection("applications").doc(orderId).set(updatePayload, { merge: true });
    }

    return res.status(200).send("OK");
  } catch (error) {
    console.error("payhereNotify error:", error);
    return res.status(500).send("ERROR");
  }
});

function _normalizeNotifyBody(rawBody) {
  if (!rawBody) return {};
  if (typeof rawBody === "object") return rawBody;
  if (typeof rawBody !== "string") return {};

  const params = new URLSearchParams(rawBody);
  const body = {};
  for (const [key, value] of params.entries()) {
    body[key] = value;
  }
  return body;
}

function _verifyPayHereSignature(body, incomingMd5Sig) {
  const merchantId = String(body.merchant_id || "").trim();
  const orderId = String(body.order_id || "").trim();
  const amount = String(body.payhere_amount || "").trim();
  const currency = String(body.payhere_currency || "").trim();
  const statusCode = String(body.status_code || "").trim();

  const merchantSecret = (process.env.PAYHERE_MERCHANT_SECRET || "").trim();
  if (!merchantSecret) {
    return { verified: false, reason: "missing_merchant_secret_env" };
  }

  if (!incomingMd5Sig || !merchantId || !orderId || !amount || !currency || !statusCode) {
    return { verified: false, reason: "missing_signature_fields" };
  }

  const localSecretHash = crypto.createHash("md5").update(merchantSecret).digest("hex").toUpperCase();
  const expectedSig = crypto
    .createHash("md5")
    .update(`${merchantId}${orderId}${amount}${currency}${statusCode}${localSecretHash}`)
    .digest("hex")
    .toUpperCase();

  return {
    verified: expectedSig === incomingMd5Sig,
    reason: expectedSig === incomingMd5Sig ? "ok" : "signature_mismatch",
  };
}

/**
 * Triggers when a new notification is added to the 'notifications' collection.
 * Sends an FCM push notification to the user's fcmTokens.
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = notification.userId;
    
    if (!userId) {
      console.error('No userId attached to the notification');
      return null;
    }
    
    // Get the user document to fetch FCM tokens
    let userDoc = await admin.firestore().collection('citizens').doc(userId).get();
    if (!userDoc.exists) {
      userDoc = await admin.firestore().collection('officers').doc(userId).get();
    }
    
    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      return null;
    }
    
    const user = userDoc.data();
    const tokens = user.fcmTokens;
    
    if (!tokens || tokens.length === 0) {
      console.log(`User ${userId} has no FCM tokens`);
      return null;
    }
    
    const payload = {
      notification: {
        title: notification.title || 'GovEase',
        body: notification.body || 'You have a new notification',
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        notificationId: snap.id,
        type: notification.type || 'general',
      }
    };
    
    try {
      const response = await admin.messaging().sendToDevice(tokens, payload);
      console.log(`Successfully sent push notification to ${userId}:`, response);
      
      // Clean up invalid tokens
      const tokensToRemove = [];
      response.results.forEach((result, index) => {
        const error = result.error;
        if (error) {
          console.error('Failure sending notification to', tokens[index], error);
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            tokensToRemove.push(tokens[index]);
          }
        }
      });
      
      if (tokensToRemove.length > 0) {
        await userDoc.ref.update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
        });
        console.log('Removed invalid tokens:', tokensToRemove);
      }
      
    } catch (error) {
      console.error('Error sending push notification:', error);
    }
    
    return null;
  });

async function _appendActionLog({
  entityType,
  entityId,
  beforeData,
  afterData,
}) {
  const oldStatus = String(beforeData?.status || "").trim();
  const newStatus = String(afterData?.status || "").trim();
  if (!newStatus || oldStatus === newStatus) {
    return;
  }

  const actorUid = String(
    afterData?.lastActionBy ||
      afterData?.assignedOfficerId ||
      afterData?.updatedBy ||
      ""
  ).trim();

  const reason = String(
    afterData?.lastActionReason ||
      afterData?.officerRemarks ||
      afterData?.officerNotes ||
      ""
  ).trim();

  await admin.firestore().collection("action_logs").add({
    entityType,
    entityId,
    actorUid: actorUid || null,
    oldStatus,
    newStatus,
    reason,
    source: String(afterData?.lastActionSource || "mobile-app").trim() || "mobile-app",
    sessionId: String(afterData?.lastActionSessionId || "unknown").trim() || "unknown",
    deviceId: String(afterData?.lastActionDeviceId || "unknown").trim() || "unknown",
    actionAt: afterData?.lastActionAt || afterData?.updatedAt || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Creates a notification when an application status changes.
 */
exports.onApplicationStatusChange = functions.firestore
  .document('applications/{appId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    if (newData.status !== oldData.status && newData.userId) {
      await admin.firestore().collection('notifications').add({
        userId: newData.userId,
        title: 'Application Status Update',
        body: `Your application for ${newData.serviceType} is now ${newData.status}`,
        type: 'application',
        relatedId: context.params.appId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await _appendActionLog({
        entityType: 'application',
        entityId: context.params.appId,
        beforeData: oldData,
        afterData: newData,
      });
    }
    return null;
  });

/**
 * Creates a notification when a complaint status changes.
 */
exports.onComplaintStatusChange = functions.firestore
  .document('complaints/{compId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    if (newData.status !== oldData.status && newData.userId) {
      await admin.firestore().collection('notifications').add({
        userId: newData.userId,
        title: 'Complaint Status Update',
        body: `Your complaint (${newData.category}) is now ${newData.status}`,
        type: 'complaint',
        relatedId: context.params.compId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await _appendActionLog({
        entityType: 'complaint',
        entityId: context.params.compId,
        beforeData: oldData,
        afterData: newData,
      });
    }
    return null;
  });

/**
 * Creates a notification when a GN appointment status changes.
 */
exports.onAppointmentStatusChange = functions.firestore
  .document('gn_appointments/{apptId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    if (newData.status !== oldData.status && newData.userId) {
      await admin.firestore().collection('notifications').add({
        userId: newData.userId,
        title: 'Appointment Update',
        body: `Your GN appointment is now ${newData.status}`,
        type: 'appointment',
        relatedId: context.params.apptId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await _appendActionLog({
        entityType: 'gn_appointment',
        entityId: context.params.apptId,
        beforeData: oldData,
        afterData: newData,
      });
    }
    return null;
  });

/**
 * Scheduled function to send appointment reminders (24h and 2h).
 * Runs every hour.
 */
exports.sendAppointmentReminders = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async (context) => {
    const now = new Date();
    const upcoming24hStart = new Date(now.getTime() + 23.5 * 60 * 60 * 1000);
    const upcoming24hEnd = new Date(now.getTime() + 24.5 * 60 * 60 * 1000);
    
    const upcoming2hStart = new Date(now.getTime() + 1.5 * 60 * 60 * 1000);
    const upcoming2hEnd = new Date(now.getTime() + 2.5 * 60 * 60 * 1000);

    const appointmentsRef = admin.firestore().collection('gn_appointments');
    
    // Check for 24h reminders
    const snapshot24h = await appointmentsRef
      .where('status', '==', 'Approved')
      .where('scheduledDate', '>=', upcoming24hStart.toISOString())
      .where('scheduledDate', '<=', upcoming24hEnd.toISOString())
      .get();
      
    snapshot24h.forEach(async (doc) => {
      const data = doc.data();
      if (!data.reminder24hSent) {
        await admin.firestore().collection('notifications').add({
          userId: data.userId,
          title: 'Appointment Reminder',
          body: `You have a GN appointment tomorrow at ${new Date(data.scheduledDate).toLocaleTimeString()}`,
          type: 'appointment_reminder',
          relatedId: doc.id,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        await doc.ref.update({ reminder24hSent: true });
      }
    });

    // Check for 2h reminders
    const snapshot2h = await appointmentsRef
      .where('status', '==', 'Approved')
      .where('scheduledDate', '>=', upcoming2hStart.toISOString())
      .where('scheduledDate', '<=', upcoming2hEnd.toISOString())
      .get();
      
    snapshot2h.forEach(async (doc) => {
      const data = doc.data();
      if (!data.reminder2hSent) {
        await admin.firestore().collection('notifications').add({
          userId: data.userId,
          title: 'Appointment Starting Soon',
          body: `Your GN appointment starts in 2 hours.`,
          type: 'appointment_reminder',
          relatedId: doc.id,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        await doc.ref.update({ reminder2hSent: true });
      }
    });
    
    return null;
  });

/**
 * Secure role update endpoint.
 * Only admins (by custom claim) can promote/demote users.
 */
exports.setUserRoleSecure = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const actorRole = context.auth.token.role;
  if (actorRole !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can update user roles."
    );
  }

  const targetUid = String(data?.targetUid || "").trim();
  const targetRole = String(data?.targetRole || "").trim().toLowerCase();
  const allowedRoles = new Set(["citizen", "officer", "admin"]);

  if (!targetUid || !allowedRoles.has(targetRole)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Required fields: targetUid and valid targetRole (citizen|officer|admin)."
    );
  }

  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const actorUid = context.auth.uid;

  const citizenRef = db.collection("citizens").doc(targetUid);
  const officerRef = db.collection("officers").doc(targetUid);

  const [citizenSnap, officerSnap] = await Promise.all([
    citizenRef.get(),
    officerRef.get(),
  ]);

  let primaryRef = null;
  let secondaryRef = null;

  if (targetRole === "citizen") {
    primaryRef = citizenRef;
    secondaryRef = officerRef;
  } else {
    primaryRef = officerRef;
    secondaryRef = citizenRef;
  }

  const baseProfile = citizenSnap.exists
    ? citizenSnap.data()
    : officerSnap.exists
      ? officerSnap.data()
      : {};

  const userRecord = await admin.auth().getUser(targetUid);
  const existingClaims = userRecord.customClaims || {};
  await admin.auth().setCustomUserClaims(targetUid, {
    ...existingClaims,
    role: targetRole,
  });

  await primaryRef.set({
    ...baseProfile,
    role: targetRole,
    updatedAt: now,
    roleUpdatedAt: now,
    roleUpdatedBy: actorUid,
  }, { merge: true });

  if (secondaryRef) {
    await secondaryRef.delete().catch(() => null);
  }

  return {
    success: true,
    targetUid,
    targetRole,
    updatedBy: actorUid,
  };
});

/**
 * Validates citizen NIC + phone pairing for login without exposing profile documents.
 */
exports.lookupCitizenIdentity = functions.https.onCall(async (data) => {
  const nic = String(data?.nic || "").trim().toUpperCase();
  const phone = String(data?.phone || "").trim();

  if (!nic || !phone) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Required fields: nic and phone."
    );
  }

  const db = admin.firestore();
  const nicQuery = await db
    .collection("citizens")
    .where("nicNormalized", "==", nic)
    .limit(1)
    .get();

  if (nicQuery.empty) {
    return { found: false, reason: "nic_not_found" };
  }

  const doc = nicQuery.docs[0];
  const model = doc.data();
  const savedPhone = String(model.phoneNormalized || model.phone || "")
    .replace(/\D/g, "")
    .slice(-10);
  const enteredPhone = phone.replace(/\D/g, "").slice(-10);

  if (!savedPhone || savedPhone !== enteredPhone) {
    return { found: false, reason: "phone_mismatch" };
  }

  return {
    found: true,
    uid: doc.id,
    nic: model.nic || "",
    phone: model.phone || "",
    preferredLanguage: model.preferredLanguage || "en",
  };
});

/**
 * Resolves officer by officer ID for OTP login bootstrap.
 */
exports.lookupOfficerIdentity = functions.https.onCall(async (data) => {
  const officerId = String(data?.officerId || "").trim().toUpperCase();
  if (!officerId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Required field: officerId."
    );
  }

  const db = admin.firestore();
  const query = await db
    .collection("officers")
    .where("officerIdNormalized", "==", officerId)
    .limit(1)
    .get();

  if (query.empty) {
    return { found: false };
  }

  const doc = query.docs[0];
  const model = doc.data();
  const role = String(model.role || "").toLowerCase();
  if (role !== "officer" && role !== "admin") {
    return { found: false };
  }

  return {
    found: true,
    uid: doc.id,
    name: model.name || "",
    nic: model.nic || "",
    phone: model.phone || "",
    role,
    division: model.division || "",
    province: model.province || "",
    district: model.district || "",
    pradeshiyaSabha: model.pradeshiyaSabha || "",
    gramasewaWasama: model.gramasewaWasama || "",
    preferredLanguage: model.preferredLanguage || "en",
    profileImageUrl: model.profileImageUrl || "",
  };
});

/**
 * Checks whether NIC/phone already exist for citizen signup.
 */
exports.checkCitizenRegistration = functions.https.onCall(async (data) => {
  const nic = String(data?.nic || "").trim().toUpperCase();
  const phone = String(data?.phone || "").trim();

  if (!nic || !phone) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Required fields: nic and phone."
    );
  }

  const normalizedPhone = phone.replace(/\D/g, "").slice(-10);
  const db = admin.firestore();

  const nicQuery = await db
    .collection("citizens")
    .where("nicNormalized", "==", nic)
    .limit(1)
    .get();

  const phoneQuery = await db
    .collection("citizens")
    .where("phoneNormalized", "==", `0${normalizedPhone.slice(-9)}`)
    .limit(1)
    .get();

  return {
    nicExists: !nicQuery.empty,
    phoneExists: !phoneQuery.empty,
  };
});

function _certificateSignatureSeed(app) {
  return [
    String(app.certificateReference || "").trim(),
    String(app.id || "").trim(),
    String(app.userId || "").trim(),
    String(app.serviceType || "").trim(),
    String(app.certificateIssuedAt || "").trim(),
  ].join("|");
}

function _certificateSignature(seed) {
  const secret = (process.env.CERT_SIGNATURE_SECRET || "dev-cert-signing-secret").trim();
  return crypto
    .createHmac("sha256", secret)
    .update(seed)
    .digest("hex");
}

/**
 * Verifies certificate reference using server-side signature logic.
 */
exports.verifyCertificateReference = functions.https.onCall(async (data) => {
  const reference = String(data?.reference || "").trim();
  if (!reference) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Required field: reference."
    );
  }

  const db = admin.firestore();
  const query = await db
    .collection("applications")
    .where("certificateReference", "==", reference)
    .limit(1)
    .get();

  if (query.empty) {
    return { verified: false, reason: "not_found" };
  }

  const doc = query.docs[0];
  const app = { id: doc.id, ...doc.data() };

  const completed = String(app.status || "").toLowerCase() === "completed";
  const generated = app.certificateGenerated === true;
  if (!completed || !generated) {
    return { verified: false, reason: "inactive_certificate" };
  }

  const seed = _certificateSignatureSeed(app);
  const expectedSignature = _certificateSignature(seed);
  const storedSignature = String(app.certificateServerSignature || "").trim();

  if (!storedSignature) {
    await doc.ref.set(
      {
        certificateServerSignature: expectedSignature,
        certificateSignatureVersion: 1,
        certificateSignatureUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  const verified = !storedSignature || storedSignature === expectedSignature;
  return {
    verified,
    reason: verified ? "ok" : "signature_mismatch",
    applicationId: doc.id,
    serviceType: app.serviceType || "",
    reference,
    certificateIssuedAt: app.certificateIssuedAt || null,
    signatureVersion: 1,
  };
});

/**
 * Ensures server-side certificate signature is stamped once certificate is issued.
 */
exports.onCertificateIssuedSign = functions.firestore
  .document('applications/{appId}')
  .onWrite(async (change) => {
    if (!change.after.exists) return null;

    const after = change.after.data() || {};
    const before = change.before.exists ? (change.before.data() || {}) : {};

    const becameIssued =
      after.certificateGenerated === true &&
      String(after.certificateReference || "").trim() !== "";

    if (!becameIssued) {
      return null;
    }

    const alreadySigned = String(after.certificateServerSignature || "").trim();
    if (alreadySigned) {
      return null;
    }

    const previousSignature = String(before.certificateServerSignature || "").trim();
    if (previousSignature) {
      return null;
    }

    const app = {
      id: change.after.id,
      ...after,
    };
    const seed = _certificateSignatureSeed(app);
    const signature = _certificateSignature(seed);

    await change.after.ref.set(
      {
        certificateServerSignature: signature,
        certificateSignatureVersion: 1,
        certificateSignatureUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return null;
  });

exports.onOfficerWrite = functions.firestore
  .document("officers/{uid}")
  .onWrite(async (change, context) => {
    const data = change.after.exists ? change.after.data() : null;
    const uid = context.params.uid;
    if (data && (data.role === "officer" || data.role === "admin")) {
       try {
         const userRecord = await admin.auth().getUser(uid);
         const existingClaims = userRecord.customClaims || {};
         if (existingClaims.role !== data.role) {
           await admin.auth().setCustomUserClaims(uid, { ...existingClaims, role: data.role });
           console.log(`Set custom claim role=${data.role} for user ${uid}`);
         }
       } catch(e) {
           console.error("Failed to set claim", e);
       }
    }
  });

async function notifyDSAdmins(dsName, title, body, type, relatedId) {
  if (!dsName) return;
  try {
    const snap = await admin.firestore().collection('ds_admins')
      .where('dsDivision', '==', dsName)
      .get();
      
    if (snap.empty) return;
    
    const batch = admin.firestore().batch();
    snap.docs.forEach(doc => {
      const notifRef = admin.firestore().collection('notifications').doc();
      batch.set(notifRef, {
        userId: doc.id,
        title,
        body,
        type,
        relatedId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    await batch.commit();
  } catch (e) {
    console.error("Error notifying DS Admins", e);
  }
}

/**
 * Creates a notification for DS Admin when a new Application is submitted.
 */
exports.onApplicationCreate = functions.firestore
  .document('applications/{appId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const division = data.pradeshiyaSabha || data.division || data.dsDivision;
    if (division) {
      await notifyDSAdmins(
        division,
        'New Application Submitted',
        `A new application for ${data.serviceType} has been submitted.`,
        'application_request',
        context.params.appId
      );
    }
    return null;
  });

/**
 * Creates a notification for DS Admin when a new Complaint is submitted.
 */
exports.onComplaintCreate = functions.firestore
  .document('complaints/{compId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const division = data.pradeshiyaSabha || data.division || data.dsDivision;
    if (division) {
      await notifyDSAdmins(
        division,
        'New Complaint Logged',
        `A new complaint (${data.category}) has been logged in your division.`,
        'complaint_logged',
        context.params.compId
      );
    }
    return null;
  });

/**
 * Creates a notification for GN Officer when a new appointment is requested.
 */
exports.onAppointmentCreate = functions.firestore
  .document('gn_appointments/{apptId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    if (data.assignedOfficerId) {
      await admin.firestore().collection('notifications').add({
        userId: data.assignedOfficerId,
        title: 'New Appointment Request',
        body: `You have a new appointment request on ${new Date(data.scheduledDate).toLocaleDateString()}`,
        type: 'appointment_request',
        relatedId: context.params.apptId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    return null;
  });
