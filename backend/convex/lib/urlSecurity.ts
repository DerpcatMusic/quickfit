const PRIVATE_HOST_PATTERNS = [
  /^localhost$/i,
  /^127\./,
  /^10\./,
  /^192\.168\./,
  /^172\.(1[6-9]|2\d|3[0-1])\./,
  /^169\.254\./,
  /^\[::1\]$/i,
];

const OFFICIAL_PROVIDER_HOSTS: Record<"morning" | "icount", string[]> = {
  morning: [
    "api.morning.co.il",
    "api.greeninvoice.co.il",
    "api.rivhit.co.il",
  ],
  icount: ["api.icount.co.il"],
};

const getAllowedHosts = (provider: "morning" | "icount"): string[] => {
  const envName =
    provider === "morning"
      ? "MORNING_ALLOWED_HOSTS"
      : "ICOUNT_ALLOWED_HOSTS";
  const extra = (process.env[envName] ?? "")
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);
  return [...OFFICIAL_PROVIDER_HOSTS[provider], ...extra];
};

const hostMatchesAllowlist = (host: string, allowlist: string[]): boolean => {
  const normalized = host.toLowerCase();
  return allowlist.some((allowed) => {
    const entry = allowed.toLowerCase();
    return normalized === entry || normalized.endsWith(`.${entry}`);
  });
};

const isPrivateHost = (host: string): boolean => {
  const normalized = host.toLowerCase();
  return PRIVATE_HOST_PATTERNS.some((pattern) => pattern.test(normalized));
};

export const validateAndNormalizeProviderBaseUrl = (
  provider: "morning" | "icount",
  value: string,
): string => {
  const trimmed = value.trim();
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new Error("Invalid provider base URL");
  }
  if (parsed.protocol !== "https:") {
    throw new Error("Provider base URL must use https://");
  }
  if (parsed.username || parsed.password) {
    throw new Error("Provider base URL must not include credentials");
  }
  if (isPrivateHost(parsed.hostname)) {
    throw new Error("Private/internal hosts are not allowed for provider URL");
  }
  if (!hostMatchesAllowlist(parsed.hostname, getAllowedHosts(provider))) {
    throw new Error("Provider base URL host is not allowed");
  }
  return `${parsed.origin}${parsed.pathname}`.replace(/\/+$/, "");
};
