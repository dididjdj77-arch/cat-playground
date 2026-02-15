# Playbook: RPC Public

> 이 문서는 공개 조회 RPC(보안/노출/화이트리스트) 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-029, D-035~037, D-043, D-050, D-055, D-063, D-065

## 체크리스트

### Do (공통 — 모든 공개 RPC)
- [ ] `SECURITY DEFINER` + 고정 `search_path`를 사용한다.
- [ ] `guard_soft_state`(deleted_at/hidden_at) 필터를 적용한다.
- [ ] `guard_block`(viewer_id, target_user_id) 필터를 적용한다.
- [ ] posts/house 계열은 `guard_visibility_published`를 추가 적용한다. threads/replies는 적용하지 않는다.
- [ ] 반환 컬럼은 명시적 화이트리스트로 제한한다 (`select *` 금지).
- [ ] `p_limit`는 하한/상한 캡을 적용한다 (`least(greatest(p_limit, 1), 100)`).
- [ ] cursor pagination은 keyset 방식을 기본으로 한다.
- [ ] 비즈니스 에러는 JSON return으로 전달한다 (D-065).
- [ ] 외부 라우트/API는 guard 불만족을 404로 통일한다 (D-050).
- [ ] 인증/권한 실패 에러 표현은 `docs/API.md` 표준 에러 체계와 정합되게 유지한다.
- [ ] write RPC는 `guard_terms_agreed()`를 적용한다 (D-073).
- [ ] write RPC가 섞이는 경우 guard 호출 순서를 고정한다: `guard_terms_agreed` → `guard_block` → `guard_soft_state` → `guard_visibility_published`.
- [ ] RPC 성격상 불필요한 guard는 `N/A`로 명시한다.

### Do (House 보충 — house 공개 RPC만)
- [ ] 반환 DTO는 D-055 화이트리스트(`slot_key`, `equipped_at`, `type`, `standard_name`)만 반환한다.
- [ ] `house_slots.owner_id`와 `house_profiles.user_id`를 기준으로 조인한다.
- [ ] `house_slots.deleted_at is null`을 필수로 적용한다.
- [ ] 빈 슬롯(`inventory_item_id is null`)은 포함하고, 인벤/카탈로그 컬럼은 nullable로 반환한다.
- [ ] auth-only는 DB 데이터 접근 요건으로 문서화하고 EXECUTE 권한으로 강제한다.

### Do (Comments 보충 — 댓글 공개 RPC만)
- [ ] 부모 post의 공개 가드(`guard_soft_state + guard_block + guard_visibility_published`)를 먼저 통과한 후에만 댓글을 반환한다 (D-063).
- [ ] 부모 post 가드 불만족 시 404를 반환한다 (댓글 0건이 아님).
- [ ] 댓글 자체에도 `guard_soft_state + guard_block`을 적용한다.

### Don't (공통)
- [ ] `select *`를 사용하지 않는다.
- [ ] `cats.avatar_key`/`cats.avatar_url`을 join/노출하지 않는다.
- [ ] `inventory_item_id` 같은 내부 id를 노출하지 않는다.
- [ ] `raw_text/note/meta`를 공개 DTO에 포함하지 않는다.
- [ ] D-055 비허용 필드를 DTO 예시/코드/주석 어디에도 넣지 않는다.
- [ ] threads/replies에 visibility/published 가드를 적용하지 않는다.

## 템플릿

```sql
create or replace function public.rpc_get_public_house_slots_summary(
  p_target_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_viewer_id uuid := auth.uid();
  v_slots jsonb;
begin
  if v_viewer_id is null then
    raise exception 'auth required';
  end if;

  with slot_keys as (
    select unnest(array[
      'slot_01','slot_02','slot_03','slot_04',
      'slot_05','slot_06','slot_07','slot_08'
    ]::text[]) as slot_key
  ),
  base as (
    select
      sk.slot_key,
      s.equipped_at,
      i.type,
      c.standard_name
    from slot_keys sk
    -- slot은 항상 8개를 반환하기 위해 LEFT JOIN
    left join public.house_slots s
      on s.owner_id = p_target_user_id
     and s.room_key = 'living_room'
     and s.slot_key = sk.slot_key
     and s.deleted_at is null
    -- 공개 조건은 house_profiles 기준으로 단일 판정
    join public.house_profiles h
      on h.user_id = p_target_user_id
    left join public.inventory_items i
      on i.id = s.inventory_item_id
     and i.is_current = true
     and i.deleted_at is null
    left join public.catalog_items c
      on c.id = i.catalog_item_id
    where public.guard_soft_state(h.deleted_at, h.hidden_at)
      and public.guard_block(v_viewer_id, p_target_user_id)
      and public.guard_visibility_published(h.visibility, h.published_at)
    order by sk.slot_key
  )
  select jsonb_agg(
           jsonb_build_object(
             'slot_key', slot_key,
             'equipped_at', equipped_at,
             'type', type,
             'standard_name', standard_name
           )
           order by slot_key
         )
    into v_slots
  from base;

  if v_slots is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  return jsonb_build_object('slots', v_slots);
end;
$$;

-- auth-only는 DB 데이터 접근 요건이다(anon EXECUTE 비허용 + 내부 auth check).
revoke all on function public.rpc_get_public_house_slots_summary(uuid) from public;
grant execute on function public.rpc_get_public_house_slots_summary(uuid) to authenticated;

-- 미인증 404는 외부 표면 정책이다.
-- 웹/API 라우트는 미인증 요청에서 DB 호출 유무와 무관하게 404를 반환한다.
```

### Posts Feed 스켈레톤 (예시)

```sql
create or replace function public.rpc_get_public_posts_feed(
  p_cursor text default null,
  p_limit int default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_viewer_id uuid := auth.uid(); -- anon이면 null
  v_result jsonb;
begin
  with feed as (
    select p.id, p.body, p.log_date, p.like_count, p.comment_count,
           p.published_at, p.created_at,
           pr.nickname as author_nickname
    from public.posts p
    join public.profiles pr on pr.user_id = p.author_id
    where p.deleted_at is null
      and p.hidden_at is null
      and p.visibility = 'public'
      and p.published_at is not null
      and public.guard_block(v_viewer_id, p.author_id)
      and (p_cursor is null or p.published_at < p_cursor::timestamptz)
    order by p.published_at desc
    limit least(greatest(p_limit, 1), 100)
  )
  select jsonb_agg(to_jsonb(feed)) into v_result from feed;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;
```

### Comments (부모 가드 종속) 스켈레톤 (예시)

```sql
create or replace function public.rpc_get_public_post_comments(
  p_post_id uuid,
  p_cursor text default null,
  p_limit int default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_viewer_id uuid := auth.uid();
  v_post_author_id uuid;
  v_result jsonb;
begin
  -- Step 1: 부모 post 가드 (D-063)
  select p.author_id into v_post_author_id
  from public.posts p
  where p.id = p_post_id
    and p.deleted_at is null
    and p.hidden_at is null
    and p.visibility = 'public'
    and p.published_at is not null
    and public.guard_block(v_viewer_id, p.author_id);

  if v_post_author_id is null then
    -- 부모 post가 공개 조건 불만족 → 404 (댓글 0건이 아님)
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- Step 2: 댓글 조회 (자체 guard)
  with comments as (
    select c.id, c.body, c.like_count, c.edited_at, c.created_at,
           pr.nickname as author_nickname
    from public.comments c
    join public.profiles pr on pr.user_id = c.author_id
    where c.post_id = p_post_id
      and c.deleted_at is null
      and c.hidden_at is null
      and public.guard_block(v_viewer_id, c.author_id)
      and (p_cursor is null or c.created_at < p_cursor::timestamptz)
    order by c.created_at desc
    limit least(greatest(p_limit, 1), 100)
  )
  select jsonb_agg(to_jsonb(comments)) into v_result from comments;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;
```

## 검증

### 스모크 테스트

```sql
-- 공개+발행+비차단 상태에서 whitelist 필드만 반환되는지 확인
select *
from public.rpc_get_public_house_slots_summary('00000000-0000-0000-0000-000000000000');
```

### 네거티브 테스트

```sql
-- DB 직접 호출(anon)은 EXECUTE 거부 또는 auth required 에러 확인
-- 외부 라우트/API는 미인증/비공개/숨김/삭제/차단/미발행에서 404 확인
-- 반환 컬럼에 avatar_url, inventory_item_id, raw_text/note/meta 없는지 확인
```

## 근거 링크
- See: DECISIONS D-029
- See: DECISIONS D-035
- See: DECISIONS D-036
- See: DECISIONS D-037
- See: DECISIONS D-043
- See: DECISIONS D-050
- See: DECISIONS D-055
- See: DECISIONS D-063
- See: DECISIONS D-065
- See: docs/AUTHZ-MODEL.md#0
