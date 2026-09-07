class_name MovementRules
extends RefCounted

## 격자 위 이동 판정 (M1-6a, 헌법 P2·P3·P7).
##
## 전부 정수 연산이고 상태를 바꾸지 않는다. 실제 이동은 명령이 이 판정 결과를 받아
## [PlayerState.walk_to] 로 적용한다.
##
## 블록은 속성으로만 본다(P2): `registry.has_at(id, BlockRegistry.ATTR_SOLID)`. 블록 타입·이름
## 분기는 없다. 층 인덱스 분기(`layer == Chunk.LAYER_UNDER`)는 블록이 아니라 세계 구조의 규칙이다.
##
## 세계는 층 3개의 2D 격자다(DECISIONS 2026-09-06). 바닥 = 아래 층의 solid 칸. 지하층 아래는
## 암묵 기반암. 층 이동·낙하는 M3 gravity 규칙과 함께 온다 — M1 에서는 바닥 없는 칸으로는 아예
## 나가지 않는다.
##
## 언로드된 청크의 시뮬레이션은 멈춘다(P7). 안 로드된 칸은 지나갈 수도 딛을 수도 없다.
## `ChunkWorld.get_id_at` 은 안 로드된 칸에 0(air)을 돌려주므로 반드시 로드 검사를 먼저 둔다 —
## 안 그러면 언로드 경계 너머가 전부 뚫린 허공으로 보인다.
##
## 이 파일에는 Node·부동소수·난수·파일 IO 가 없다.

## 걸을 수 있는 여덟 방향. 순서 고정 — 판정과 열거가 항상 같은 차례여야 한다(P3).
##
## 대각선이 있어야 화면의 위아래좌우와 맞는다. 아이소메트릭에서는 격자 축이 비스듬히 놓여
## 네 방향만으로는 어느 키도 화면과 나란해지지 않는다 — 화면 축이 격자의 대각선이다.
const DIRECTIONS: Array[Vector2i] = [
    Vector2i(0, -1),
    Vector2i(0, 1),
    Vector2i(1, 0),
    Vector2i(-1, 0),
    Vector2i(1, -1),
    Vector2i(-1, -1),
    Vector2i(1, 1),
    Vector2i(-1, 1),
]


static func is_direction(dir: Vector2i) -> bool:
    return DIRECTIONS.has(dir)


## 두 축을 한꺼번에 건너는 걸음인가.
static func is_diagonal(dir: Vector2i) -> bool:
    return dir.x != 0 and dir.y != 0


## 그 칸에 몸이 들어가는가. 청크가 로드되어 있고 블록이 solid 가 아니어야 한다.
static func is_passable(chunks: ChunkWorld, registry: BlockRegistry, wx: int, wy: int, layer: int) -> bool:
    if not chunks.is_loaded(ChunkWorld.chunk_of(wx), ChunkWorld.chunk_of(wy)):
        return false
    return not registry.has_at(chunks.get_id_at(wx, wy, layer), BlockRegistry.ATTR_SOLID)


## 발밑이 단단한가. 지하층은 암묵 기반암 위라 항상 그렇다. 그 밖의 층은 아래 층 같은 칸이
## 로드되어 있고 solid 여야 한다.
static func is_supported(chunks: ChunkWorld, registry: BlockRegistry, wx: int, wy: int, layer: int) -> bool:
    if layer == Chunk.LAYER_UNDER:
        return true
    if not chunks.is_loaded(ChunkWorld.chunk_of(wx), ChunkWorld.chunk_of(wy)):
        return false
    return registry.has_at(chunks.get_id_at(wx, wy, layer - 1), BlockRegistry.ATTR_SOLID)


## 들어갈 수 있고 딛을 것도 있는가.
static func is_walkable(chunks: ChunkWorld, registry: BlockRegistry, wx: int, wy: int, layer: int) -> bool:
    return is_passable(chunks, registry, wx, wy, layer) \
        and is_supported(chunks, registry, wx, wy, layer)


## 한 걸음 뒤에 도착할 칸. 갈 수 없으면 제자리([param feet])를 돌려준다.
##
## 출발 칸은 검사하지 않는다. solid 안에 서 있어도 air 이웃으로 걸어 나올 수 있다 —
## 스폰 칸이 solid 여도 갇히지 않게 하는 규칙이다.
##
## 대각선 걸음은 **양옆이 모두 열려 있어야 지나간다.** 한쪽이라도 solid 면 벽 모서리를 뚫고
## 지나가는 꼴이 된다. 이것은 화면에 어떻게 보이는지와 무관한 격자의 문제다 — 시점을 돌려도
## 대각선은 대각선이다. 양옆은 [method is_passable] 만 본다. 옆이 바닥 없는 구멍이어도 스치는
## 것은 된다 — 딛는 곳은 목적지뿐이다.
static func resolve_walk(chunks: ChunkWorld, registry: BlockRegistry, feet: Vector2i, layer: int, dir: Vector2i) -> Vector2i:
    if not is_direction(dir):
        return feet
    var destination := feet + dir
    if not is_walkable(chunks, registry, destination.x, destination.y, layer):
        return feet
    if is_diagonal(dir):
        if not is_passable(chunks, registry, feet.x + dir.x, feet.y, layer):
            return feet
        if not is_passable(chunks, registry, feet.x, feet.y + dir.y, layer):
            return feet
    return destination
