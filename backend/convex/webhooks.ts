import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { openSealedSecret } from "./lib/secrets";
import type { Id } from "./_generated/dataModel";

const getHeader = (req: Request, key: string): string | null =>
  req.headers.get(key) ?? req.headers.get(key.toLowerCase()) ?? null;

const buildRapydSignature = async ({
  method,
  path,
  salt,
  timestamp,
  accessKey,
  secretKey,
  body,
}: {
  method: string;
  path: string;
  salt: string;
  timestamp: string;
  accessKey: string;
  secretKey: string;
  body: string;
}): Promise<string> => {
  const toSign = `${method.toLowerCase()}${path}${salt}${timestamp}${accessKey}${secretKey}${body}`;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secretKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(toSign),
  );
  const bytes = new Uint8Array(signature);
  const hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  // Rapyd signature convention: base64 of SHA256 hex string bytes.
  return btoa(hex);
};

const safeEqual = (a: string, b: string): boolean => {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i += 1) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
};

const sha256Hex = async (input: string): Promise<string> => {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
};

const hmacSha256Hex = async (
  secret: string,
  payload: string,
): Promise<string> => {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(payload),
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
};

type PaymentForLookup = {
  _id: Id<"payments">;
  studioId: Id<"users">;
};

type StudioPaymentIntegration = {
  provider: "rapyd" | "bitpay";
  apiToken?: string;
  apiKey?: string;
  webhookSecret?: string;
  sealedApiToken?: string;
  sealedApiKey?: string;
  sealedWebhookSecret?: string;
};

export const rapydWebhook = httpAction(async (ctx, req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const accessKeyHeader = getHeader(req, "access_key") ?? "";
  const salt = getHeader(req, "salt") ?? "";
  const timestamp = getHeader(req, "timestamp") ?? "";
  const signature = getHeader(req, "signature") ?? "";
  const bodyText = await req.text();

  const payloadHash = await sha256Hex(bodyText);
  const timestampSeconds = Number.parseInt(timestamp, 10);
  const nowSeconds = Math.floor(Date.now() / 1000);
  const timestampValid =
    Number.isFinite(timestampSeconds) &&
    Math.abs(nowSeconds - timestampSeconds) <= 60;

  let parsedPayload: unknown = null;
  try {
    parsedPayload = bodyText ? JSON.parse(bodyText) : {};
  } catch {
    parsedPayload = { raw: bodyText };
  }

  const payload = parsedPayload as {
    id?: string;
    type?: string;
    data?: {
      id?: string;
      status?: string;
      payment?: { id?: string; status?: string };
      checkout?: { id?: string };
    };
  };

  const providerEventId = payload.id?.toString().trim();
  if (!providerEventId) {
    return new Response(JSON.stringify({ received: false, error: "missing_event_id" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const providerPaymentId =
    payload.data?.payment?.id?.toString().trim() ||
    payload.data?.id?.toString().trim() ||
    undefined;
  const providerCheckoutId =
    payload.data?.checkout?.id?.toString().trim() || undefined;
  const statusRaw =
    payload.data?.payment?.status?.toString().trim() ||
    payload.data?.status?.toString().trim() ||
    undefined;

  const payment = (await ctx.runQuery(
    internal.payments.getPaymentByProviderRefs,
    {
      provider: "rapyd",
      providerPaymentId,
      providerCheckoutId,
    },
  )) as PaymentForLookup | null;

  const studioIntegration = payment
    ? ((await ctx.runQuery(
        internal.billing.getStudioPaymentIntegrationByProvider,
        { studioId: payment.studioId, provider: "rapyd" },
      )) as StudioPaymentIntegration | null)
    : null;

  const expectedAccessKey =
    studioIntegration?.sealedApiToken != null
      ? await openSealedSecret(studioIntegration.sealedApiToken)
      : studioIntegration?.apiToken?.trim() ||
        (process.env.RAPYD_ACCESS_KEY ?? "").trim();
  const webhookSecret =
    studioIntegration?.sealedWebhookSecret != null
      ? await openSealedSecret(studioIntegration.sealedWebhookSecret)
      : studioIntegration?.webhookSecret?.trim() ||
        (studioIntegration?.sealedApiKey != null
          ? await openSealedSecret(studioIntegration.sealedApiKey)
          : studioIntegration?.apiKey?.trim()) ||
        (
          process.env.RAPYD_WEBHOOK_SECRET ??
          process.env.RAPYD_SECRET_KEY ??
          ""
        ).trim();

  let signatureValid = false;
  if (
    webhookSecret &&
    expectedAccessKey &&
    accessKeyHeader &&
    salt &&
    timestamp &&
    signature &&
    timestampValid
  ) {
    const expected = await buildRapydSignature({
      method: "POST",
      path: new URL(req.url).pathname,
      salt,
      timestamp,
      accessKey: expectedAccessKey,
      secretKey: webhookSecret,
      body: bodyText,
    });
    signatureValid =
      accessKeyHeader === expectedAccessKey && safeEqual(expected, signature);
  }

  await ctx.runMutation(internal.payments.processRapydWebhookEvent, {
    providerEventId,
    eventType: payload.type?.toString(),
    providerPaymentId,
    providerCheckoutId,
    statusRaw,
    signatureValid,
    payloadHash,
    payload: parsedPayload,
  });

  return new Response(
    JSON.stringify({ received: true, signatureValid, timestampValid }),
    {
      status: signatureValid ? 200 : 401,
      headers: { "Content-Type": "application/json" },
    },
  );
});

export const bitpayWebhook = httpAction(async (ctx, req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const bodyText = await req.text();
  const payloadHash = await sha256Hex(bodyText);
  const signatureHeader =
    getHeader(req, "x-signature") ??
    getHeader(req, "X-Signature") ??
    getHeader(req, "signature") ??
    "";

  let parsedPayload: unknown = null;
  try {
    parsedPayload = bodyText ? JSON.parse(bodyText) : {};
  } catch {
    parsedPayload = { raw: bodyText };
  }

  const payload = parsedPayload as {
    event?: { name?: string; code?: string };
    id?: string;
    data?: {
      id?: string;
      status?: string;
      posData?: string;
    };
  };

  let paymentId: Id<"payments"> | undefined;
  let providerCheckoutId = payload.data?.id?.toString().trim() || undefined;
  let providerPaymentId = payload.data?.id?.toString().trim() || undefined;
  if (payload.data?.posData) {
    try {
      const parsedPosData = JSON.parse(payload.data.posData) as {
        paymentId?: string;
        checkoutId?: string;
      };
      if (parsedPosData.paymentId) {
        paymentId = parsedPosData.paymentId as Id<"payments">;
      }
      providerCheckoutId = parsedPosData.checkoutId || providerCheckoutId;
    } catch {
      // keep graceful fallback
    }
  }

  const payment = (await ctx.runQuery(
    internal.payments.getPaymentByProviderRefs,
    {
      provider: "bitpay",
      paymentId,
      providerPaymentId,
      providerCheckoutId,
    },
  )) as PaymentForLookup | null;

  const studioIntegration = payment
    ? ((await ctx.runQuery(
        internal.billing.getStudioPaymentIntegrationByProvider,
        { studioId: payment.studioId, provider: "bitpay" },
      )) as StudioPaymentIntegration | null)
    : null;

  const webhookSecret =
    studioIntegration?.sealedWebhookSecret != null
      ? await openSealedSecret(studioIntegration.sealedWebhookSecret)
      : studioIntegration?.webhookSecret?.trim() ||
        (process.env.BITPAY_WEBHOOK_SECRET ?? "").trim();

  let signatureValid = false;
  if (webhookSecret && signatureHeader) {
    const expected = await hmacSha256Hex(webhookSecret, bodyText);
    signatureValid = safeEqual(
      expected.toLowerCase(),
      signatureHeader.trim().toLowerCase(),
    );
  }

  const providerEventId =
    payload.id?.toString().trim() ?? payload.event?.code?.toString().trim();
  if (!providerEventId) {
    return new Response(JSON.stringify({ received: false, error: "missing_event_id" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const statusRaw = payload.data?.status?.toString().trim();

  await ctx.runMutation(internal.payments.processBitpayWebhookEvent, {
    providerEventId,
    eventType:
      payload.event?.name?.toString() ?? payload.event?.code?.toString(),
    providerPaymentId,
    providerCheckoutId,
    statusRaw,
    signatureValid,
    payloadHash,
    payload: parsedPayload,
  });

  return new Response(JSON.stringify({ received: true, signatureValid }), {
    status: signatureValid ? 200 : 401,
    headers: { "Content-Type": "application/json" },
  });
});
