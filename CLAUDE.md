# CLAUDE.md — Project Context for Claude Code

## Verification Flow (검증 플로우)
사용자가 "검증해줘" 요청 시 아래 순서로 실행:

1. **CI 게이트**: `npm run ci:verify && npm run ci:drift`
2. **DB 실제 검증**: `docker exec supabase_db_cat-playground psql -U postgres -d postgres -c "<query>"`
   - 테이블 존재 확인
   - 제약조건(PK/FK/CHECK/UNIQUE) 확인
   - 인덱스 확인
3. **스펙 대조**: EP 문서 + `docs/DATA-MODEL.md` + `docs/DECISIONS.md` 대비 누락/불일치 확인
4. **결과 리포트**: 테이블 형식으로 PASS/FAIL 정리

## Key Paths
- EP 문서: `docs/execution_packets/EXEC-P0-*.md`
- 마이그레이션: `supabase/migrations/`
- 스키마 SSOT: `docs/DATA-MODEL.md`
- 결정 SSOT: `docs/DECISIONS.md`
- CI 스크립트: `scripts/`

## Conventions
- 언어: 한국어 (사용자 선호)
- Max 구독 사용 중 (비용 걱정 불필요)
- 브랜치 네이밍: `chore/p0-03a-core-schema-1` 패턴
