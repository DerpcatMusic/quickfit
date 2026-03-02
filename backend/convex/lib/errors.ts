export const ErrorCode = {
  authRequired: "AUTH_REQUIRED",
  userNotFound: "USER_NOT_FOUND",
  studioOnly: "STUDIO_ONLY",
  instructorOnly: "INSTRUCTOR_ONLY",
} as const;

export type ErrorCodeValue = (typeof ErrorCode)[keyof typeof ErrorCode];

export function domainError(code: ErrorCodeValue, message?: string): Error {
  const error = new Error(message ?? code) as Error & { code?: string };
  error.code = code;
  return error;
}

