import { failWithList, readText } from "./repo-spine-check.mjs";

const sharedIndex = readText("packages/shared/src/index.ts");
const errorCodes = readText("packages/shared/src/error-codes.ts");
const publicDto = readText("packages/shared/src/public-dto.ts");

const missingExports = [];
for (const token of [
  "export { ERROR_CODES }",
  "export type { ErrorCode }",
  "export { PUBLIC_HOUSE_SLOT_WHITELIST }",
  "export type { PublicHouseSlotDto, PublicHouseSlotKey }"
]) {
  if (!sharedIndex.includes(token)) {
    missingExports.push(token);
  }
}

const missingErrorCodes = [];
for (const code of ["not_found", "terms_not_agreed", "version_conflict"]) {
  if (!errorCodes.includes(`"${code}"`)) {
    missingErrorCodes.push(code);
  }
}

const missingWhitelistFields = [];
for (const field of ["slot_key", "equipped_at", "type", "standard_name"]) {
  if (!publicDto.includes(`"${field}"`)) {
    missingWhitelistFields.push(field);
  }
}

const forbiddenWhitelistFields = [];
for (const field of ["inventory_item_id", "raw_text", "note", "meta", "avatar_key", "avatar_url"]) {
  if (publicDto.includes(`"${field}"`)) {
    forbiddenWhitelistFields.push(field);
  }
}

const failed =
  failWithList("packages/shared/src/index.ts missing exports", missingExports) ||
  failWithList("packages/shared/src/error-codes.ts missing baseline error codes", missingErrorCodes) ||
  failWithList("packages/shared/src/public-dto.ts missing whitelist fields", missingWhitelistFields) ||
  failWithList("packages/shared/src/public-dto.ts contains forbidden fields", forbiddenWhitelistFields);

if (failed) {
  process.exit(1);
}

console.log("PASS: repo:typecheck");
