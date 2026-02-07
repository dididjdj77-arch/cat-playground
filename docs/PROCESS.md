# PROCESS — 프로세스/워크플로우 SSOT

> 이 문서는 EP(Execution Packet) 운영, 문서 관리, PR 규칙, 리스크 판정, 역할 분업의 단일 원문입니다.
> 정책/설계 결정은 DECISIONS.md, 운영 수치는 CONFIG-BASELINES.md를 참조.

---

## 1. SSOT 운영 방식 (from D-011)

### 문서 체계
- SSOT: CONTEXT / INDEX / DECISIONS / OPEN (+ ADR/* 필요 시)
- Work unit: EP-ID + PR (Execution Packet 기반). TODO 문서는 사용하지 않는다.

### 회차 종료 체크(3줄)
1. DECISIONS: 신규 D-### 추가/정정 반영 여부
2. OPEN: 상태 갱신(Resolved → D-### 링크) 반영 여부
3. PR: EP-ID ↔ PR 링크(또는 PR 본문 Result Packet) 기록 여부

---

## 2. SSOT 문서 자동 PR 규칙 (from D-027)

- SSOT 문서 변경은 D-### 결정 키를 기준으로 수행한다(헤딩 전체 텍스트 일치에 의존하지 않는다).
- 동일 요청을 여러 번 실행해도 동일 PR을 반환해야 한다(멱등성).
- GitHub Contents API는 대상 브랜치의 최신 sha 기준으로 처리한다.
- sha mismatch(409) 발생 시 최신 sha 재조회 후 1회 재시도한다.

---

## 3. DECISIONS 운영 규칙 (from D-034)

- D-### 번호는 "영구 할당"이며 재사용 금지.
- 기존 D-###의 "내용 수정"을 허용한다(오타/명확화/정정/정보 업데이트 포함).
- 삭제는 금지한다(참조 안정성). 필요 시 해당 D 항목 상단에 Status를 표시한다:
  - Status: active | superseded | MOVED
  - See: ADR-### 또는 관련 D-### 링크
- 근본적 방향 전환(정책/권한/아키텍처 패턴 변경)은 ADR로 근거를 남긴다.
- Git commit 메시지에 변경 이유(Reason)를 남긴다(문서는 현재 상태 우선, 이력은 Git이 관리).

---

## 4. Execution/Result Packet 운영 (from D-047)

### 원칙
- 모든 구현 작업은 Execution Packet(EP) 단위로 진행한다.
- 각 티켓은 Execution Packet(EP)으로 지시하며, EP는 `docs/PACKET-TEMPLATES.md` 형식을 따른다.
- 결과 제출은 PR 1개로 하며, PR 본문은 Result Packet 형식을 채운다.
- PR 생성 시 기본 본문은 `.github/pull_request_template.md`를 따른다.
- EP에는 최소한 Allowed changes / Validation / DoD / Evidence required를 포함한다.
- Result Packet에 Evidence(실행한 명령/SQL + 출력)가 없으면 "미검증"으로 간주하고 리뷰를 중단한다(불합격).

---

## 5. EP-ID 관리 (from D-048)

- EP 식별자는 EP-ID를 SSOT로 사용한다(예: EP-YYYYMMDD-<slug>).
- Execution Packet ID는 `EP-<EP-ID>`로 표기한다.
- PR 제목과 본문(Result Packet)에는 EP-ID를 반드시 포함한다.
- Result Packet은 `EP-ID`로 추적하며, 별도 "Result 번호"는 두지 않는다.
- (선택) GitHub Issue를 쓰는 경우, Issue 번호는 참고 링크로만 둔다(SSOT는 EP-ID 유지).

---

## 6. 고위험 판정 원칙 (from D-032)

고위험은 키워드가 아니라 영향도(Blast radius)와 롤백 가능성으로 판단한다. 아래 6문항 중 하나라도 "예/의심"이면 PRECISE 우선:

1. 롤백 난이도(되돌리기 비용/다운타임/복구 난이도)
2. 데이터 유실/오염 가능성(대량 UPDATE/DELETE/정합성 훼손)
3. 공개/비공개 경계 변화(anon 접근, SEO 노출, 공개 URL/스토리지)
4. 권한/정책 변화(RLS, SECURITY DEFINER RPC, 우회 가능성)
5. 스키마/마이그레이션 성격(컬럼/인덱스/제약/키 변경, 백필성 작업 포함)
6. 외부/클라이언트 영향(API 계약, 앱/웹 동시 영향, 캐시/검색 영향)

PRECISE는 최소 안전장치(DoD/검증/롤백)를 반드시 포함한다. FAST도 PR/스모크/체크리스트로 되돌리기 가능성을 확보한다.

---

## 7. 컨트롤/데이터 플레인 분업 (from D-033)

**컨트롤 플레인** (사용자 + 어시스턴트):
- 설계·검증·판단: SSOT/LOCK/OPEN/ADR 기준
- 최종 리뷰·승인: PR diff/테스트 검토 → 승인/수정지시
- 충돌 처리: 자동 결론 금지, 차이/영향 정리 → 질문

**데이터 플레인** (omoc/Claude Code 등):
- 구현 실행: 컨트롤 플레인이 정한 스코프/DoD 범위 내에서만
- 산출: PR + CI/테스트 결과
- 불확실시: 임의 결론 대신 질문으로 멈춤

---

## History

### 해소된 충돌 (DECISIONS에서 이관)
- 채널 v1 범위: "답글/좋아요/검색까지 포함" 사용자 확정 발언으로 D-013 고정.
- 닉네임 이동 UX: "바로 페이지 이동 아님, 메뉴로" 사용자 확정 발언으로 D-017 고정.