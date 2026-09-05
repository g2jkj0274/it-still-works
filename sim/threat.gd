class_name Threat
extends RefCounted

## 밤에만 나타나는 적대 개체.
##
## 가장 가까운 목표로 곧장 다가가 닿으면 피해를 준다. 그 이상은 하지 않는다.
## 판단은 전부 정수이고 난수를 쓰지 않으므로 언제 돌려도 같게 움직인다.

const HEIGHT := 2

## 이 틱마다 한 칸 옮긴다. 사람보다 느려야 도망칠 수 있다.
const STEP_TICKS := 12

## 닿았을 때 주는 피해와 그 사이 간격.
const TOUCH_DAMAGE := 2
const TOUCH_TICKS := Simulation.TICK_RATE

## 길이 막혔을 때 앞을 부수기까지 걸리는 틱.
const BREAK_TICKS := 3 * Simulation.TICK_RATE

## 태어난 차례. 순회 순서를 고정하는 데 쓴다.
var id: int = 0
var position: Vector3i = Vector3i.ZERO

var _step_countdown: int = STEP_TICKS
var _touch_countdown: int = 0
var _break_countdown: int = BREAK_TICKS


static func create(p_id: int, at: Vector3i) -> Threat:
    var threat := Threat.new()
    threat.id = p_id
    threat.position = at
    return threat


func to_hash_fields() -> Array:
    var key := "threat.%d" % id
    return [
        [key + ".x", position.x],
        [key + ".y", position.y],
        [key + ".z", position.z],
        [key + ".step", _step_countdown],
        [key + ".touch", _touch_countdown],
        [key + ".break", _break_countdown],
    ]


## 한 틱 움직인다.
func advance(state: WorldState) -> void:
    _stand(state)
    _touch_countdown = maxi(_touch_countdown - 1, 0)

    if _is_touching(state.character.cell()):
        _bite(state)
        return

    _step_countdown -= 1
    if _step_countdown > 0:
        return
    _step_countdown = STEP_TICKS
    _walk_towards(state)


func _bite(state: WorldState) -> void:
    if _touch_countdown > 0:
        return
    _touch_countdown = TOUCH_TICKS
    state.vitals.damage(TOUCH_DAMAGE)


## 목표와 맞닿아 있는가. 같은 칸이거나 바로 옆이면 닿은 것이다.
func _is_touching(target: Vector3i) -> bool:
    var offset := target - position
    return absi(offset.x) + absi(offset.y) + absi(offset.z) <= 1


## 발밑이 사라지면 내려앉는다. 사람과 같은 규칙이다.
##
## 이것이 없으면 단에서 내려온 위협이 그 높이로 허공에 뜬 채 맴돌고, 밑을
## 파낸 자리에서도 그대로 떠 있는다.
func _stand(state: WorldState) -> void:
    position = MovementRules.settle(state.grid, position)


## 목표 쪽으로 한 칸. 막히면 다른 축을 시도하고, 그래도 막히면 앞을 부순다.
func _walk_towards(state: WorldState) -> void:
    var offset := state.character.cell() - position
    for direction in _preferred_directions(offset):
        var destination := MovementRules.resolve_walk(state.grid, position, direction)
        if destination != position:
            # 위협은 칸을 즉시 건넌다. 건넌 자리가 허공이면 그 자리에서 내려앉는다.
            position = MovementRules.settle(state.grid, destination)
            _break_countdown = BREAK_TICKS
            return

    _gnaw(state, _preferred_directions(offset))


## 축 차이가 큰 쪽을 먼저 고른다. 같으면 x 를 먼저 본다. 차례가 고정되어야 한다.
func _preferred_directions(offset: Vector3i) -> Array[Vector3i]:
    var horizontal := Vector3i(signi(offset.x), 0, 0)
    var vertical := Vector3i(0, signi(offset.y), 0)

    var order: Array[Vector3i] = []
    if absi(offset.y) > absi(offset.x):
        order.append(vertical)
        order.append(horizontal)
    else:
        order.append(horizontal)
        order.append(vertical)

    var kept: Array[Vector3i] = []
    for direction in order:
        if direction != Vector3i.ZERO:
            kept.append(direction)
    return kept


## 앞을 가로막은 것을 갉는다. 섬의 바닥은 건드리지 못한다.
func _gnaw(state: WorldState, directions: Array[Vector3i]) -> void:
    _break_countdown -= 1
    if _break_countdown > 0:
        return
    _break_countdown = BREAK_TICKS

    for direction in directions:
        var blocking := position + direction
        if VoxelGrid.is_bedrock(blocking):
            continue
        if not state.grid.is_solid(blocking):
            continue
        state.grid.set_block(blocking, BlockType.EMPTY)
        state.circuit.remove_part(blocking)
        return
