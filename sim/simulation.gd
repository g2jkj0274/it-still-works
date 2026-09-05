class_name Simulation
extends RefCounted

## 고정 틱 시뮬레이션의 진입점.
##
## 상태 변경은 오직 [method step] 안에서, 명령을 적용할 때만 일어난다.
## 바깥에서 [member state] 를 직접 고치면 결정론이 깨진다. 표현 레이어는 읽기만 한다.
##
## 이 클래스는 노드 트리와 렌더링을 모른다. 헤드리스로 단독 실행된다.
## 실시간을 틱으로 바꾸는 일은 [TickDriver] 가 맡는다.

## 초당 틱 수. 렌더 프레임률과 무관하다.
const TICK_RATE := 20

## 틱 하나의 길이(마이크로초). 시뮬레이션 안에 실수를 들이지 않으려고 정수로 둔다.
const TICK_INTERVAL_USEC := 1_000_000 / TICK_RATE

## 시뮬레이션이 소유한 월드 상태. 읽기 전용으로 다룬다.
var state: WorldState

## 아직 소비되지 않은 명령들.
var queue: SimCommandQueue

## 접수한 명령을 펼친 그대로 적어 둔다.
##
## **저장은 이 기록을 옮겨 적는 일이다.** 상태를 통째로 뜨지 않는다. 같은 시드에
## 같은 명령을 같은 차례로 넣으면 같은 상태가 나온다는 것이 이 게임의 뿌리
## 규칙이고(스펙 §2), 그 규칙이 곧 저장 형식이 된다. 스냅숏은 필드 하나만
## 빠뜨려도 조용히 어긋나지만 이쪽은 규칙이 깨지면 회귀 테스트가 먼저 운다.
##
## 대가는 불러오는 데 걸리는 시간이다. 재어 보면 30분 분량이 281ms 다.
var _log: Array = []


func _init(p_seed: int = 0) -> void:
    state = WorldState.new(SimRng.new(p_seed))
    queue = SimCommandQueue.new()


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
## 이 틱까지 밀린 명령을 정해진 순서대로 적용한 뒤 틱을 하나 올린다.
## 렌더 프레임과 무관하게 항상 같은 폭으로 나아간다.
func step() -> void:
    for command in queue.take_due(state.tick):
        command.apply(state)
    state.crops.advance()
    state.circuit.tick(state)
    _turn_of_day()
    state.threats.advance(state)
    state.vitals.tick()
    _revive_if_fallen()
    _settle_character()
    state.tick += 1


## 밤이 되면 위협이 나오고 날이 밝으면 사라진다.
func _turn_of_day() -> void:
    if DayCycle.is_nightfall(state.tick):
        state.threats.spawn_night(state)
    elif DayCycle.is_daybreak(state.tick):
        state.threats.clear()


## 쓰러지면 시작 자리에서 다시 일어난다.
##
## 인벤토리의 절반을 떨어뜨린다. 실패는 가벼워야 하지만 공짜여서는 안 된다.
## 만든 것은 그대로 남는다.
func _revive_if_fallen() -> void:
    if not state.vitals.is_dead():
        return

    state.inventory.drop_half()
    state.vitals.revive()
    state.character.place_at(state.spawn)


## 걷는 중이면 한 틱만큼 나아가고, 멈춰 있는데 발밑이 비었으면 한 칸 떨어진다.
##
## 입력에서 온 변경이 아니라 월드가 스스로 지키는 규칙이므로 명령을 거치지 않는다.
## 한 칸씩 떨어뜨리는 이유는 떨어지는 도중에 지형이 바뀌어도 어긋나지 않게 하려는 것이다.
func _settle_character() -> void:
    var character := state.character
    if character.is_moving():
        character.advance()
        return

    var here := character.cell()
    if not MovementRules.is_falling(state.grid, here):
        return
    character.walk_to(here - VoxelGrid.UP)


## [param ticks] 만큼 진행한다. 0 이하면 아무 일도 하지 않는다.
func advance(ticks: int) -> void:
    for i in maxi(ticks, 0):
        step()


## 현재 월드 상태의 다이제스트. 결정론 회귀 테스트가 비교하는 값이다.
func state_hash() -> String:
    return state.compute_hash()
