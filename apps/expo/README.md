# Expo Auth Session (P2-01A)

This package keeps the original tab routes and adds an auth session console in
`app/(tabs)/settings.tsx`.

## Scope in this EP

- Preserve tab route stubs: `house`, `diary`, `social`, `settings`
- Add auth/session flow in Settings tab:
  - OAuth sign-in buttons (Apple, Kakao required, Google optional)
  - Session create/store/restore check and sign-out
  - auth-only RPC call: `rpc_get_app_config` via transport adapter
- Record AS gate evidence logs in-app

## Required env keys

Copy `apps/expo/.env.example` and fill with real values:

- `EXPO_PUBLIC_SUPABASE_URL`
- `EXPO_PUBLIC_SUPABASE_ANON_KEY`
- `EXPO_PUBLIC_AUTH_REDIRECT_SCHEME`

`EXPO_PUBLIC_AUTH_REDIRECT_SCHEME` must match the app deep-link scheme configured for OAuth callback.

## Manual verification checklist (AS-1 ~ AS-5)

Use the Settings tab and capture screenshots/logs for each platform (iOS, Android):

1. AS-1: successful login (Apple and Kakao required, Google optional)
2. AS-2: redirect/deep link round-trip succeeds
3. AS-3: session survives app restart and can be read
4. AS-4: `rpc_get_app_config` returns config payload
5. AS-5: env reproducibility tracked per environment (dev/staging/prod)

At least one negative case should be captured (for example: user cancels OAuth
or a network failure during session/RPC verification).
