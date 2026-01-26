# HOWTO/local-setup — 로컬 셋업(초안)

전제: Expo 앱 + Next.js 웹 + Supabase 백엔드

1) Node LTS, pnpm, Supabase CLI 설치
2) supabase start
3) migrations 적용(supabase/migrations)
4) env 설정(SUPABASE_URL/KEY)
5) 앱 실행(expo start), 웹 실행(next dev)
6) 체크:
- anon으로 공개 토픽/스레드/공개 글 읽기
- 로그인 후 작성/댓글/답글/좋아요
- 차단/숨김이 노출 정책에 반영
