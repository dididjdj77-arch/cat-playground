# Playbook: RPC Owner

> 이 문서는 owner 전용 RPC(쓰기/수정/멱등) 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-022, D-040, D-046

## 체크리스트

### Do
- [ ] owner 식별은 `auth.uid()`를 강제한다.
- [ ] 트랜잭션 경계를 명시해 partial write를 방지한다.
- [ ] `idempotency_key` 중복을 서버에서 차단한다.
- [ ] `expected_version` 불일치 시 409 충돌을 반환한다.
- [ ] 충돌 응답은 `error_code/current_version/(optional) current_group_snapshot` 구조를 따른다.
- [ ] like_count는 원자 UPDATE(`= like_count + 1`)로 처리한다.
- [ ] inventory 수정은 `is_current=false + 새 row` 패턴을 사용한다.

### Don't
- [ ] read-modify-write로 like_count를 업데이트하지 않는다.
- [ ] 멱등키 없이 재시도 가능한 쓰기 RPC를 만들지 않는다.
- [ ] inventory row를 delete 방식으로 제거하지 않는다.

## 템플릿

```sql
create or replace function public.rpc_upsert_owner_item(
  p_idempotency_key text,
  p_expected_version int,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_current_version int;
begin
  if v_owner_id is null then
    raise exception 'unauthorized';
  end if;

  perform 1
  from public.observation_groups g
  where g.owner_id = v_owner_id
    and g.idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object('status', 'idempotent-replay');
  end if;

  select version into v_current_version
  from public.observation_groups
  where owner_id = v_owner_id
  order by created_at desc
  limit 1;

  if v_current_version is not null and v_current_version <> p_expected_version then
    -- 충돌 페이로드 구조는 RPC-SPECS/API-CONTRACTS를 따른다.
    -- HTTP 상태코드 매핑은 라우트/API 계층에서 결정한다.
    return jsonb_build_object(
      'error_code', 'version_conflict',
      'current_version', v_current_version
    );
  end if;

  -- write payload in one transaction boundary
  return jsonb_build_object('status', 'ok');
end;
$$;
```

## 검증

### 스모크 테스트

```sql
-- 동일 idempotency_key 2회 호출 시 두 번째는 replay 처리 기대
-- expected_version 일치 시 저장 성공 기대
```

### 네거티브 테스트

```sql
-- expected_version 불일치 시 409(충돌) 기대
-- inventory delete 시도는 거부되고 is_current=false + 새 row 경로만 허용 기대
```

## 근거 링크
- See: DECISIONS D-022
- See: DECISIONS D-040
- See: DECISIONS D-046
- See: docs/PROCESS.md#6-고위험-판정-원칙-from-d-032
