// convex/actions/sendPush.ts
// Firebase Cloud Messaging push notifications

"use node";

import { internalAction } from "../_generated/server";
import { v } from "convex/values";

const FCM_ENDPOINT = "https://fcm.googleapis.com/fcm/send";

export const send = internalAction({
  args: {
    fcmToken: v.string(),
    title: v.string(),
    body: v.string(),
    data: v.optional(v.any()),
  },
  handler: async (_, { fcmToken, title, body, data }) => {
    const serverKey = process.env.FCM_SERVER_KEY;
    
    if (!serverKey) {
      console.warn("FCM_SERVER_KEY not set, skipping push notification");
      return { success: false, error: "FCM_SERVER_KEY not configured" };
    }
    
    try {
      const response = await fetch(FCM_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${serverKey}`,
        },
        body: JSON.stringify({
          to: fcmToken,
          notification: {
            title,
            body,
            sound: "default",
            badge: 1,
          },
          data: data || {},
          priority: "high",
        }),
      });
      
      if (!response.ok) {
        const error = await response.text();
        console.error("FCM error:", error);
        return { success: false, error };
      }
      
      const result = await response.json();
      return { success: true, result };
    } catch (error) {
      console.error("FCM send error:", error);
      return { success: false, error: String(error) };
    }
  },
});
