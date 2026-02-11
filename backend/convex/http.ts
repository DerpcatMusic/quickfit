import { httpRouter } from "convex/server";
import { bitpayWebhook, rapydWebhook } from "./webhooks";

const http = httpRouter();

http.route({
  path: "/webhooks/rapyd",
  method: "POST",
  handler: rapydWebhook,
});

http.route({
  path: "/webhooks/bitpay",
  method: "POST",
  handler: bitpayWebhook,
});

export default http;
