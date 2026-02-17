# PHASE-0.9.md
# Phase 0.9 — Auth 스파이크(Phase 0 ↔ Phase 1 브릿지)

## EP P0.9-01 — Expo 최소 앱: 로그인 → 세션 확인 → auth-only RPC 1회 호출
**Goal (1~3줄)**  
- OAuth/딥링크/세션 저장 리스크를 UI 최소로 조기 발견한다.  
- AS-1~AS-5(Auth Spike Gate) “통과 증거”를 남길 수 있는 골격을 만든다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed paths: `TBD: <expo-app-root>/**` + (필요 시) `docs/playbooks/ops-app-config.md`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Providers: Apple, Kakao 필수 / Google 옵션 / Email/password 복구 채널(정책 SSOT)  
- auth-only RPC: `rpc_get_app_config`(권장, SSOT 존재)  
- 외부 동작 변화: 없음(스파이크 전용)

**Validation placeholders**  
- Auth Spike Gate: AS-1~AS-5 (수동/증거, `docs/VERIFICATION.md`)  
- `repo:lint`, `repo:typecheck` (가능하면)

**Hardening hints**  
- [ ] iOS/Android 각각 1세트 증거(스크린샷/로그) 첨부 형식 고정  
- [ ] 로그인 취소/실패/네트워크 오류 케이스 최소 1개 기록  
- [ ] 롤백: 스파이크 UI/코드 제거 가능(본체와 분리 유지)

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/DECISIONS.md`, `roadmap.md`  
- D-066, D-056

**Prerequisites**: P0-03C, P0-06

**OPEN**  
- 실제 리다이렉트/딥링크 스킴 값(Env Matrix 근거 필요).

---

## EP P0.9-02 — 환경별 재현성 체크리스트 + Env Matrix 값 채우기(dev/staging/prod)
**Goal (1~3줄)**  
- dev/staging/prod에서 “로그인→세션 확인”이 재현 가능한 체크리스트/설정 기록으로 남는다.  
- Env Matrix placeholder를 실제 값/저장 위치로 채운다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed paths: `docs/playbooks/ops-app-config.md` + `TBD: env 관리 파일(레포 근거 필요)`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- 기록 필드(roadmap §1.4): Supabase ref/keys 저장 위치, OAuth redirect URI, Expo scheme, Next domain, revalidate secret 저장 위치 등

**Validation placeholders**  
- AS-5 체크리스트 완료(환경별 재현)  
- 문서 diff 리뷰(누락 필드 0)

**Hardening hints**  
- [ ] secret은 “값”이 아니라 “저장 위치/권한경계”만 기록(평문 금지)  
- [ ] staging 증거 첨부 규약 준수

**SSOT refs**  
- `docs/playbooks/ops-app-config.md`, `docs/VERIFICATION.md`, `roadmap.md`

**Prerequisites**: P0.9-01

**OPEN**: none

---

## Phase 0.9 요약
- EP 개수: 2  
- 단독 권장(고위험): P0.9-01  
- 번들 후보(가벼운 것끼리): P0.9-01+P0.9-02 (roadmap상 “0.9=1 EP”로 운영 시 번들링 가능)
