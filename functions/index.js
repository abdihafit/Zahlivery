const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const notificationChannelId = "zahlivery_high_importance_channel";

async function getUserTokens(userId) {
  if (!userId) return [];

  const snapshot = await db.collection("users").doc(userId).get();
  if (!snapshot.exists) return [];

  const data = snapshot.data() || {};
  const tokens = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
  return tokens.filter((token) => typeof token === "string" && token.length > 0);
}

async function sendPushToUser(userId, {title, body, data = {}}) {
  const tokens = await getUserTokens(userId);
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)])
    ),
    android: {
      priority: "high",
      notification: {
        channelId: notificationChannelId,
      },
    },
  });

  const invalidTokens = [];
  response.responses.forEach((result, index) => {
    if (!result.success) {
      const code = result.error && result.error.code;
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        invalidTokens.push(tokens[index]);
      }
    }
  });

  if (invalidTokens.length > 0) {
    await db.collection("users").doc(userId).set({
      fcmTokens: tokens.filter((token) => !invalidTokens.includes(token)),
    }, {merge: true});
  }
}

async function createNotification({
  recipientId,
  senderId,
  type,
  title,
  body,
  chatId,
  orderId,
}) {
  if (!recipientId || recipientId === senderId) return;

  await db.collection("users")
      .doc(recipientId)
      .collection("notifications")
      .add({
        recipientId,
        senderId,
        type,
        title,
        body,
        chatId: chatId || null,
        orderId: orderId || null,
        isRead: false,
        createdAt: new Date(),
      });
}

exports.notifyOnOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data && event.data.data();
  if (!order) return;

  await createNotification({
    recipientId: order.hotelId,
    senderId: order.customerId || "",
    type: "order",
    title: "New order received",
    body: `${order.customerName || "A customer"} placed an order.`,
    orderId: event.params.orderId,
  });
});

exports.notifyOnMessageCreated = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const message = event.data && event.data.data();
      if (!message) return;
      if (message.messageType === "order_summary") return;

      const chatSnapshot = await db.collection("chats").doc(event.params.chatId).get();
      const chat = chatSnapshot.data() || {};
      const participants = Array.isArray(chat.participants) ? chat.participants : [];
      const recipientId = participants.find((id) => id && id !== message.senderId);
      if (!recipientId) return;

      await createNotification({
        recipientId,
        senderId: message.senderId || "",
        type: "chat",
        title: "New chat message",
        body: `${message.senderName || "Someone"}: ${message.text || "You have a new message."}`,
        chatId: event.params.chatId,
        orderId: message.orderId || "",
      });
    }
);

exports.notifyOnOrderUpdated = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const orderId = event.params.orderId;

  const tasks = [];

  if (before.status !== after.status) {
    if (after.customerId) {
      tasks.push(createNotification({
        recipientId: after.customerId,
        senderId: after.hotelId || after.riderId || "",
        type: after.status === "sent_to_rider" || after.status === "delivered" ?
          "delivery" : "order",
        title: "Order update",
        body: buildCustomerStatusMessage(after.status, after.hotelName),
        orderId,
      }));
    }

    if (after.status === "delivered" && after.hotelId) {
      tasks.push(createNotification({
        recipientId: after.hotelId,
        senderId: after.riderId || "",
        type: "delivery",
        title: "Delivery completed",
        body: "A rider marked this order as delivered.",
        orderId,
      }));
    }
  }

  if (!before.riderId && after.riderId) {
    tasks.push(createNotification({
      recipientId: after.riderId,
      senderId: after.hotelId || "",
      type: "delivery",
      title: "New delivery assigned",
      body: `${after.hotelName || "A hotel"} assigned you a delivery.`,
      orderId,
    }));
  }

  await Promise.all(tasks);
});

exports.notifyOnNotificationCreated = onDocumentCreated(
    "users/{userId}/notifications/{notificationId}",
    async (event) => {
      const notification = event.data && event.data.data();
      if (!notification) return;

      await sendPushToUser(event.params.userId, {
        title: notification.title || "Zahlivery",
        body: notification.body || "",
        data: {
          type: notification.type || "",
          chatId: notification.chatId || "",
          orderId: notification.orderId || "",
          senderId: notification.senderId || "",
        },
      });
    }
);

function buildCustomerStatusMessage(status, hotelName) {
  const source = hotelName || "The hotel";
  switch (status) {
    case "accepted":
      return `${source} accepted your order.`;
    case "payment_verified":
      return `${source} confirmed your payment.`;
    case "sent_to_rider":
      return `${source} sent your order to the rider.`;
    case "delivered":
      return `Your order from ${source} was delivered.`;
    case "cancelled":
      return `${source} cancelled your order.`;
    default:
      return `${source} updated your order.`;
  }
}
