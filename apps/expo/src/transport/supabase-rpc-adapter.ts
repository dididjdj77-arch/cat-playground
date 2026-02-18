import type { SupabaseClient } from "@supabase/supabase-js";
import { parseRpcErrorBody, readRpcErrorCode, toTypedRpcError } from "@cat-playground/shared";

export class UnknownRpcErrorCodeError extends Error {
  readonly rpcName: string;
  readonly errorCode: string;
  readonly body: unknown;

  constructor(rpcName: string, errorCode: string, body: unknown) {
    super(`RPC ${rpcName} returned unknown error_code=${errorCode}`);
    this.name = "UnknownRpcErrorCodeError";
    this.rpcName = rpcName;
    this.errorCode = errorCode;
    this.body = body;
  }
}

export async function callSupabaseRpcWithAdapter<TResult = unknown>(
  client: SupabaseClient,
  rpcName: string,
  rpcArgs?: Record<string, unknown>,
): Promise<TResult> {
  const response = rpcArgs === undefined ? await client.rpc(rpcName) : await client.rpc(rpcName, rpcArgs);

  if (response.error) {
    throw response.error;
  }

  const parsedBody = parseRpcErrorBody(response.data);
  if (parsedBody) {
    throw toTypedRpcError({ rpcName, body: parsedBody });
  }

  const rawErrorCode = readRpcErrorCode(response.data);
  if (rawErrorCode !== null) {
    throw new UnknownRpcErrorCodeError(rpcName, rawErrorCode, response.data);
  }

  return response.data as TResult;
}
