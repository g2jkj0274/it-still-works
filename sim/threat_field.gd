class_name ThreatField
extends RefCounted

## 지금 섬에 나와 있는 위협들.
##
## 밤이 되면 나타나고 날이 밝으면 사라진다. 태어난 차례대로만 순회한다.
## 나타나는 자리는 시드 고정 난수로 고른다. 전역 난수를 쓰지 않는다.

## 하룻밤에 나오는 수.
const NIGHTLY_COUNT := 4

## 사람에게서 이만큼 떨어진 띠 안에서 나타난다.
##
## 예전에는 아래쪽 한계만 있었고 그것이 12 였다. 기본 시야가 열다섯 칸
## 남짓이라 밤이 시작되는 순간 넷이 전부 화면 밖이거나 가장자리에 있었고,
## 사람보다 느려서(0.6초에 한 칸) 다가오는 데 다시 일곱 초가 걸렸다.
## **밤이 아무 일도 없는 삼 분으로 시작해서, 아무 예고 없이 등 뒤에서 물리는
## 것으로 끝났다.**
##
## 멀리서 다가오는 것을 몇 초 보는 것이 밤의 긴장 전부다. 낮에 만든 장치가
## 밤에 시험받는다는 계약(스펙 §3.2)도 그때 전달된다.
##
## 아래쪽 한계가 있는 이유는 그대로다. 나오자마자 붙으면 피할 틈이 없다.
const MIN_CLEARANCE := 8
const MAX_CLEARANCE := 14

## 자리를 고르다 이만큼 실패하면 그 밤은 그만큼만 나온다.
const SPAWN_ATTEMPTS := 40

## 설 자리를 못 찾았음을 뜻하는 값. 격자 안에 있을 수 없는 칸이다.
const NO_SPOT := Vector3i(-1, -1, -1)

var _threats: Array[Threat] = []
var _next_id: int = 0


func count() -> int:
    return _threats.size()


func threats() -> Array[Threat]:
    return _threats.duplicate()


func clear() -> void:
    _threats.clear()


## 밤이 되면 부른다. 자리를 골라 위협을 내놓는다.
func spawn_night(state: WorldState) -> void:
    for i in NIGHTLY_COUNT:
        var at := _find_spot(state)
        if at == NO_SPOT:
            continue
        _threats.append(Threat.create(_next_id, at))
        _next_id += 1


## 한 틱 진행한다. 태어난 차례대로만 움직인다.
func advance(state: WorldState) -> void:
    for threat in _threats:
        threat.advance(state)


func to_hash_fields() -> Array:
    var fields: Array = [["threats.count", _threats.size()], ["threats.next_id", _next_id]]
    for threat in _threats:
        fields.append_array(threat.to_hash_fields())
    return fields


## 설 만한 자리를 찾는다. 못 찾으면 [constant NO_SPOT].
func _find_spot(state: WorldState) -> Vector3i:
    var here := state.character.cell()
    for attempt in SPAWN_ATTEMPTS:
        var x := state.rng.next_range(0, VoxelGrid.SIZE_X - 1)
        var y := state.rng.next_range(0, VoxelGrid.SIZE_Y - 1)

        var offset := Vector2i(x - here.x, y - here.y)
        var squared := offset.x * offset.x + offset.y * offset.y
        if squared < MIN_CLEARANCE * MIN_CLEARANCE:
            continue
        if squared > MAX_CLEARANCE * MAX_CLEARANCE:
            continue

        var found := _ground_above(state, x, y)
        if found != NO_SPOT:
            return found
    return NO_SPOT


## 그 기둥에서 설 수 있는 가장 낮은 칸. 없으면 [constant NO_SPOT].
func _ground_above(state: WorldState, x: int, y: int) -> Vector3i:
    for z in range(1, VoxelGrid.SIZE_Z - Threat.HEIGHT):
        var cell := Vector3i(x, y, z)
        if not state.grid.is_solid(cell - VoxelGrid.UP):
            continue
        if MovementRules.can_occupy(state.grid, cell):
            return cell
    return NO_SPOT
