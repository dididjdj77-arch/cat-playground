# Playbook: SEO / Web (Next.js SSR/ISR)

> 이 문서는 웹(SEO) 라우트 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-015, D-021, D-025, D-050, ROUTES-AND-IA.md

## 체크리스트

### Do
- [ ] index 대상 라우트: `/c`, `/c/{topicSlug}`, `/c/{topicSlug}/{threadId}`, `/p`, `/p/{postId}`
- [ ] noindex 대상: `/search?q=...` (D-021)
- [ ] SSR/ISR 캐시 전략을 라우트별로 명시한다.
- [ ] hidden_at/deleted_at이 설정된 콘텐츠는 404를 반환한다 (D-050).
- [ ] 공개 조건 불만족(비공개/미발행/차단/숨김/삭제) 시 404로 통일한다 (D-050).
- [ ] 재검증(revalidation) 트리거를 명시한다: 발행/숨김/삭제/수정 이벤트.
- [ ] meta tags(title/description/og:*)를 콘텐츠에서 동적 생성한다.
- [ ] 공개 하우스는 auth-only이므로 SEO 제외(v1) 처리한다.

### Don't
- [ ] `/search` 결과를 index하지 않는다.
- [ ] hidden/deleted 콘텐츠를 캐시에 남기지 않는다 (재검증 트리거 필수).
- [ ] 크롤러에게 인증이 필요한 페이지를 200으로 반환하지 않는다.
- [ ] ISR 캐시 TTL을 과도하게 길게(예: 24h+) 두지 않는다.

## 라우트별 정책 요약

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

## 재검증 트리거 (권장)

```typescript
await fetch(`/api/revalidate?path=/c/${topicSlug}/${threadId}`, { method: "POST" });
await fetch(`/api/revalidate?path=/p/${postId}`, { method: "POST" });
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

## 근거 링크
- See: DECISIONS D-015, D-021, D-025, D-050
- See: docs/ROUTES-AND-IA.md
- See: docs/ARCHITECTURE-OVERVIEW.md
