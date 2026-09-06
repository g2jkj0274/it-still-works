class_name Simulation
extends RefCounted

## 고정 틱 시뮬레이션의 진입점.
##
## 상태 변경은 오직 [method step] 안에서, 명령을 적용할 때만 일어난다.
## 바깥에서 [member state] 를 직접 고치면 결정론이 깨진다. 표현 레이어는 읽기만 한다.
##
## 이 클래스는 노드 트리와 렌더링을 모른다. 헤드리스로 단독 실행된다.
## 실시간을 틱으로 바꾸는 일은 [TickDriver] 가 맡는다.
##
## 틱 안의 갱신 순서는 `docs/SIM_ORDER.md` 가 문서다. 순서를 바꾸면 그 문서와
## `docs/DECISIONS.md` 를 함께 고친다.

## 초당 틱 수. 렌더 프레임률과 무관하다.
const TICK_RATE := 20

## 틱 하나의 길이(마이크로초). 시뮬레이션 안에 실수를 들이지 않으려고 정수로 둔다.
const TICK_INTERVAL_USEC := 1_000_000 / TICK_RATE

## 시뮬레이션이 소유한 월드 상태. 읽기 전용으로 다룬다.
var state: WorldState

## 블록 속성 표. 읽기 전용으로 다룬다 — view 가 팔레트 매핑(name_of)에 쓴다.
var registry: BlockRegistry

## 지형 생성 규칙 표. 읽기 전용으로 다룬다.
var terrain: TerrainTable

## 아직 소비되지 않은 명령들.
var queue: SimCommandQueue

## 접수한 명령을 펼친 그대로 적어 둔다.
##
## **저장은 이 기록을 옮겨 적는 일이다.** 상태를 통째로 뜨지 않는다. 같은 시드에
## 같은 명령을 같은 차례로 넣으면 같은 상태가 나온다는 것이 이 게임의 뿌리
## 규칙이고, 그 규칙이 곧 저장 형식이 된다. 스냅숏은 필드 하나만
## 빠뜨려도 조용히 어긋나지만 이쪽은 규칙이 깨지면 회귀 테스트가 먼저 운다.
var _log: Array = []


## 시드와 규칙 표 둘로 청크 월드를 가진 세계를 만든다. 셋 다 필수.
## 바깥에서는 [method create] 나 [method create_default] 를 쓴다 — null 검사가 거기 있다.
func _init(p_seed: int, p_registry: BlockRegistry, p_terrain: TerrainTable) -> void:
    registry = p_registry
    terrain = p_terrain
    var generator := ChunkGenerator.new(p_seed, p_registry, p_terrain)
    var chunk_world := ChunkWorld.new(generator)
    state = WorldState.new(SimRng.new(p_seed), chunk_world)
    queue = SimCommandQueue.new()


## 규칙 표를 받아 시뮬레이션을 만든다. [param p_registry] 나 [param p_terrain] 이 null 이면 null.
static func create(p_seed: int, p_registry: BlockRegistry, p_terrain: TerrainTable) -> Simulation:
    if p_registry == null or p_terrain == null:
        return null
    return Simulation.new(p_seed, p_registry, p_terrain)


## `data/blocks.json`·`data/terrain.json` 을 읽어 시뮬레이션을 만든다. 어느 하나라도 못 읽으면 null.
## 데이터 표를 못 읽으면 시뮬레이션은 만들어지지 않는다 — 같은 명령 로그가 파일 유무로 다른
## 해시를 내는 것을 막는다(P3). 빈 세계 fallback 은 없다.
static func create_default(p_seed: int) -> Simulation:
    var default_registry := BlockRegistry.load_default()
    if default_registry == null:
        return null
    var default_terrain := TerrainTable.load_default(default_registry)
    if default_terrain == null:
        return null
    return create(p_seed, default_registry, default_terrain)


## 다음에 실행할 틱 번호.
func current_tick() -> int:
    return state.tick


## 다음 틱에 실행되도록 접수한다.
func submit(command: SimCommand) -> SimCommand:
    return _record(queue.submit(command, state.tick))


## 지정한 틱에 실행되도록 접수한다. 이미 지나간 틱이면 다음 틱에 실행된다.
func submit_at(command: SimCommand, at_tick: int) -> SimCommand:
    return _record(queue.submit(command, at_tick))


## 지금까지 접수한 명령을 펼친 그대로. 적은 차례가 곧 접수한 차례다.
func command_log() -> Array:
    return _log.duplicate(true)


func command_count() -> int:
    return _log.size()


## 큐가 틱을 새긴 뒤에 적는다. 적힌 틱이 곧 실행될 틱이어야 다시 틀 때 맞는다.
func _record(command: SimCommand) -> SimCommand:
    if command != null:
        _log.append(command.to_dict())
    return command


## 한 틱 진행한다.
##
## 1. 이 틱까지 밀린 명령을 (실행 틱, 접수 순서) 차례로 적용한다.
##    - 로드 중심 동기화([method _sync_load_center]).
## 2. 틱을 하나 올린다.
##
## 서브시스템 갱신은 1 과 2 사이에 들어간다(`docs/SIM_ORDER.md`).
## 렌더 프레임과 무관하게 항상 같은 폭으로 나아간다.
func step() -> void:
    for command in queue.take_due(state.tick):
        command.apply(state)
    _sync_load_center()
    state.tick += 1


## 상태의 로드 중심 목표를 청크 월드에 반영한다.
## 제품 코드(sim/·view/)에서 set_center 의 유일한 호출 지점. 같은 틱의 명령은 동기화 전(이전 중심)의
## 로드 집합을 본다 — 새 중심으로 로드된 청크는 다음 틱 명령부터 접근된다.
func _sync_load_center() -> void:
    if not state.has_load_center:
        return
    if not state.chunks.has_center() or state.chunks.center() != state.load_center:
        state.chunks.set_center(state.load_center.x, state.load_center.y)


## [param ticks] 만큼 진행한다. 0 이하면 아무 일도 하지 않는다.
func advance(ticks: int) -> void:
    for i in maxi(ticks, 0):
        step()


## 현재 월드 상태의 다이제스트. 결정론 회귀 테스트가 비교하는 값이다.
func state_hash() -> String:
    return state.compute_hash()
