class_name InputController
extends Node

## 입력을 명령으로 바꾼다.
##
## 월드 상태를 직접 고치지 않는다. 명령을 만들어 큐에 넣을 뿐이고, 그 명령이
## 언제 반영될지는 시뮬레이션이 틱 단위로 정한다.
##
## 상태를 읽기는 한다. 어느 칸에 놓을지 정하려면 캐릭터가 어디를 보는지 알아야 한다.
##
## 이동 키는 화면 기준이다. W 는 화면 위쪽이다. 두 키를 겹쳐 누르면 그 사이
## 쪽으로 가므로 여덟 쪽 모두 갈 수 있다. 화면과 격자 사이의 회전은
## ScreenDirections 가 카메라에서 뽑는다. 시점을 돌리면 조작도 따라 돈다.
##
## 묶기는 손이 여러 번 간다. V 로 칸을 고르고, B 로 값이 드나들 자리를 정하고,
## G 로 묶는다. 묶은 것은 N 으로 손에 쥔다. 고른 차례가 그대로 드나드는
## 차례가 되므로 고른 순서를 그대로 들고 있는다.

## 이동 동작과 화면 방향. 딕셔너리가 아니라 순서 있는 배열이다.
## 두 방향이 동시에 눌렸을 때 어느 쪽이 이기는지가 실행마다 달라지면 안 된다.
const MOVE_ACTIONS: Array = [
    [&"move_up", ScreenDirections.UP],
    [&"move_down", ScreenDirections.DOWN],
    [&"move_left", ScreenDirections.LEFT],
    [&"move_right", ScreenDirections.RIGHT],
]

## 카메라가 없을 때 쓸 자리. 헤드리스에서도 이동은 되어야 한다.
##
## 요 45도에서 실제로 나오는 배치와 같다. 화면 위아래좌우가 격자 대각선이고,
## 화면 대각선이 격자 축이다.
const FALLBACK_DIRECTIONS: Dictionary[Vector2i, Vector3i] = {
    ScreenDirections.UP: Vector3i(-1, -1, 0),
    ScreenDirections.DOWN: Vector3i(1, 1, 0),
    ScreenDirections.RIGHT: Vector3i(1, -1, 0),
    ScreenDirections.LEFT: Vector3i(-1, 1, 0),
    ScreenDirections.UP_RIGHT: Vector3i(0, -1, 0),
    ScreenDirections.UP_LEFT: Vector3i(-1, 0, 0),
    ScreenDirections.DOWN_RIGHT: Vector3i(1, 0, 0),
    ScreenDirections.DOWN_LEFT: Vector3i(0, 1, 0),
}

const ACTION_PLACE := &"place_block"
const ACTION_BREAK := &"break_block"
const ACTION_LINK := &"link_parts"
const ACTION_TARGET := &"cycle_target"
const ACTION_EAT := &"eat"
const ACTION_HELP := &"toggle_help"
const ACTION_ZOOM_IN := &"zoom_in"
const ACTION_ZOOM_OUT := &"zoom_out"
const ACTION_TURN_LEFT := &"turn_left"
const ACTION_TURN_RIGHT := &"turn_right"
const ACTION_CHOOSE := &"choose_for_bundle"
const ACTION_TERMINAL := &"cycle_terminal"
const ACTION_BUNDLE := &"make_bundle"
const ACTION_HOLD_BUNDLE := &"hold_bundle"
const ACTION_CRAFT := &"craft"
const ACTION_LAMP := &"hold_lamp"
const ACTION_SAVE := &"save_game"
const ACTION_LOAD := &"load_game"

## 손에 쥘 수 있는 것. 고를 수 있는 차례대로.
const PLACEABLE: Array[int] = [
    BlockType.GROUND,
    BlockType.ORE,
    BlockType.WOOD,
    BlockType.DOOR_CLOSED,
    BlockType.DETECTOR,
    BlockType.ACTUATOR,
    BlockType.REPEATER,
    BlockType.BOX,
    BlockType.BRANCH,
    BlockType.FIELD,
    BlockType.LAMP_DARK,
    BlockType.BUNDLE,
]

## 고른 칸이 묶음에서 맡을 몫.
const ROLE_PLAIN := 0
const ROLE_ENTRY := 1
const ROLE_EXIT := 2
const ROLE_COUNT := 3

## 설정을 고를 수 있는 부품들.
const PARTS_WITH_SETTINGS: Array[int] = [
    BlockType.DETECTOR, BlockType.REPEATER, BlockType.BOX, BlockType.BRANCH, BlockType.BUNDLE,
]

const SELECT_ACTIONS: Array = [
    &"select_1", &"select_2", &"select_3", &"select_4", &"select_5",
    &"select_6", &"select_7", &"select_8", &"select_9", &"select_0",
]

## 키를 누르고 있을 때 한 걸음마다 두는 간격(틱).
const REPEAT_TICKS := 4

## 되풀이를 놓을 때 고를 수 있는 설정들. [갈래, 횟수, 간격].
## 숫자를 자유롭게 넣을 화면이 아직 없어 미리 정해 둔 몇 가지로 돌린다.
const REPEATER_PRESETS: Array = [
    [RepeaterPart.MODE_COUNT, 3, 10],
    [RepeaterPart.MODE_COUNT, 10, 10],
    [RepeaterPart.MODE_WHILE, 0, 10],
    [RepeaterPart.MODE_FOREVER, 0, 10],
]

## 갈림길을 놓을 때 고를 수 있는 판정들. [판정 방식, 견줄 수].
const BRANCH_PRESETS: Array = [
    [BranchPart.MODE_TRUTH, 0],
    [BranchPart.MODE_GREATER_EQUAL, 1],
    [BranchPart.MODE_GREATER_EQUAL, 10],
    [BranchPart.MODE_LESS, 3],
    [BranchPart.MODE_AND, 0],
    [BranchPart.MODE_OR, 0],
]

signal help_toggled(shown: bool)

## 저장과 불러오기는 명령이 아니라 파일을 만지는 일이다. 입력은 알리기만 하고
## 실제로 하는 것은 게임 화면이 맡는다.
signal save_requested
signal load_requested

## 만들기를 접수했다. 소리를 낼 자리를 알리는 것뿐이고, 실제로 만들어졌는지는
## 시뮬레이션이 정한다.
signal crafted

var _simulation: Simulation
var _camera: Camera3D
var _selected: int = BlockType.WOOD
var _next_move_tick: int = 0
var _target: BlockTarget = null
var _detector_target: int = DetectorPart.TARGET_PLAYER
var _repeater_preset: int = 0
var _box_shape: int = BoxPart.SHAPE_SQUARE
var _branch_preset: int = 0
var _link_source: Vector3i = Vector3i.ZERO
var _has_link_source: bool = false
var _link_port: int = BranchPart.PORT_TRUE
var _help_shown: bool = false

## 묶으려고 고른 칸들. 고른 차례 그대로다.
var _chosen: Array[Vector3i] = []

## 고른 칸이 저마다 맡은 몫. [member _chosen] 과 나란히 간다.
var _roles: PackedInt32Array = PackedInt32Array()

## 지금 손에 쥔 묶음 번호. 아무것도 안 쥐었으면 -1.
var _held_bundle: int = -1


func bind(simulation: Simulation) -> void:
    _simulation = simulation


## 이동 방향을 뽑을 카메라. 없으면 고정 배치로 물러난다.
func bind_camera(camera: Camera3D) -> void:
    _camera = camera


static func screen_for_action(action: StringName) -> Vector2i:
    for entry: Array in MOVE_ACTIONS:
        if entry[0] == action:
            return entry[1]
    return Vector2i.ZERO


## 화면 방향에 해당하는 격자 방향.
func grid_for_screen(screen: Vector2i) -> Vector3i:
    if _camera != null:
        var direction := ScreenDirections.grid_for(_camera, screen)
        if direction != Vector3i.ZERO:
            return direction
    return FALLBACK_DIRECTIONS.get(screen, Vector3i.ZERO)


func selected_block() -> int:
    return _selected


func select_block(block_type: int) -> void:
    if not PLACEABLE.has(block_type):
        return
    _selected = block_type


## 감지기가 무엇을 볼지. 놓기 전에 고른다.
func detector_target() -> int:
    return _detector_target


func repeater_preset() -> int:
    return _repeater_preset


func box_shape() -> int:
    return _box_shape


func branch_preset() -> int:
    return _branch_preset


func help_shown() -> bool:
    return _help_shown


func toggle_help() -> void:
    _help_shown = not _help_shown
    help_toggled.emit(_help_shown)


## 갈림길에서 배선이 나갈 출구. 참 쪽이거나 거짓 쪽이다.
func link_port() -> int:
    return _link_port


## 화면에 보일 출구 이름.
func link_port_name() -> String:
    return "참" if _link_port == BranchPart.PORT_TRUE else "거짓"


func cycle_link_port() -> void:
    _link_port = BranchPart.PORT_FALSE if _link_port == BranchPart.PORT_TRUE else BranchPart.PORT_TRUE


## 지금 갈림길을 출발점으로 잡고 배선을 잇는 중인가.
##
## 이때는 T 가 설정이 아니라 출구를 바꾼다. 출구는 이을 때에만 뜻이 있다.
func wiring_from_branch() -> bool:
    if not _has_link_source or _simulation == null:
        return false
    var source := _simulation.state.circuit.part_at(_link_source)
    return source != null and source.kind() == BlockType.BRANCH


## 지금 고른 것의 설정을 다음 것으로 넘긴다.
func cycle_part_setting() -> void:
    if wiring_from_branch():
        cycle_link_port()
        return
    if _selected == BlockType.BUNDLE:
        cycle_held_bundle()
        return
    if _selected == BlockType.REPEATER:
        _repeater_preset = (_repeater_preset + 1) % REPEATER_PRESETS.size()
        return
    if _selected == BlockType.BOX:
        _box_shape = (_box_shape + 1) % BoxPart.SHAPE_COUNT
        return
    if _selected == BlockType.BRANCH:
        _branch_preset = (_branch_preset + 1) % BRANCH_PRESETS.size()
        return
    _detector_target = (_detector_target + 1) % DetectorPart.TARGET_COUNT


## 지금 고른 것에 설정이 있는가. 화면에 무엇을 보일지 정할 때 쓴다.
func has_part_setting() -> bool:
    return PARTS_WITH_SETTINGS.has(_selected)


## 지금 고른 설정을 화면에 보일 말로.
func part_setting_name() -> String:
    match _selected:
        BlockType.DETECTOR:
            return PartWords.target_name(_detector_target)
        BlockType.REPEATER:
            return PartWords.repeater_setting_name(_repeater_preset)
        BlockType.BOX:
            return PartWords.shape_name(_box_shape)
        BlockType.BRANCH:
            return PartWords.branch_setting_name(_branch_preset)
        BlockType.BUNDLE:
            return PartWords.bundle_name(_held_bundle)
        _:
            return ""


## 지금 고른 것을 놓을 때 함께 넘길 설정값.
func part_settings() -> PackedInt32Array:
    if _selected == BlockType.DETECTOR:
        return PackedInt32Array([_detector_target])
    if _selected == BlockType.REPEATER:
        var repeater: Array = REPEATER_PRESETS[_repeater_preset]
        return PackedInt32Array([repeater[0], repeater[1], repeater[2]])
    if _selected == BlockType.BOX:
        return PackedInt32Array([_box_shape])
    if _selected == BlockType.BRANCH:
        var branch: Array = BRANCH_PRESETS[_branch_preset]
        return PackedInt32Array([branch[0], branch[1]])
    if _selected == BlockType.BUNDLE:
        return PackedInt32Array([_held_bundle])
    return PackedInt32Array()


## 시선이 가리키는 칸을 알려준다. 표현 레이어가 매 프레임 갱신한다.
func set_target(target: BlockTarget) -> void:
    _target = target


func clear_target() -> void:
    _target = null


func has_target() -> bool:
    return _target != null and _target.hit


## 부술 칸. 가리키는 곳이 없으면 바라보는 앞 칸으로 물러난다.
func break_cell() -> Vector3i:
    if has_target():
        return _target.cell
    return _facing_cell()


## 놓을 칸. 가리키는 것의 맞은 면 바깥이다.
func place_cell() -> Vector3i:
    if has_target():
        return _target.place_cell()
    return _facing_cell()


## 지금 겨냥하고 있는 부품. 없으면 null.
func aimed_part() -> CircuitPart:
    if _simulation == null:
        return null
    return _simulation.state.circuit.part_at(break_cell())


func has_link_source() -> bool:
    return _has_link_source


func link_source() -> Vector3i:
    return _link_source


func clear_link_source() -> void:
    _has_link_source = false


## 화면 방향으로 한 걸음 접수한다.
func submit_move_screen(screen: Vector2i) -> void:
    submit_move(grid_for_screen(screen))


func submit_move(direction: Vector3i) -> void:
    if _simulation == null or direction == Vector3i.ZERO:
        return
    _simulation.submit(MoveCharacterCommand.create(direction))


func submit_place() -> void:
    if _simulation == null:
        return

    var cell := place_cell()
    if _selected == BlockType.BUNDLE and _held_bundle < 0:
        return
    if BlockType.is_part(_selected):
        _simulation.submit(PlacePartCommand.create(cell, _selected, part_settings()))
        return
    _simulation.submit(PlaceBlockCommand.create(cell, _selected))


func submit_break() -> void:
    if _simulation == null:
        return
    _simulation.submit(BreakBlockCommand.create(break_cell()))


## 지금 고른 것을 만든다. 재료가 모자라면 아무 일도 일어나지 않는다.
func submit_craft() -> void:
    if _simulation == null or not RecipeBook.can_be_made(_selected):
        return
    # 재료가 없으면 만들어지지 않는다. 그때는 소리도 나지 않아야 한다.
    if not RecipeBook.has_materials(
        _simulation.state.inventory, RecipeBook.index_for(_selected)):
        return
    _simulation.submit(CraftCommand.create(_selected))
    crafted.emit()


## 지금 고른 것을 만들 수 있는가. 화면에 무엇을 보일지 정할 때 쓴다.
func selected_can_be_made() -> bool:
    return RecipeBook.can_be_made(_selected)


## 작물을 먹는다. 배가 찬다.
func submit_eat() -> void:
    if _simulation == null:
        return
    _simulation.submit(EatCommand.create())


## 부품 둘을 배선으로 잇는다. 처음 누르면 출발점, 다음에 누르면 도착점이다.
func submit_link() -> void:
    if _simulation == null:
        return

    var cell := break_cell()
    if not _simulation.state.circuit.has_part(cell):
        clear_link_source()
        return

    if not _has_link_source:
        _link_source = cell
        _has_link_source = true
        return

    if _link_source != cell:
        var port := _link_port if wiring_from_branch() else 0
        _simulation.submit(ConnectPartsCommand.create(_link_source, cell, port))
    clear_link_source()


## 묶으려고 고른 칸들. 고른 차례 그대로다.
func chosen_cells() -> Array[Vector3i]:
    return _chosen.duplicate()


## 그 칸이 묶음에서 맡은 몫.
func role_of(cell: Vector3i) -> int:
    var at := _chosen.find(cell)
    if at < 0:
        return ROLE_PLAIN
    return _roles[at]


## 값이 들어오는 자리들. 고른 차례가 곧 배선이 닿는 차례다.
func bundle_entries() -> Array[Vector3i]:
    return _cells_with_role(ROLE_ENTRY)


## 값이 나가는 자리들. 고른 차례가 곧 출구 번호다.
func bundle_exits() -> Array[Vector3i]:
    return _cells_with_role(ROLE_EXIT)


## 지금 묶으려고 고르는 중인가.
func is_choosing() -> bool:
    return not _chosen.is_empty()


func clear_chosen() -> void:
    _chosen.clear()
    _roles.clear()


## 겨냥한 칸을 고르거나 놓는다. 부품이 없는 칸은 고를 수 없다.
func toggle_chosen() -> void:
    if _simulation == null:
        return

    var cell := break_cell()
    var at := _chosen.find(cell)
    if at >= 0:
        _chosen.remove_at(at)
        _roles.remove_at(at)
        return

    if not _simulation.state.circuit.has_part(cell):
        return
    _chosen.append(cell)
    _roles.append(ROLE_PLAIN)


## 겨냥한 칸이 맡을 몫을 다음 것으로 넘긴다. 고르지 않은 칸에는 몫이 없다.
func cycle_role() -> void:
    var at := _chosen.find(break_cell())
    if at < 0:
        return
    _roles[at] = (_roles[at] + 1) % ROLE_COUNT


## 고른 것을 하나의 묶음으로 압축한다.
func submit_bundle() -> void:
    if _simulation == null or _chosen.is_empty():
        return
    _simulation.submit(BundlePartsCommand.create(_chosen, bundle_entries(), bundle_exits()))
    clear_chosen()


## 지금 손에 쥔 묶음 번호. 아무것도 안 쥐었으면 -1.
func held_bundle() -> int:
    return _held_bundle


## 손에 든 묶음들의 번호. 늘 오름차순이다.
func owned_bundles() -> PackedInt32Array:
    var owned := PackedInt32Array()
    if _simulation == null:
        return owned
    var inventory := _simulation.state.inventory
    for id in inventory.bundle_slots():
        if inventory.count_of_bundle(id) > 0:
            owned.append(id)
    return owned


## 묶음을 손에 쥔다. 이미 쥐고 있으면 다음 묶음으로 넘어간다.
func cycle_held_bundle() -> void:
    var owned := owned_bundles()
    if owned.is_empty():
        _held_bundle = -1
        _selected = BlockType.BUNDLE
        return

    if _selected != BlockType.BUNDLE:
        _selected = BlockType.BUNDLE
        if owned.has(_held_bundle):
            return
        _held_bundle = owned[0]
        return

    var at := owned.find(_held_bundle)
    _held_bundle = owned[(at + 1) % owned.size()]


## 쥐고 있던 묶음이 사라졌으면 손을 비우거나 남은 것으로 옮긴다.
##
## 묶는 것은 명령이라 한 틱 뒤에야 손에 들어온다. 그때 저절로 쥐게 하려는 것이다.
func refresh_held_bundle() -> void:
    var owned := owned_bundles()
    if owned.has(_held_bundle):
        return
    _held_bundle = owned[0] if not owned.is_empty() else -1


func _cells_with_role(role: int) -> Array[Vector3i]:
    var cells: Array[Vector3i] = []
    for i in _chosen.size():
        if _roles[i] == role:
            cells.append(_chosen[i])
    return cells


## 눌린 키를 읽어 명령을 만든다. 표현 레이어의 프레임 루프에서 부른다.
func poll(current_tick: int) -> void:
    if _simulation == null:
        return
    refresh_held_bundle()
    _poll_selection()
    _poll_movement(current_tick)
    _poll_actions()
    _poll_camera()


## 키 배치를 InputMap 에 등록한다. 이미 있으면 손대지 않는다.
static func install_actions() -> void:
    _install(&"move_up", [KEY_W, KEY_UP])
    _install(&"move_down", [KEY_S, KEY_DOWN])
    _install(&"move_left", [KEY_A, KEY_LEFT])
    _install(&"move_right", [KEY_D, KEY_RIGHT])

    _install(ACTION_PLACE, [KEY_E])
    _install(ACTION_BREAK, [KEY_Q])
    _install(ACTION_LINK, [KEY_R])
    _install(ACTION_TARGET, [KEY_T])
    _install(ACTION_EAT, [KEY_F])
    _install(ACTION_HELP, [KEY_H, KEY_F1])
    _install(ACTION_TURN_LEFT, [KEY_BRACKETLEFT])
    _install(ACTION_TURN_RIGHT, [KEY_BRACKETRIGHT])
    _install(ACTION_CHOOSE, [KEY_V])
    _install(ACTION_TERMINAL, [KEY_B])
    _install(ACTION_BUNDLE, [KEY_G])
    _install(ACTION_HOLD_BUNDLE, [KEY_N])
    _install(ACTION_CRAFT, [KEY_C])
    _install(ACTION_LAMP, [KEY_L])
    _install(ACTION_SAVE, [KEY_F5])
    _install(ACTION_LOAD, [KEY_F9])

    var keys: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
    for i in SELECT_ACTIONS.size():
        _install(SELECT_ACTIONS[i], [keys[i]])

    _install_wheel(ACTION_ZOOM_IN, MOUSE_BUTTON_WHEEL_UP)
    _install_wheel(ACTION_ZOOM_OUT, MOUSE_BUTTON_WHEEL_DOWN)


static func _install(action: StringName, keys: Array) -> void:
    if InputMap.has_action(action):
        return
    InputMap.add_action(action)
    for key: Key in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action, event)


static func _install_wheel(action: StringName, button: MouseButton) -> void:
    if InputMap.has_action(action):
        return
    InputMap.add_action(action)
    var event := InputEventMouseButton.new()
    event.button_index = button
    InputMap.action_add_event(action, event)


func _facing_cell() -> Vector3i:
    return _simulation.state.character.facing_cell()


func _poll_movement(current_tick: int) -> void:
    if current_tick < _next_move_tick:
        return

    var screen := pressed_screen_direction()
    if screen == Vector2i.ZERO:
        return
    submit_move_screen(screen)
    _next_move_tick = current_tick + REPEAT_TICKS


## 지금 눌린 이동 키를 하나의 화면 방향으로 모은다.
##
## 두 키를 겹쳐 누르면 그 사이 쪽으로 간다. 마주 보는 두 키는 서로 지운다.
func pressed_screen_direction() -> Vector2i:
    var screen := Vector2i.ZERO
    for entry: Array in MOVE_ACTIONS:
        if Input.is_action_pressed(entry[0]):
            screen += entry[1]
    return combine(screen)


## 모은 값을 여덟 쪽 가운데 하나로 다듬는다.
static func combine(screen: Vector2i) -> Vector2i:
    return Vector2i(signi(screen.x), signi(screen.y))


func _poll_actions() -> void:
    if Input.is_action_just_pressed(ACTION_PLACE):
        submit_place()
    if Input.is_action_just_pressed(ACTION_BREAK):
        submit_break()
    if Input.is_action_just_pressed(ACTION_LINK):
        submit_link()
    if Input.is_action_just_pressed(ACTION_TARGET):
        cycle_part_setting()
    if Input.is_action_just_pressed(ACTION_EAT):
        submit_eat()
    if Input.is_action_just_pressed(ACTION_HELP):
        toggle_help()
    if Input.is_action_just_pressed(ACTION_CHOOSE):
        toggle_chosen()
    if Input.is_action_just_pressed(ACTION_TERMINAL):
        cycle_role()
    if Input.is_action_just_pressed(ACTION_BUNDLE):
        submit_bundle()
    if Input.is_action_just_pressed(ACTION_HOLD_BUNDLE):
        cycle_held_bundle()
    if Input.is_action_just_pressed(ACTION_CRAFT):
        submit_craft()
    if Input.is_action_just_pressed(ACTION_LAMP):
        select_block(BlockType.LAMP_DARK)
    if Input.is_action_just_pressed(ACTION_SAVE):
        save_requested.emit()
    if Input.is_action_just_pressed(ACTION_LOAD):
        load_requested.emit()


func _poll_camera() -> void:
    if _camera == null or not _camera.has_method("zoom_by"):
        return
    if Input.is_action_just_pressed(ACTION_ZOOM_IN):
        _camera.call("zoom_by", -1)
    if Input.is_action_just_pressed(ACTION_ZOOM_OUT):
        _camera.call("zoom_by", 1)
    if Input.is_action_just_pressed(ACTION_TURN_LEFT):
        _camera.call("turn_by", -1)
    if Input.is_action_just_pressed(ACTION_TURN_RIGHT):
        _camera.call("turn_by", 1)


## 숫자 키는 열 개뿐이다. 그 너머의 것은 제 키로 고른다. 묶음은 N 이다.
func _poll_selection() -> void:
    for i in mini(PLACEABLE.size(), SELECT_ACTIONS.size()):
        if Input.is_action_just_pressed(SELECT_ACTIONS[i]):
            select_block(PLACEABLE[i])
