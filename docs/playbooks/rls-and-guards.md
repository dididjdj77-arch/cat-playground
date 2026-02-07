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
- [ ] 반환 컬럼은 화이트리스트로 명시한다.

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
  limit greatest(p_limit, 1);
$$;
```

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
