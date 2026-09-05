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
const ACTION_NEXT_SLOT := &"next_slot"
const ACTION_PREV_SLOT := &"prev_slot"
const ACTION_HALF := &"take_half"
const ACTION_CLOSE := &"close_screen"
const ACTION_TURN_LEFT := &"turn_left"
const ACTION_TURN_RIGHT := &"turn_right"
const ACTION_CRAFT := &"craft"
const ACTION_RECIPE := &"cycle_recipe"
const ACTION_BAG := &"open_bag"
const ACTION_SAVE := &"save_game"
const ACTION_LOAD := &"load_game"

## 손에 쥘 수 있는 것. 고를 수 있는 차례대로.
const PLACEABLE: Array[int] = [
    BlockType.GROUND,
    BlockType.ORE,
    BlockType.WOOD,
    BlockType.SAND,
    BlockType.EMBER,
    BlockType.PLANK,
    BlockType.TORCH,
    BlockType.DOOR_CLOSED,
    BlockType.DETECTOR,
    BlockType.ACTUATOR,
    BlockType.REPEATER,
    BlockType.BOX,
    BlockType.BRANCH,
    BlockType.FIELD,
    BlockType.LAMP_DARK,
    BlockType.CHEST,
    BlockType.FURNACE,
    BlockType.BENCH,
    BlockType.BRICK,
    BlockType.GLASS,
    BlockType.IRON_DOOR_CLOSED,
]

## 설정을 고를 수 있는 부품들.
const PARTS_WITH_SETTINGS: Array[int] = [
    BlockType.DETECTOR, BlockType.REPEATER, BlockType.BOX, BlockType.BRANCH,
]

const SELECT_ACTIONS: Array = [
    &"select_1", &"select_2", &"select_3", &"select_4", &"select_5",
    &"select_6", &"select_7", &"select_8", &"select_9",
]

## 키를 누르고 있을 때 한 걸음마다 두는 간격(틱).
const REPEAT_TICKS := 4

## 부수기·놓기를 누른 채로 있을 때 한 번마다 두는 간격(틱).
##
## 한 칸씩 따로 눌러야 했다. 세계가 세로로 깊어졌고 지하를 파는 것이
## 새 유인인데, 통로 한 줄 뚷는 데 수십 번을 따로 눌러야 했다.
const DIG_TICKS := 5

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

## 인벤토리 화면을 열고 닫는다. 화면을 여는 것은 명령이 아니다.
## 하려던 것이 일어나지 않았다.
##
## **아무 일도 안 일어나는 것이 가장 나쁜 답이다.** 손이 차 있으면 부수기가
## 통째로 막히는데, 화면에서는 누르는 것이 먹히지 않는 것과 구별되지 않았다.
## 무엇이 잘못됐는지는 말하지 않는다(스펙 §1). 다만 **눌린 것은 닿았고, 세상은
## 그대로다**를 알린다.
signal balked

signal bag_toggled

## 겨냥한 궤짝을 열어 달라. 놓기(E)가 궤짝을 만나면 이쪽으로 간다.
signal chest_opened(cell: Vector3i)

var _simulation: Simulation
var _camera: Camera3D
var _selected_slot: int = 0
var _recipe: int = 0

## 방금 낸 명령을 지켜보는 자리. 지켜보지 않으면 -1.
var _watch_tick: int = -1
var _watch_version: int = 0
var _watch_stock: String = ""

## 지켜보는 것이 만들기인가. 만들기는 성공했을 때도 따로 알린다.
var _watch_craft: bool = false
var _next_move_tick: int = 0
var _next_dig_tick: int = 0
var _target: BlockTarget = null
var _detector_target: int = DetectorPart.TARGET_PLAYER
var _repeater_preset: int = 0
var _box_shape: int = BoxPart.SHAPE_SQUARE
var _branch_preset: int = 0
var _link_source: Vector3i = Vector3i.ZERO
var _has_link_source: bool = false
var _link_port: int = BranchPart.PORT_TRUE
var _help_shown: bool = false




func bind(p_simulation: Simulation) -> void:
    _simulation = p_simulation


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
    if _simulation == null:
        return BlockType.EMPTY
    return _simulation.state.inventory.kind_at(_selected_slot)


func selected_variant() -> int:
    if _simulation == null:
        return 0
    return _simulation.state.inventory.variant_at(_selected_slot)


func selected_slot() -> int:
    return _selected_slot


func select_slot(slot: int) -> void:
    if slot < 0 or slot >= Inventory.HOTBAR_SLOTS:
        return
    _selected_slot = slot


func select_block(block_type: int) -> void:
    if _simulation == null:
        return
    var inventory := _simulation.state.inventory
    for slot in Inventory.HOTBAR_SLOTS:
        if inventory.kind_at(slot) == block_type:
            _selected_slot = slot
            return


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
    var chosen := selected_block()
    if chosen == BlockType.REPEATER:
        _repeater_preset = (_repeater_preset + 1) % REPEATER_PRESETS.size()
        return
    if chosen == BlockType.BOX:
        _box_shape = (_box_shape + 1) % BoxPart.SHAPE_COUNT
        return
    if chosen == BlockType.BRANCH:
        _branch_preset = (_branch_preset + 1) % BRANCH_PRESETS.size()
        return
    _detector_target = (_detector_target + 1) % DetectorPart.TARGET_COUNT


## 지금 고른 것에 설정이 있는가. 화면에 무엇을 보일지 정할 때 쓴다.
func has_part_setting() -> bool:
    return PARTS_WITH_SETTINGS.has(selected_block())


## 지금 고른 설정을 화면에 보일 말로.
func part_setting_name() -> String:
    match selected_block():
        BlockType.DETECTOR:
            return PartWords.target_name(_detector_target)
        BlockType.REPEATER:
            return PartWords.repeater_setting_name(_repeater_preset)
        BlockType.BOX:
            return PartWords.shape_name(_box_shape)
        BlockType.BRANCH:
            return PartWords.branch_setting_name(_branch_preset)
        _:
            return ""


## 지금 고른 것을 놓을 때 함께 넘길 설정값.
func part_settings() -> PackedInt32Array:
    var chosen := selected_block()
    if chosen == BlockType.DETECTOR:
        return PackedInt32Array([_detector_target])
    if chosen == BlockType.REPEATER:
        var repeater: Array = REPEATER_PRESETS[_repeater_preset]
        return PackedInt32Array([repeater[0], repeater[1], repeater[2]])
    if chosen == BlockType.BOX:
        return PackedInt32Array([_box_shape])
    if chosen == BlockType.BRANCH:
        var branch: Array = BRANCH_PRESETS[_branch_preset]
        return PackedInt32Array([branch[0], branch[1]])
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
## 지금 붙어 있는 시뮬레이션. 화면 쪽이 읽기만 한다.
func simulation() -> Simulation:
    return _simulation


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

    # 궤짝을 겨냥하고 놓기를 누르면 궤짝이 열린다. 놓는 것이 아니다.
    var aimed := break_cell()
    if _simulation.state.chests.has_chest(aimed):
        chest_opened.emit(aimed)
        return

    var cell := place_cell()
    var chosen := selected_block()
    if chosen == BlockType.EMPTY:
        return
    if BlockType.is_part(chosen):
        _simulation.submit(PlacePartCommand.create(cell, chosen, part_settings()))
    else:
        _simulation.submit(PlaceBlockCommand.create(cell, chosen))
    _watch_this_attempt()


func submit_break() -> void:
    if _simulation == null:
        return
    # 손에 든 것을 그대로 실어 보낸다. 그것으로 무엇을 캘 수 있는지는
    # 시뮬레이션이 정한다([ToolRules]). 화면이 다시 판단하지 않는다.
    _simulation.submit(BreakBlockCommand.create(break_cell(), selected_block()))
    _watch_this_attempt()


## 방금 낸 명령이 세상을 바꾸는지 지켜본다.
##
## 규칙을 여기에 옮겨 적지 않는다. 손이 찼는지, 궤짝이 비었는지, 바위인지를
## 표현 레이어가 다시 판단하면 언젠가 시뮬레이션과 어긋나고, 어긋난 신호는
## 없느니만 못하다. **낸 다음에 세상이 그대로인지만 본다.**
func _watch_this_attempt(is_craft: bool = false) -> void:
    _watch_tick = _simulation.state.tick
    _watch_version = _simulation.state.grid.version()
    _watch_stock = _stock_print()
    _watch_craft = is_craft


## 손에 든 것의 지문. 총 개수만 보면 넷이 하나가 되는 만들기를 놓칠 수 있다.
func _stock_print() -> String:
    return SimHash.hash_fields(_simulation.state.inventory.to_hash_fields())


## 지켜보던 틱이 지났는데 아무것도 안 바뀌었으면 알린다.
func _watch_for_balk() -> void:
    if _watch_tick < 0 or _simulation.state.tick <= _watch_tick:
        return

    var still := (_simulation.state.grid.version() == _watch_version
        and _stock_print() == _watch_stock)
    var was_craft := _watch_craft
    _watch_tick = -1
    _watch_craft = false

    if still:
        balked.emit()
    elif was_craft:
        crafted.emit()


## 지금 만들려는 것.
##
## 핫바가 칸이 되면서 "고른 것을 만든다"가 성립하지 않는다 — 빈 칸을 잡고
## 있을 수도 있기 때문이다. 만들 것은 따로 고른다.
func recipe_output() -> int:
    return RecipeBook.output_of(_recipe)


func recipe_index() -> int:
    return _recipe


func cycle_recipe() -> void:
    _recipe = (_recipe + 1) % RecipeBook.count()


## 만든다. 재료가 모자라면 아무 일도 일어나지 않는다.
##
## **재료를 여기서 미리 세지 않는다.** 부수기·놓기와 달리 만들기만 규칙을
## 옮겨 적고 있었다. 시뮬레이션이 다른 까닭으로 거절하면 소리는 "만들었다"고
## 말했다 — 화면과 소리가 다른 것을 말하는 자리다. 낸 다음에 손이 바뀌었는지만
## 본다.
func submit_craft() -> void:
    if _simulation == null:
        return
    _simulation.submit(CraftCommand.create(recipe_output()))
    _watch_this_attempt(true)


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
## 눌린 키를 읽어 명령을 만든다. 표현 레이어의 프레임 루프에서 부른다.
func poll(current_tick: int) -> void:
    if _simulation == null:
        return
    _watch_for_balk()
    _poll_selection()
    _poll_movement(current_tick)
    _poll_actions(current_tick)
    _poll_camera()


## 키 배치를 InputMap 에 등록한다. 이미 있으면 손대지 않는다.
static func install_actions() -> void:
    _install(&"move_up", [KEY_W, KEY_UP])
    _install(&"move_down", [KEY_S, KEY_DOWN])
    _install(&"move_left", [KEY_A, KEY_LEFT])
    _install(&"move_right", [KEY_D, KEY_RIGHT])

    # 마우스가 먼저다. 키는 같은 일을 하는 다른 길이다 —
    # 마우스 없이도 놀 수 있어야 한다(스펙 §3.4).
    _install_click(ACTION_BREAK, MOUSE_BUTTON_LEFT, [KEY_Q])
    _install_click(ACTION_PLACE, MOUSE_BUTTON_RIGHT, [KEY_E])
    _install(ACTION_CLOSE, [KEY_ESCAPE])
    _install(ACTION_LINK, [KEY_R])
    _install(ACTION_TARGET, [KEY_T])
    _install(ACTION_EAT, [KEY_F])
    _install(ACTION_HELP, [KEY_H, KEY_F1])
    _install(ACTION_TURN_LEFT, [KEY_BRACKETLEFT])
    _install(ACTION_TURN_RIGHT, [KEY_BRACKETRIGHT])
    _install(ACTION_CRAFT, [KEY_C])
    _install(ACTION_RECIPE, [KEY_X])
    _install(ACTION_BAG, [KEY_TAB, KEY_I])
    _install(ACTION_SAVE, [KEY_F5])
    _install(ACTION_LOAD, [KEY_F9])

    var keys: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
    for i in SELECT_ACTIONS.size():
        _install(SELECT_ACTIONS[i], [keys[i]])

    # 휠은 핫바 칸을 바꿀다. 마크가 그렇고, 당기고 미는 것보다
    # 이쪽을 훨씬 자주 한다.
    _install_wheel(ACTION_PREV_SLOT, MOUSE_BUTTON_WHEEL_UP)
    _install_wheel(ACTION_NEXT_SLOT, MOUSE_BUTTON_WHEEL_DOWN)
    _install_click(ACTION_HALF, MOUSE_BUTTON_RIGHT, [])
    _install(ACTION_ZOOM_IN, [KEY_EQUAL, KEY_KP_ADD])
    _install(ACTION_ZOOM_OUT, [KEY_MINUS, KEY_KP_SUBTRACT])


static func _install(action: StringName, keys: Array) -> void:
    if InputMap.has_action(action):
        return
    InputMap.add_action(action)
    for key: Key in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action, event)


## 마우스 단추 하나와 키 몇을 함께 묶는다.
static func _install_click(action: StringName, button: MouseButton, keys: Array) -> void:
    if InputMap.has_action(action):
        return
    InputMap.add_action(action)

    var click := InputEventMouseButton.new()
    click.button_index = button
    InputMap.action_add_event(action, click)

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


func _poll_actions(current_tick: int) -> void:
    # 부수기와 놓기는 누른 채로 있으면 되풀이된다.
    if Input.is_action_just_pressed(ACTION_PLACE):
        submit_place()
        _next_dig_tick = current_tick + DIG_TICKS
    elif Input.is_action_just_pressed(ACTION_BREAK):
        submit_break()
        _next_dig_tick = current_tick + DIG_TICKS
    elif current_tick >= _next_dig_tick:
        if Input.is_action_pressed(ACTION_BREAK):
            submit_break()
            _next_dig_tick = current_tick + DIG_TICKS
        elif Input.is_action_pressed(ACTION_PLACE):
            submit_place()
            _next_dig_tick = current_tick + DIG_TICKS
    if Input.is_action_just_pressed(ACTION_LINK):
        submit_link()
    if Input.is_action_just_pressed(ACTION_TARGET):
        cycle_part_setting()
    if Input.is_action_just_pressed(ACTION_EAT):
        submit_eat()
    if Input.is_action_just_pressed(ACTION_HELP):
        toggle_help()
    if Input.is_action_just_pressed(ACTION_CRAFT):
        submit_craft()
    if Input.is_action_just_pressed(ACTION_RECIPE):
        cycle_recipe()
    if Input.is_action_just_pressed(ACTION_BAG):
        bag_toggled.emit()
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


## 핫바 칸을 옆으로 옮긴다. 휠이 부른다.
func step_slot(by: int) -> void:
    _selected_slot = posmod(_selected_slot + by, Inventory.HOTBAR_SLOTS)


## 숫자 키는 아홉 개다. 손에 잡히는 줄이 그만큼이다.
func _poll_selection() -> void:
    for i in SELECT_ACTIONS.size():
        if Input.is_action_just_pressed(SELECT_ACTIONS[i]):
            select_slot(i)
    if Input.is_action_just_pressed(ACTION_NEXT_SLOT):
        step_slot(1)
    if Input.is_action_just_pressed(ACTION_PREV_SLOT):
        step_slot(-1)
