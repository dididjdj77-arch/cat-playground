# Playbook: Moderation (신고/자동숨김/차단)

> 이 문서는 모더레이션(신고/자동숨김/차단/감사로그) 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-014, D-019, D-024, D-052, D-053, D-054, D-056

## 체크리스트

### Do
- [ ] 신고 시 `reports.snapshot(jsonb)`에 대상 콘텐츠의 현재 상태를 저장한다 (D-052).
- [ ] 동일 사용자/동일 대상 중복 신고를 방지한다.
- [ ] 대상 콘텐츠가 존재하지 않으면 report row를 생성하지 않고 에러를 반환한다.
- [ ] 자동숨김 트리거: 서로 다른 신뢰 신고자 N명(CONFIG-BASELINES §2) 충족 시 `hidden_at` 설정.
- [ ] 자동숨김은 `hidden_at`만 설정한다 (`deleted_at` 아님, D-024).
- [ ] 신고자 신뢰 조건(계정 생성 경과일)과 시간창(window)은 CONFIG-BASELINES를 따른다.
- [ ] 차단(block): blocker/blocked 양방향 비노출 + 상호작용 불가를 보장한다 (D-019).
- [ ] anon viewer는 block 필터 미적용(no-op) 규칙을 유지한다.
- [ ] 모든 모더레이션 액션은 감사로그(`moderation_actions`)를 기록한다.
- [ ] 임계값/레이트리밋은 `app_config`를 통해 런타임 조회한다 (코드 상수 금지, D-056).

### Don't
- [ ] 자동숨김으로 `deleted_at`을 설정하지 않는다.
- [ ] 동일 신고를 중복 저장하지 않는다.
- [ ] 차단 필터를 anon에 적용하지 않는다.
- [ ] 임계값/레이트리밋을 코드 상수로 하드코딩하지 않는다.

## 템플릿

### 신고 + 스냅샷

```sql
create or replace function public.rpc_report_content(
  p_target_type text,
  p_target_id uuid,
  p_reason_code text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reporter_id uuid := auth.uid();
  v_target_user_id uuid;
  v_snapshot jsonb;
  v_report_id uuid;
  v_err jsonb;
begin
  if v_reporter_id is null then
    raise exception 'auth required';
  end if;

  -- 1) write 공통 가드(LOCK): terms -> block -> soft_state -> domain
  v_err := public.guard_terms_agreed();
  if v_err is not null then
    return v_err;
  end if;

  -- 2) 대상 존재/가드 검증 + snapshot 구성 (존재 은닉: 실패는 not_found로 통일)
  case p_target_type
    when 'post' then
      select p.author_id, to_jsonb(p.*)
        into v_target_user_id, v_snapshot
      from public.posts p
      where p.id = p_target_id
        and public.guard_soft_state(p.deleted_at, p.hidden_at)
        and public.guard_block(v_reporter_id, p.author_id)
        and public.guard_visibility_published(p.visibility, p.published_at);

    when 'thread' then
      select t.author_id, to_jsonb(t.*)
        into v_target_user_id, v_snapshot
      from public.threads t
      where t.id = p_target_id
        and public.guard_soft_state(t.deleted_at, t.hidden_at)
        and public.guard_block(v_reporter_id, t.author_id);

    when 'comment' then
      -- 부모 post 공개 가드 종속(D-063)
      select p.author_id
        into v_target_user_id
      from public.posts p
      join public.comments c on c.post_id = p.id
      where c.id = p_target_id
        and public.guard_soft_state(p.deleted_at, p.hidden_at)
        and public.guard_block(v_reporter_id, p.author_id)
        and public.guard_visibility_published(p.visibility, p.published_at);

      if v_target_user_id is not null then
        select to_jsonb(c.*) into v_snapshot
        from public.comments c
        where c.id = p_target_id
          and public.guard_soft_state(c.deleted_at, c.hidden_at)
          and public.guard_block(v_reporter_id, c.author_id);
      end if;

    when 'reply' then
      -- 부모 thread 공개 가드 종속(threads는 visibility/published 가드 없음)
      select t.author_id
        into v_target_user_id
      from public.threads t
      join public.replies r on r.thread_id = t.id
      where r.id = p_target_id
        and public.guard_soft_state(t.deleted_at, t.hidden_at)
        and public.guard_block(v_reporter_id, t.author_id);

      if v_target_user_id is not null then
        select to_jsonb(r.*) into v_snapshot
        from public.replies r
        where r.id = p_target_id
          and public.guard_soft_state(r.deleted_at, r.hidden_at)
          and public.guard_block(v_reporter_id, r.author_id);
      end if;

    else
      return jsonb_build_object('error_code', 'invalid_target_type');
  end case;

  if v_snapshot is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- 3) 중복 신고 방지 + 저장
  insert into public.reports (reporter_id, target_type, target_id, reason_code, note, snapshot)
  values (v_reporter_id, p_target_type, p_target_id, p_reason_code, p_note, v_snapshot)
  on conflict (reporter_id, target_type, target_id) where deleted_at is null
  do nothing
  returning id into v_report_id;

  if v_report_id is null then
    return jsonb_build_object('error_code', 'duplicate_report');
  end if;

  insert into public.moderation_actions (actor_id, action, target_type, target_id, meta)
  values (v_reporter_id, 'report', p_target_type, p_target_id, jsonb_build_object('report_id', v_report_id));

  perform public.check_auto_hide(p_target_type, p_target_id);

  return jsonb_build_object('report_id', v_report_id);
end;
$$;
```

### 자동숨김 체크 (스켈레톤)

```sql
create or replace function public.check_auto_hide(
  p_target_type text,
  p_target_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_config jsonb;
  v_threshold int;
  v_window_hours int;
  v_trust_days int;
  v_count int;
begin
  select value into v_config from public.app_config where key = 'auto_hide';
  v_threshold := (v_config->>'threshold_n')::int;
  v_window_hours := (v_config->>'window_hours')::int;
  v_trust_days := coalesce((v_config->>'trust_days')::int, 7);

  select count(distinct r.reporter_id) into v_count
  from public.reports r
  join public.profiles pr on pr.user_id = r.reporter_id
  where r.target_type = p_target_type
    and r.target_id = p_target_id
    and r.deleted_at is null
    and r.created_at >= now() - (v_window_hours || ' hours')::interval
    and pr.created_at <= now() - (v_trust_days || ' days')::interval;

  if v_count >= v_threshold then
    case p_target_type
      when 'post' then update public.posts set hidden_at = now() where id = p_target_id and hidden_at is null;
      when 'comment' then update public.comments set hidden_at = now() where id = p_target_id and hidden_at is null;
      when 'thread' then update public.threads set hidden_at = now() where id = p_target_id and hidden_at is null;
      when 'reply' then update public.replies set hidden_at = now() where id = p_target_id and hidden_at is null;
    end case;

    insert into public.moderation_actions (actor_id, action, target_type, target_id, meta)
    values (null, 'auto_hide', p_target_type, p_target_id, jsonb_build_object('report_count', v_count));
  end if;
end;
$$;
```

## 검증

### 스모크 테스트

```sql
-- 사전조건: 대상 post가 존재
select public.rpc_report_content('post', '<existing-post-uuid>', 'spam', 'test report');
-- 기대: {"report_id":"..."}
```

### 네거티브 테스트

```sql
select public.rpc_report_content('post', '00000000-0000-0000-0000-000000000000', 'spam');
-- 기대: {"error_code":"not_found"}

-- 사전조건: 동일 reporter/target으로 이미 신고 1건 존재
select public.rpc_report_content('post', '<existing-post-uuid>', 'spam');
-- 기대: {"error_code":"duplicate_report"}
```

## 근거 링크
- See: DECISIONS D-014, D-019, D-024, D-052, D-053, D-054, D-056
- See: docs/CONFIG-BASELINES.md
- See: docs/AUTHZ-MODEL.md#0-2
- See: docs/playbooks/ops-app-config.md
