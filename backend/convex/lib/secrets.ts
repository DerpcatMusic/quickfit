const bytesToBase64 = (bytes: Uint8Array): string => {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary);
};

const base64ToBytes = (value: string): Uint8Array => {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
};

const bytesToArrayBuffer = (value: Uint8Array): ArrayBuffer => {
  const buffer = new ArrayBuffer(value.byteLength);
  new Uint8Array(buffer).set(value);
  return buffer;
};

const deriveAesKey = async (
  secret: string,
  keyUsages: KeyUsage[],
): Promise<CryptoKey> => {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(secret),
  );
  return await crypto.subtle.importKey(
    "raw",
    digest,
    { name: "AES-GCM" },
    false,
    keyUsages,
  );
};

export const getBillingSecretsKey = (): string => {
  const value = process.env.BILLING_SECRETS_KEY?.trim();
  if (!value) {
    throw new Error(
      "BILLING_SECRETS_KEY is required for encrypted billing/payment integrations",
    );
  }
  return value;
};

export const sealSecret = async (plain: string): Promise<string> => {
  const key = await deriveAesKey(getBillingSecretsKey(), ["encrypt"]);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipherBuffer = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(plain),
  );
  const ivB64 = bytesToBase64(iv);
  const cipherB64 = bytesToBase64(new Uint8Array(cipherBuffer));
  return `${ivB64}:${cipherB64}`;
};

export const openSealedSecret = async (sealed: string): Promise<string> => {
  const [ivB64, cipherB64] = sealed.split(":");
  if (!ivB64 || !cipherB64) {
    throw new Error("Invalid sealed secret format");
  }
  const key = await deriveAesKey(getBillingSecretsKey(), ["decrypt"]);
  const plainBuffer = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: bytesToArrayBuffer(base64ToBytes(ivB64)) },
    key,
    bytesToArrayBuffer(base64ToBytes(cipherB64)),
  );
  return new TextDecoder().decode(plainBuffer);
};
