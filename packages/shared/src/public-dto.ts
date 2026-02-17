export const PUBLIC_HOUSE_SLOT_WHITELIST = [
  "slot_key",
  "equipped_at",
  "type",
  "standard_name"
] as const;

export type PublicHouseSlotKey = (typeof PUBLIC_HOUSE_SLOT_WHITELIST)[number];

export type PublicHouseSlotDto = {
  slot_key: string;
  equipped_at: string | null;
  type: string | null;
  standard_name: string | null;
};
