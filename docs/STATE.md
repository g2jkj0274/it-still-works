# STATE
마일스톤: M1 (M0 완료 — 빈 세계 2000틱 결정론 통과, 2026-09-06)
진행 중: M1-3 시드 기반 청크 절차 생성 (architect 검토 예정)
마지막 통과 테스트: 153/153 (tools/test.sh, 약 33초)
마지막 결정론 테스트: 통과 — 163d462bb8385e534447c4ce97b5c872fad72ddf80a667cec1be69cd6bab4e02 (별도 프로세스 4회 일치)
이터레이션 수: 5 (10마다 architect 전체 감사 — 다음 감사는 10)

## M1 태스크 (LOOP.md M1)
- [x] M1-1 블록 속성 시스템(P2) + `data/blocks.json` + `sim/block_registry.gd` (2026-09-07, 26 테스트. view 는 M1-5 에서 붙음)
- [x] M1-2 청크 자료구조 `sim/chunk.gd`(16×16×3, 바이트 둘, dirty, digest) (2026-09-07, 27 테스트. 1000청크 채우기+digest 약 0.92ms/청크)
- [ ] M1-3 시드 기반 청크 절차 생성
- [ ] M1-4 청크 월드: 로드 반경 상수, 로드/언로드, 청크 간 조회
- [ ] M1-5 아이소메트릭 렌더(플레이스홀더 색), 층 전환
- [ ] M1-6 플레이어 이동(명령 경유, 서브유닛 정수 — legacy character_state 참고)
- [ ] M1-7 채집·배치 명령, 인벤토리
- [ ] M1-8 기초 크래프팅(부품만 — M1 은 레시피 0개, 틀만)
- [ ] M1-9 연구대 부품 + 연구 트리 UI 골격(빈 트리)
- [ ] M1-10 저장/불러오기(시드+명령 로그 + 언로드 청크 스냅샷) — legacy save_slot 참고
- [ ] M1 완료 조건: 걸어서 새 청크 생성 → 저장 → 종료 → 로드 → 동일 상태 테스트

## 남긴 태스크 (builder 보고)
- [x] legacy/ 중첩 평평하게 (legacy/view/view, legacy/test/integration/integration) — 이번 커밋에서 정리
- [x] docs/TESTING.md 갱신 (--import 절차, 98 케이스)
- [x] DECISIONS.md 에 .gdignore 확인 결과
- [ ] tools/perf.sh — M3 에서 부품이 생기면
- [ ] M1-7 채집 규칙(architect, M1-2 검토): breakable 블록(레지스트리 max>0)의 현재 내구도 0 은 저장 상태로 존재할 수 없다. 0 에 도달한 틱 안에서 air 로 바꾼다. Chunk 는 레지스트리를 모르므로 이 규칙은 채집·몹 파괴 명령 쪽이 지킨다.

비고:
- 이 세션 첫 감사는 general-purpose 에이전트에 architect 지시문을 넘겨 돌렸다(에이전트 정의가 세션 시작 뒤 생김). 이후는 architect/builder/tester 타입 사용.
