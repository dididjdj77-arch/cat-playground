import { ERROR_CODES, type ErrorCode } from "./error-codes";

export const RPC_ERROR_CODE_TO_HTTP_STATUS = {
  not_found: 404,
  version_conflict: 409,
  invalid_request: 400,
  invalid_payload_version: 400,
  rejected_version: 400,
  terms_not_agreed: 403,
  duplicate_report: 409,
  invalid_target_type: 400,
  invalid_inventory_item: 400,
} as const satisfies Record<ErrorCode, 400 | 403 | 404 | 409>;

export type RpcHttpStatus = (typeof RPC_ERROR_CODE_TO_HTTP_STATUS)[ErrorCode];

export interface RpcErrorBody {
  error_code: ErrorCode;
  [key: string]: unknown;
}

export interface RpcTypedErrorArgs {
  rpcName: string;
  body: RpcErrorBody;
}

const ERROR_CODE_LOOKUP: ReadonlySet<string> = new Set(ERROR_CODES);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function assertNever(value: never): never {
  throw new Error(`Unhandled RPC error code: ${String(value)}`);
}

function buildErrorMessage({ rpcName, body }: RpcTypedErrorArgs): string {
  const status = RPC_ERROR_CODE_TO_HTTP_STATUS[body.error_code];
  return `RPC ${rpcName} failed with error_code=${body.error_code} (HTTP ${status})`;
}

export function readRpcErrorCode(value: unknown): string | null {
  if (!isRecord(value)) {
    return null;
  }

  const errorCode = value.error_code;
  if (typeof errorCode !== "string") {
    return null;
  }

  return errorCode;
}

export function parseRpcErrorBody(value: unknown): RpcErrorBody | null {
  const errorCode = readRpcErrorCode(value);

  if (errorCode === null || !ERROR_CODE_LOOKUP.has(errorCode) || !isRecord(value)) {
    return null;
  }

  return {
    ...value,
    error_code: errorCode,
  } as RpcErrorBody;
}

export class RpcBusinessError extends Error {
  readonly rpcName: string;
  readonly code: ErrorCode;
  readonly status: RpcHttpStatus;
  readonly body: RpcErrorBody;

  constructor(args: RpcTypedErrorArgs) {
    super(buildErrorMessage(args));
    this.name = "RpcBusinessError";
    this.rpcName = args.rpcName;
    this.code = args.body.error_code;
    this.status = RPC_ERROR_CODE_TO_HTTP_STATUS[args.body.error_code];
    this.body = args.body;
  }
}

export class NotFoundError extends RpcBusinessError {
  constructor(args: RpcTypedErrorArgs) {
    super(args);
    this.name = "NotFoundError";
  }
}

export class ConflictError extends RpcBusinessError {
  constructor(args: RpcTypedErrorArgs) {
    super(args);
    this.name = "ConflictError";
  }
}

export class ValidationError extends RpcBusinessError {
  constructor(args: RpcTypedErrorArgs) {
    super(args);
    this.name = "ValidationError";
  }
}

export class TermsError extends RpcBusinessError {
  constructor(args: RpcTypedErrorArgs) {
    super(args);
    this.name = "TermsError";
  }
}

export type TypedRpcError = NotFoundError | ConflictError | ValidationError | TermsError;

export function toTypedRpcError(args: RpcTypedErrorArgs): TypedRpcError {
  switch (args.body.error_code) {
    case "not_found":
      return new NotFoundError(args);
    case "version_conflict":
    case "duplicate_report":
      return new ConflictError(args);
    case "terms_not_agreed":
      return new TermsError(args);
    case "invalid_request":
    case "invalid_payload_version":
    case "rejected_version":
    case "invalid_target_type":
    case "invalid_inventory_item":
      return new ValidationError(args);
    default:
      return assertNever(args.body.error_code);
  }
}
