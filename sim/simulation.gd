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


func _init(p_seed: int = 0) -> void:
    state = WorldState.new(SimRng.new(p_seed))
    queue = SimCommandQueue.new()


## 다음에 실행할 틱 번호.
func current_tick() -> int:
    return state.tick


## 다음 틱에 실행되도록 접수한다.
func submit(command: SimCommand) -> SimCommand:
    return queue.submit(command, state.tick)


## 지정한 틱에 실행되도록 접수한다. 이미 지나간 틱이면 다음 틱에 실행된다.
func submit_at(command: SimCommand, at_tick: int) -> SimCommand:
    return queue.submit(command, at_tick)


## 한 틱 진행한다.
##
## 이 틱까지 밀린 명령을 정해진 순서대로 적용한 뒤 틱을 하나 올린다.
## 렌더 프레임과 무관하게 항상 같은 폭으로 나아간다.
func step() -> void:
    for command in queue.take_due(state.tick):
        command.apply(state)
    _settle_character()
    state.tick += 1


## 발밑 블록이 사라졌을 때 캐릭터가 공중에 남지 않게 한다.
##
## 입력에서 온 변경이 아니라 월드가 스스로 지키는 규칙이므로 명령을 거치지 않는다.
func _settle_character() -> void:
    state.character.position = MovementRules.settle(state.grid, state.character.position)


## [param ticks] 만큼 진행한다. 0 이하면 아무 일도 하지 않는다.
func advance(ticks: int) -> void:
    for i in maxi(ticks, 0):
        step()


## 현재 월드 상태의 다이제스트. 결정론 회귀 테스트가 비교하는 값이다.
func state_hash() -> String:
    return state.compute_hash()
