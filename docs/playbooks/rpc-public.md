# Playbook: RPC Public

> 이 문서는 공개 조회 RPC(보안/노출/화이트리스트) 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-029, D-035~037, D-043, D-050, D-055

## 체크리스트

### Do
- [ ] `SECURITY DEFINER` + 고정 `search_path`를 사용한다.
- [ ] `guard_soft_state + guard_block + guard_visibility_published`를 적용한다.
- [ ] 반환 DTO는 D-055 화이트리스트 필드만 반환한다.
- [ ] 비공개/숨김/차단/미발행/미인증은 404로 통일한다.
- [ ] 하우스 공개 조회는 auth-only 규칙을 유지한다.
- [ ] non-current 슬롯은 공개 응답에서 제외(또는 empty)한다.

### Don't
- [ ] `select *`를 사용하지 않는다.
- [ ] `cats.avatar_url`을 join/노출하지 않는다.
- [ ] `inventory_item_id` 같은 내부 id를 노출하지 않는다.
- [ ] `raw_text/note/meta`를 공개 DTO에 포함하지 않는다.

## 템플릿

```sql
create or replace function public.rpc_get_public_house(p_target_user_id uuid)
returns table (
  slot_key text,
  equipped_at timestamptz,
  type text,
  standard_name text,
  brand text,
  days_since_equipped int
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select s.slot_key,
         s.equipped_at,
         i.type,
         c.standard_name,
         c.brand,
         case
           when s.equipped_at is null then null
           else extract(day from now() - s.equipped_at)::int
         end as days_since_equipped
  from public.house_slots s
  join public.house_profiles h on h.user_id = s.user_id
  join public.inventory_items i on i.id = s.inventory_item_id and i.is_current = true
  left join public.catalog_items c on c.id = i.catalog_item_id
  where s.user_id = p_target_user_id
    and public.guard_soft_state(h.deleted_at, h.hidden_at)
    and public.guard_block(auth.uid(), p_target_user_id)
    and public.guard_visibility_published(h.visibility, h.published_at);
$$;
```

## 검증

### 스모크 테스트

```sql
-- 공개+발행+비차단 상태에서 whitelist 필드만 반환되는지 확인
select * from public.rpc_get_public_house('00000000-0000-0000-0000-000000000000');
```

### 네거티브 테스트

```sql
-- 비공개/숨김/차단/미발행/미인증 조건에서 404 또는 no rows 확인
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
- See: docs/AUTHZ-MODEL.md#0
