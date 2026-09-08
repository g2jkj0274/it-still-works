class_name HarvestRules
extends RefCounted

## 채집·배치 목표 판정 (M1-7a, 헌법 P2·P3·P7).
##
## 전부 정수 연산이고 상태를 바꾸지 않는다. 채집·배치 명령(M1-7b)이 이 판정을 받아 청크에
## 적용한다. 여기에는 쓰기 경로가 없다.
##
## 목표는 발 칸의 facing 이웃, 같은 층이다. 발 칸과 그 아래 층은 정의상 목표가 못 된다
## (목표 ≠ feet). 8방향 전부, 대각선도 허용 — 이동의 모서리 규칙은 몸이 지나는 문제라
## 채집에는 없다.
##
## 블록은 속성으로만 본다(P2). 부술 수 있는지는 `registry.is_breakable(id)`(내구도 > 0) 하나로
## 묻는다. 채집·배치 판정은 `solid` 를 절대 보지 않는다 — 단단함과 부술 수 있음은 다른 속성이다
## (DECISIONS 2026-09-06 이 legacy 의 실수로 지목한 지점). 테스트가 grep 으로 지킨다.
##
## 언로드된 청크의 시뮬레이션은 멈춘다(P7). 안 로드된 칸은 부술 수도 놓을 수도 없다.
## `ChunkWorld.get_id_at` 은 안 로드된 칸에 0 을 돌려주므로 모든 판정은 로드 검사를 먼저 둔다.
##
## 이 파일에는 씬 노드·부동소수·난수·파일 IO 가 없다.

## 한 번 때릴 때 깎이는 내구도.
const HIT_POWER := 1


## 채집·배치 목표 칸 = 발 칸 + facing. 같은 층.
static func target_of(feet: Vector2i, facing: Vector2i) -> Vector2i:
    return feet + facing


## 그 칸을 부술 수 있는가. 로드되어 있고 블록이 breakable(내구도 > 0) 이어야 한다.
static func can_harvest(chunks: ChunkWorld, registry: BlockRegistry, wx: int, wy: int, layer: int) -> bool:
    if not chunks.is_loaded(ChunkWorld.chunk_of(wx), ChunkWorld.chunk_of(wy)):
        return false
    return registry.is_breakable(chunks.get_id_at(wx, wy, layer))


## 그 칸이 비어 있는가(놓을 수 있는가). 로드되어 있고 블록이 없어야 한다.
##
## id 0 = 블록 없음, DECISIONS 2026-09-06 (a) 의 구조 규약이지 블록 정체 분기가 아니다.
## 로드 검사가 먼저다 — get_id_at 은 언로드 칸에 0 을 돌려주므로 순서를 바꾸면 언로드 경계
## 너머가 전부 빈 칸이 된다. 이 비교는 이 함수 한 곳에만 둔다.
static func is_empty_at(chunks: ChunkWorld, wx: int, wy: int, layer: int) -> bool:
    if not chunks.is_loaded(ChunkWorld.chunk_of(wx), ChunkWorld.chunk_of(wy)):
        return false
    return chunks.get_id_at(wx, wy, layer) == 0


## 한 번 때린 뒤 남는 내구도. 0 아래로 내려가지 않는다.
static func remaining_after_hit(current: int) -> int:
    return maxi(current - HIT_POWER, 0)
