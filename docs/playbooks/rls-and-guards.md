# Playbook: RLS And Guards

> 이 문서는 RLS/가드 함수 적용 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-029, ADR-005, AUTHZ-MODEL §0

## 체크리스트

### Do
- [ ] `SECURITY DEFINER` 함수는 `set search_path`를 고정한다.
- [ ] viewer 식별은 `auth.uid()`에서 직접 도출한다.
- [ ] `guard_soft_state`(deleted/hidden) 필터를 항상 적용한다.
- [ ] `guard_block`(viewer-target 상호 비노출) 필터를 항상 적용한다.
- [ ] posts/house 계열은 `guard_visibility_published`를 함께 적용한다.
- [ ] posts/house 계열은 `guard_visibility_published`를 적용하고, threads/replies에는 적용하지 않는다 (D-016).
- [ ] 반환 컬럼은 화이트리스트로 명시한다.
- [ ] `p_limit`는 하한/상한 캡을 함께 적용한다(예: 1~100).

### Don't
- [ ] `p_viewer_id` 같은 외부 입력 파라미터를 신뢰하지 않는다.
- [ ] `select *`를 사용하지 않는다.
- [ ] 원본 테이블 direct SELECT를 클라이언트에 열지 않는다.
- [ ] threads/replies에 visibility 가드를 무분별하게 복제하지 않는다.

## 템플릿

```sql
create or replace function public.rpc_list_public_threads(p_limit int default 20)
returns table (
  thread_id uuid,
  title text,
  created_at timestamptz
)
language sql
security definer
set search_path = public, pg_temp
as $$
  with base as (
    select t.id, t.title, t.created_at, t.author_id
    from public.threads t
    where public.guard_soft_state(t.deleted_at, t.hidden_at)
      and public.guard_block(auth.uid(), t.author_id)
  )
  select b.id, b.title, b.created_at
  from base b
  order by b.created_at desc
  limit least(greatest(p_limit, 1), 100);
$$;
```

## 부모→자식 가드 체인 패턴 (D-063)

댓글처럼 부모 엔티티 공개 조건에 종속되는 자식 조회는 2단계 가드를 적용한다.

```sql
-- Step 1: 부모 가드 (post 예시)
select p.author_id into v_post_author
from public.posts p
where p.id = p_post_id
  and public.guard_soft_state(p.deleted_at, p.hidden_at)
  and public.guard_block(auth.uid(), p.author_id)
  and public.guard_visibility_published(p.visibility, p.published_at);

if v_post_author is null then
  return jsonb_build_object('error_code', 'not_found');  -- 외부 표면 404 (D-050)
end if;

-- Step 2: 자식 가드 (comments 예시)
select ...
from public.comments c
where c.post_id = p_post_id
  and public.guard_soft_state(c.deleted_at, c.hidden_at)
  and public.guard_block(auth.uid(), c.author_id);
```

핵심: 부모 가드 불만족 시 자식 0건이 아니라 `not_found`를 반환한다.

## 검증

### 스모크 테스트

```sql
-- 차단 없는 정상 상태에서 rows 존재 확인
select count(*) from public.rpc_list_public_threads(20);
```

### 네거티브 테스트

```sql
-- block 관계 생성 후 대상 authored row가 0인지 확인
-- hidden/deleted 설정 후 노출 0인지 확인
```

## 근거 링크
- See: DECISIONS D-029
- See: docs/AUTHZ-MODEL.md#0
- See: docs/RLS-POLICY.md
- See: docs/ADR/ADR-005-guard-filters-performance.md
