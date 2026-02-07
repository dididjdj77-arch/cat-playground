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

### Don't
- [ ] 롤백 계획 없이 배포하지 않는다.
- [ ] RLS 변경을 스키마 변경과 한 파일에 혼합하지 않는다.
- [ ] 검증 없이 대량 ALTER/백필을 본 환경에서 먼저 실행하지 않는다.

## 템플릿

```sql
-- migration skeleton
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
