/**
 * app_config key/value type definitions.
 * SSOT: CONFIG-BASELINES.md §3
 */

export const APP_CONFIG_KEYS = [
  "rate_limits",
  "rate_limits_new_account",
  "auto_hide",
  "popular_feed",
] as const;

export type AppConfigKey = (typeof APP_CONFIG_KEYS)[number];

// --- value shapes per key ---

export interface RateLimitEntry {
  per_minute: number;
  per_day: number;
}

/** §1 일반 계정 / 신규 계정 rate limits */
export interface RateLimitsValue {
  posts: RateLimitEntry;
  comments_replies: RateLimitEntry;
  likes: RateLimitEntry;
  reports: RateLimitEntry;
}

/** §2 Auto-Hide Threshold */
export interface AutoHideValue {
  threshold_n: number;
  window_hours: number;
  trust_days: number;
}

/** §4a Popular Feed */
export interface PopularFeedValue {
  like_weight: number;
  reply_weight: number;
  window_days: number;
}

/** key → value shape mapping */
export interface AppConfigValueMap {
  rate_limits: RateLimitsValue;
  rate_limits_new_account: RateLimitsValue;
  auto_hide: AutoHideValue;
  popular_feed: PopularFeedValue;
}

/**
 * RPC 응답 타입.
 * Partial: 클라이언트가 아직 모르는 키는 무시할 수 있도록.
 */
export type AppConfigResponse = {
  [K in AppConfigKey]?: AppConfigValueMap[K];
};
