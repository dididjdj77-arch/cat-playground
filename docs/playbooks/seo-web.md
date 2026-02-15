# Playbook: SEO / Web (Next.js SSR/ISR)

> 이 문서는 웹(SEO) 라우트 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-015, D-021, D-025, D-050, ROUTES-AND-IA.md
> 보안 주의: `REVALIDATE_SECRET`은 서버 전용이다. 클라이언트 번들/브라우저 호출/로그 평문 노출을 금지한다.

## 체크리스트

### Do
- [ ] index 대상 라우트: `/c`, `/c/{topicSlug}`, `/c/{topicSlug}/{threadId}`, `/p`, `/p/{postId}`
- [ ] noindex 대상: `/search?q=...` (D-021)
- [ ] SSR/ISR 캐시 전략을 라우트별로 명시한다.
- [ ] v1 SEO surface는 anon 기준 결과로 고정한다(ISR/캐시 우선).
- [ ] SEO surface에서 auth 뷰어별 block/개인화 정합성은 보장 대상이 아님을 명시한다.
- [ ] auth 뷰어별 정합성은 비-SEO 동적 표면(SSR/no-store)에서 보장한다.
- [ ] hidden_at/deleted_at이 설정된 콘텐츠는 404를 반환한다 (D-050).
- [ ] 공개 조건 불만족(비공개/미발행/차단/숨김/삭제) 시 404로 통일한다 (D-050).
- [ ] 재검증(revalidation) 트리거를 명시한다: 발행/숨김/삭제/수정 이벤트.
- [ ] revalidate endpoint는 `x-revalidate-secret` 헤더만 허용한다(query/body 금지).
- [ ] revalidate 대상 path는 allowlist(v1)로 제한한다. 임의 path 재검증은 금지한다.
- [ ] revalidate allowlist는 코드 상수 1곳을 SSOT로 두고, 테스트도 동일 상수를 import한다.
- [ ] meta tags(title/description/og:*)를 콘텐츠에서 동적 생성한다.
- [ ] 공개 하우스는 auth-only이므로 SEO 제외(v1) 처리한다.

### Don't
- [ ] `/search` 결과를 index하지 않는다.
- [ ] hidden/deleted 콘텐츠를 캐시에 남기지 않는다 (재검증 트리거 필수).
- [ ] 크롤러에게 인증이 필요한 페이지를 200으로 반환하지 않는다.
- [ ] ISR 캐시 TTL을 과도하게 길게(예: 24h+) 두지 않는다.
- [ ] SEO 라우트에서 로그인 상태를 키로 한 viewer별 분기 캐시를 두지 않는다.
- [ ] `path` 입력을 사용자 입력 그대로 revalidate에 전달하지 않는다(allowlist 매핑 없이 금지).
- [ ] revalidate secret을 query/body/로그에 평문으로 남기지 않는다.

## 라우트별 정책 요약

v1 고정 규칙: SEO 라우트는 로그인 여부와 무관하게 anon 기준 공개 결과를 반환한다.

| 라우트 | index | SSR/ISR | 공개 조건 |
|--------|-------|---------|-----------|
| /c | index | ISR | topic.deleted_at is null |
| /c/{topicSlug} | index | ISR | topic 존재 + deleted_at null |
| /c/{topicSlug}/{threadId} | index | ISR | thread guard_soft_state + guard_block(anon=no-op) |
| /p | index | ISR | 공개 post 목록 품질 게이트 통과 |
| /p/{postId} | index | ISR | post guard_soft_state + guard_visibility_published |
| /search?q=... | noindex | SSR | - |
| /u/{nickname}/house | noindex | - | auth-only (v1 SEO 제외) |

## 템플릿 (Next.js App Router 예시)

```typescript
// app/c/[topicSlug]/[threadId]/page.tsx
export const revalidate = 300; // 5분 ISR

export async function generateMetadata({ params }) {
  const thread = await getPublicThread(params.threadId);
  if (!thread) return { title: "Not Found" };
  return {
    title: thread.title,
    description: thread.body?.slice(0, 160),
    robots: { index: true, follow: true },
  };
}

export default async function ThreadPage({ params }) {
  const thread = await getPublicThread(params.threadId);
  if (!thread) notFound(); // -> 404
  return <ThreadDetail thread={thread} />;
}
```

## 재검증 트리거 (D-072)

### 이벤트→revalidate 경로 매핑

| 이벤트 | revalidate 경로 | 추가 작업 |
|--------|----------------|----------|
| post publish | `/p/{postId}`, `/p` | 썸네일 생성 |
| post unpublish/hide/delete | `/p/{postId}`, `/p` | **썸네일 삭제** |
| thread create | `/c/{topicSlug}/{threadId}`, `/c/{topicSlug}` | — |
| thread hide/delete | `/c/{topicSlug}/{threadId}`, `/c/{topicSlug}` | — |
| topic create/delete | `/c`, `/c/{topicSlug}` | — |

### revalidate 보안 규약 (v1)

- 호출 주체는 서버만 허용한다(예: Route Handler, 서버 액션, 백엔드 워커).
- `REVALIDATE_SECRET`은 서버 환경변수에서만 읽는다.
- 비밀키 전달은 `x-revalidate-secret` 헤더만 허용한다(query/body 금지).
- 결과 코드는 아래를 고정한다:
  - missing/empty secret -> 401
  - mismatch/invalid secret -> 403
  - allowlist 밖 path -> 403
  - allowlist path -> 200
- allowlist는 코드 상수 1곳을 SSOT로 두고, 문서는 해당 상수를 참조만 한다(복제 금지).
- v1은 tag 기반 재검증을 사용하지 않고 path allowlist만 사용한다.

```typescript
// server-only: Route Handler / server action / worker context
await fetch(`/api/revalidate?path=/c/${topicSlug}/${threadId}`, {
  method: "POST",
  headers: { "x-revalidate-secret": process.env.REVALIDATE_SECRET! },
});
await fetch(`/api/revalidate?path=/p/${postId}`, {
  method: "POST",
  headers: { "x-revalidate-secret": process.env.REVALIDATE_SECRET! },
});
```

## 검증

### 스모크 테스트

```bash
curl -s -o /dev/null -w "%{http_code}" https://localhost:3000/c/general/test-thread-id
# 기대: 200

curl -s https://localhost:3000/search?q=test | grep -i "noindex"
# 기대: <meta name="robots" content="noindex" />
```

### 네거티브 테스트

```bash
curl -s -o /dev/null -w "%{http_code}" https://localhost:3000/c/general/hidden-thread-id
# 기대: 404

curl -s -o /dev/null -w "%{http_code}" https://localhost:3000/c/general/nonexistent-id
# 기대: 404
```

### revalidate 보안 네거티브 테스트

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST "https://localhost:3000/api/revalidate?path=/p/123"
# 기대: 401 (secret 없음)

curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "x-revalidate-secret: WRONG" \
  "https://localhost:3000/api/revalidate?path=/p/123"
# 기대: 403 (secret 불일치)

curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "x-revalidate-secret: ${REVALIDATE_SECRET}" \
  "https://localhost:3000/api/revalidate?path=/admin"
# 기대: 403 (allowlist 밖 path)

curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "x-revalidate-secret: ${REVALIDATE_SECRET}" \
  "https://localhost:3000/api/revalidate?path=/p/123"
# 기대: 200 (allowlist path)
```

## 근거 링크
- See: DECISIONS D-015, D-021, D-025, D-050
- See: docs/ROUTES-AND-IA.md
- See: docs/ARCHITECTURE-OVERVIEW.md
