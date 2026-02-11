# Playbook: Migrations

> 이 문서는 스키마 마이그레이션 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-032, PROCESS, SCHEMA-MIGRATIONS.md

## 체크리스트

### Do
- [ ] 변경 전 백업/스냅샷 경로를 명시한다.
- [ ] 테스트 환경에서 선검증 후 본 환경에 적용한다.
- [ ] 롤백 SQL(또는 revert 경로)을 먼저 준비한다.
- [ ] 파일 번호는 오름차순(`001_`, `002_`) 규칙을 지킨다.
- [ ] CHECK/UNIQUE 제약은 가능하면 `CREATE TABLE` 시점에 포함한다.
- [ ] RLS 정책은 마이그레이션 파일과 분리해 별도 단계로 관리한다.
- [ ] 대량 ALTER/백필 전 `lock_timeout`, `statement_timeout`을 설정한다.

### Don't
- [ ] 롤백 계획 없이 배포하지 않는다.
- [ ] RLS 변경을 스키마 변경과 한 파일에 혼합하지 않는다.
- [ ] 검증 없이 대량 ALTER/백필을 본 환경에서 먼저 실행하지 않는다.

## 실행 전략: fail-fast vs idempotent

- fail-fast는 중간 오류 시 즉시 중단해 불완전 상태를 막는 기본 전략이다. 구조 변경(`ALTER TABLE`, 제약 추가, 컬럼 타입 변경)은 fail-fast가 기본이다.
- idempotent는 재실행 안전성이 핵심인 단계에서 사용한다. `IF NOT EXISTS`, `ON CONFLICT DO NOTHING` 같은 구문은 반복 배포/복구 자동화에 유리하지만, 의도치 않은 드리프트를 숨기지 않도록 검증 쿼리와 함께 사용한다.

## 템플릿

```sql
-- migration skeleton
begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create table if not exists public.example_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint example_items_title_chk check (char_length(title) between 1 and 120),
  constraint example_items_owner_title_uniq unique (owner_id, title)
);

create index if not exists idx_example_items_owner_created
  on public.example_items (owner_id, created_at desc)
  where deleted_at is null;

commit;
```

## Rollback Skeleton

```sql
-- 최소 revert 경로 예시(실서비스는 변경 영향도에 맞춰 보강)
begin;

drop index if exists public.idx_example_items_owner_created;
drop table if exists public.example_items;

commit;
```

## 복합 마이그레이션 스켈레톤 (다중 테이블 + FK + seed)

```sql
begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

-- 1) 부모 테이블
create table if not exists public.parent_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);

-- 2) 자식 테이블 (FK -> 부모)
create table if not exists public.child_records (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.parent_items(id),
  owner_id uuid not null,
  record_type text not null,
  value jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint child_records_type_chk check (record_type in ('type_a','type_b','type_c')),
  constraint child_records_parent_type_uniq unique (parent_id, record_type)
);

-- 3) 인덱스
create index if not exists idx_parent_items_owner
  on public.parent_items (owner_id, created_at desc)
  where deleted_at is null;

create index if not exists idx_child_records_parent
  on public.child_records (parent_id);

-- 4) Seed (있으면)
-- insert into ... on conflict do nothing;

commit;
```

### 복합 Rollback

```sql
begin;

drop index if exists public.idx_child_records_parent;
drop index if exists public.idx_parent_items_owner;
drop table if exists public.child_records;
drop table if exists public.parent_items;

commit;
```

## 검증

### 스모크 테스트

```bash
supabase db reset
supabase db lint
```

```sql
select to_regclass('public.example_items');
```

### 네거티브 테스트

```sql
-- title check 위반 기대
insert into public.example_items (owner_id, title)
values ('00000000-0000-0000-0000-000000000000', '');
```

## 근거 링크
- See: DECISIONS D-032
- See: docs/SCHEMA-MIGRATIONS.md
- See: docs/PROCESS.md#6-고위험-판정-원칙-from-d-032
