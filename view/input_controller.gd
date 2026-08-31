class_name InputController
extends Node

## 입력을 명령으로 바꾼다.
##
## 월드 상태를 직접 고치지 않는다. 명령을 만들어 큐에 넣을 뿐이고, 그 명령이
## 언제 반영될지는 시뮬레이션이 틱 단위로 정한다.
##
## 상태를 읽기는 한다. 어느 칸에 놓을지 정하려면 캐릭터가 어디를 보는지 알아야 한다.

## 이동 동작과 격자 방향. 딕셔너리가 아니라 순서 있는 배열이다.
## 두 방향이 동시에 눌렸을 때 어느 쪽이 이기는지가 실행마다 달라지면 안 된다.
const MOVE_ACTIONS: Array = [
    [&"move_north", Vector3i(0, -1, 0)],
    [&"move_south", Vector3i(0, 1, 0)],
    [&"move_east", Vector3i(1, 0, 0)],
    [&"move_west", Vector3i(-1, 0, 0)],
]

const ACTION_PLACE := &"place_block"
const ACTION_BREAK := &"break_block"

## 손에 쥘 수 있는 재료. 고를 수 있는 순서대로.
const PLACEABLE: Array[int] = [BlockType.GROUND, BlockType.STONE, BlockType.WOOD]
const SELECT_ACTIONS: Array = [&"select_1", &"select_2", &"select_3"]

## 키를 누르고 있을 때 한 걸음마다 두는 간격(틱).
const REPEAT_TICKS := 4

var _simulation: Simulation
var _selected: int = BlockType.WOOD
var _next_move_tick: int = 0


func bind(simulation: Simulation) -> void:
    _simulation = simulation


static func direction_for_action(action: StringName) -> Vector3i:
    for entry: Array in MOVE_ACTIONS:
        if entry[0] == action:
            return entry[1]
    return Vector3i.ZERO


func selected_block() -> int:
    return _selected


func select_block(block_type: int) -> void:
    if not PLACEABLE.has(block_type):
        return
    _selected = block_type


func submit_move(direction: Vector3i) -> void:
    if _simulation == null:
        return
    _simulation.submit(MoveCharacterCommand.create(direction))


func submit_place() -> void:
    if _simulation == null:
        return
    _simulation.submit(PlaceBlockCommand.create(_target_cell(), _selected))


func submit_break() -> void:
    if _simulation == null:
        return
    _simulation.submit(BreakBlockCommand.create(_target_cell()))


## 눌린 키를 읽어 명령을 만든다. 표현 레이어의 프레임 루프에서 부른다.
func poll(current_tick: int) -> void:
    if _simulation == null:
        return
    _poll_selection()
    _poll_movement(current_tick)
    _poll_blocks()


## 키 배치를 InputMap 에 등록한다. 이미 있으면 손대지 않는다.
static func install_actions() -> void:
    _install(&"move_north", [KEY_W, KEY_UP])
    _install(&"move_south", [KEY_S, KEY_DOWN])
    _install(&"move_east", [KEY_D, KEY_RIGHT])
    _install(&"move_west", [KEY_A, KEY_LEFT])
    _install(ACTION_PLACE, [KEY_E])
    _install(ACTION_BREAK, [KEY_Q])
    _install(&"select_1", [KEY_1])
    _install(&"select_2", [KEY_2])
    _install(&"select_3", [KEY_3])


static func _install(action: StringName, keys: Array) -> void:
    if InputMap.has_action(action):
        return
    InputMap.add_action(action)
    for key: Key in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action, event)


func _target_cell() -> Vector3i:
    return _simulation.state.character.facing_cell()


func _poll_movement(current_tick: int) -> void:
    if current_tick < _next_move_tick:
        return
    for entry: Array in MOVE_ACTIONS:
        if not Input.is_action_pressed(entry[0]):
            continue
        submit_move(entry[1])
        _next_move_tick = current_tick + REPEAT_TICKS
        return


func _poll_blocks() -> void:
    if Input.is_action_just_pressed(ACTION_PLACE):
        submit_place()
    if Input.is_action_just_pressed(ACTION_BREAK):
        submit_break()


func _poll_selection() -> void:
    for i in PLACEABLE.size():
        if Input.is_action_just_pressed(SELECT_ACTIONS[i]):
            select_block(PLACEABLE[i])
