export const ERROR_CODES = [
  "not_found",
  "terms_not_agreed",
  "version_conflict",
  "invalid_payload_version",
  "rejected_version",
  "duplicate_report",
  "invalid_request"
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];
