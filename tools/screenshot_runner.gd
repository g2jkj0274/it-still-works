extends SceneTree

## 게임을 실제로 띄워 단계별 스크린샷을 남기고 명백한 이상을 찾는다.
##
## 헤드리스(--headless)에서는 렌더링 드라이버가 더미라 화면이 나오지 않는다.
## 그래서 이 도구는 창을 띄우고 돌린다. 실행:
##
##   godot --path . -s res://tools/screenshot_runner.gd
##
## 결과는 reports/screenshots/ 에 쌓인다. 이상이 있으면 종료 코드 1.

const OUT_DIR := "res://reports/screenshots"

## 명령이 반영되고 화면이 자리잡을 때까지 기다릴 프레임 수.
const SETTLE_FRAMES := 24

## 캐릭터를 감췄다 켤 때 한 프레임만으로는 갱신이 안 될 수 있다.
## 캐릭터를 감춘 뒤 몇 프레임을 기다렸다 다시 찍는가.
##
## 세 프레임으로는 처음 도는 판에서 셰이더를 굽고 자원을 읽느라 프레임이
## 통째로 밀릴 때 감추기 전 화면이 잡혔다. 그러면 두 장이 같아서 "캐릭터가
## 없다"고 잘못 일렀다. 검사 도구가 가끔 거짓으로 우는 것이 가장 나쁘다.
const TOGGLE_FRAMES := 10

## 캐릭터가 있어야 할 화면 영역의 크기(픽셀).
const SUBJECT_BOX := Vector2i(120, 160)

var _main: GameMain
var _steps: Array = []
var _index := 0
var _phase := 0
var _wait := 0

## 회로가 나오는 단계에서, 그 회로가 실제로 일을 했는가.
##
## **닫힌 문 앞에 선 그림은 아무것도 증명하지 못한다.** 이 검사가 상점 그림에만
## 걸려 있던 동안, 자동문 그림 석 장이 죽은 회로를 찍고 있는 것을 아무도
## 잡지 못했다. 회로가 나오는 단계라면 어디든 걸린다.
##
## 무엇을 보는지는 장치마다 다르다 — 문은 열렸는지, 등은 켜졌는지, 밭은
## 거두어졌는지. 장치가 늘면 여기에 한 줄이 는다.
var _worked: Dictionary[String, bool] = {}
var _with_subject: Image
var _report: Array[String] = []

## 08 단계가 실제로 놓은 작동기와 감지기의 자리. 다시 계산하지 않고 적어 둔다.
var _door_parts: Array[Vector3i] = []

## 09 · 10 단계가 세운 등과 밭. 회로가 실제로 한 일을 찍기 직전에 본다.
var _lamp_cells: Array[Vector3i] = []
var _field_cells: Array[Vector3i] = []

## 자동문 단계가 세운 문. 실제로 열렸는지 찍기 직전에 본다.
var _door_cell: Vector3i = Vector3i.ZERO

## 지하 그림에서 굴 벽에 드러난 광석 칸 수.
var _ore_in_sight: int = 0

## 만들기 그림에서 손으로 만들어 세운 것의 수.
var _made_by_hand: int = 0
var _failures := 0


func _initialize() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
    _main = (load("res://view/main.tscn") as PackedScene).instantiate()
    root.add_child(_main)
    _steps = _build_steps()


func _process(_delta: float) -> bool:
    if _index >= _steps.size():
        return _finish()

    match _phase:
        0:
            _begin_step()
        1:
            if _tick_wait():
                _with_subject = _capture()
                _main.character_view().visible = false
                _wait = TOGGLE_FRAMES
                _phase = 2
        2:
            if _tick_wait():
                var without := _capture()
                _main.character_view().visible = true
                _evaluate(without)
                _index += 1
                _phase = 0
    return false


## 화면이 세상을 통째로 가리는 단계들. 캐릭터가 보일 리 없다.
const COVERED_STEPS: PackedStringArray = ["16_bag"]

## 단계 목록. 각 항목은 [이름, 준비 동작] 이다.
##
## 저장 단계가 앞쪽에 있는 것은 일부러다. 뒤의 단계들은 무대를 세우려고 상태를
## 손으로 건드리는데(재료를 쥐여 주고, 밤으로 건너뛰고), 저장은 명령 기록이라
## 그런 것을 되살리지 못한다. 게임 자체는 모든 것을 명령으로 하므로 문제가
## 없지만, 이 검사가 뜻을 가지려면 손대기 전에 놓여야 한다.
func _build_steps() -> Array:
    return [
        ["01_spawn", func() -> void: pass],
        ["02_walk", _walk],
        ["03_gather", _gather],
        ["04_place", _place],
        ["05_break", _break],
        ["06_build_tower", _build_tower],
        ["07_save", _write_and_read_back],
        ["08_auto_door", _build_auto_door],
        ["09_lamp", _build_the_porch_lamp],
        ["10_farm", _build_the_farm],
        ["11_night", _fall_of_night],
        ["12_parts", _line_up_the_parts],
        ["13_island", _pull_back_to_the_shore],
        ["14_craft", _make_something_by_hand],
        ["15_underground", _dig_down],
        ["16_bag", _open_the_bag],
        ["17_store", _pose_for_the_store],
    ]


func _walk() -> void:
    var start := _main.simulation.current_tick()
    for i in 4:
        _main.simulation.submit_at(MoveCharacterCommand.create(Vector3i(0, -1, 0)), start + i * 2)


func _gather() -> void:
    # 빈손으로 시작하므로 먼저 부숴 재료를 모은다.
    var start := _main.simulation.current_tick()
    var here := _main.simulation.state.character.cell()
    for i in 4:
        _main.simulation.submit_at(
            BreakBlockCommand.create(here + Vector3i(i - 2, 2, -1)), start + i * 2)


func _place() -> void:
    _main.input_controller().select_block(BlockType.GROUND)
    _main.input_controller().submit_place()


func _break() -> void:
    _main.input_controller().submit_break()


func _build_tower() -> void:
    # 눈에 잘 띄는 덩어리를 세워 블록이 실제로 그려지는지 본다.
    var base := _main.simulation.state.character.facing_cell()
    var start := _main.simulation.current_tick()
    for i in 3:
        _main.simulation.submit_at(
            PlaceBlockCommand.create(base + VoxelGrid.UP * i, BlockType.GROUND), start + i * 2)


## 감지기 → 작동기 → 문. 스펙 5절의 첫 번째 조합이 화면에 나오는지 본다.
func _build_auto_door() -> void:
    var state: Object = _main.simulation.state
    state.inventory.add(BlockType.DOOR_CLOSED, 2)
    state.inventory.add(BlockType.DETECTOR, 2)
    state.inventory.add(BlockType.ACTUATOR, 2)

    # **감지기가 사람을 볼 수 있는 자리여야 한다.** 넉 칸 떨어뜨려 놓았더니
    # ([constant DetectorPart.SENSE_RADIUS] 는 3) 감지기가 사람을 못 봤고,
    # 자동문 그림 석 장이 전부 죽은 회로를 찍고 있었다. 스펙 §8 이 "1번이
    # 재미없으면 부품을 늘려도 소용없다"고 지목한 그 판정 지점이다.
    var here: Vector3i = state.character.cell()
    var door := here + Vector3i(1, 0, 0)
    var actuator := here + Vector3i(2, 0, 0)
    var detector := here + Vector3i(3, 0, 0)

    # 무대를 비운다. 저절로 난 작물이 자리를 차지하고 있으면 놓이지 않는다.
    for cell in [door, actuator, detector]:
        state.grid.set_block(cell, BlockType.EMPTY)
    _door_parts = [actuator, detector]

    var start := _main.simulation.current_tick()
    _main.simulation.submit_at(PlaceBlockCommand.create(door, BlockType.DOOR_CLOSED), start)
    _main.simulation.submit_at(PlacePartCommand.create(actuator, BlockType.ACTUATOR), start + 2)
    _main.simulation.submit_at(
        PlacePartCommand.create(detector, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER])), start + 4)
    _main.simulation.submit_at(ConnectPartsCommand.create(detector, actuator), start + 6)
    _door_cell = door


## 다가가면 켜지는 등. 감지기(사람) → 작동기 → 등 셋.
##
## **부품 셋으로 다른 기계가 나온다는 것이 이 그림의 전부다.** 자동문과 같은
## 감지기·작동기인데 붙인 블록이 달라 하는 일이 달라진다 — 스펙 §4.2 가
## "블록을 추가해도 회로 부품은 늘지 않는다"고 적은 자리다.
func _build_the_porch_lamp() -> void:
    var state: Object = _main.simulation.state
    var here: Vector3i = state.character.cell()
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            var floor_cell := here + Vector3i(dx, dy, -1)
            state.grid.set_block(floor_cell, BlockType.GROUND)
            state.grid.set_block(floor_cell + VoxelGrid.UP, BlockType.EMPTY)

    # **작동기는 맞닿은 여섯 칸만 건드린다.** 화면의 오른쪽은 격자로 (1,-1)
    # 이라 대각선이고, 거기 등을 놓으면 손이 닿지 않아 회로가 죽는다.
    # 화면에서 나란해 보이는 것과 격자에서 맞닿는 것은 다른 이야기다.
    # **격자 (-1,-1) 이 화면 위쪽이다.** 사람 뒤에 세워야 장치가 화면 위로
    # 올라가고, 아래에 세우면 밑동 글줄과 손에 잡히는 줄에 잘린다.
    var eye := here + Vector3i(-1, -1, 0)
    var hand := here + Vector3i(-3, -3, 0)
    _lamp_cells = [
        hand + Vector3i(1, 0, 0), hand + Vector3i(-1, 0, 0), hand + Vector3i(0, -1, 0),
    ]
    for cell in _lamp_cells:
        state.grid.set_block(cell, BlockType.LAMP_DARK)

    _put(eye, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER]))
    _put(hand, BlockType.ACTUATOR, PackedInt32Array())
    state.circuit.link(eye, hand)

    for i in 24:
        _main.simulation.step()
        if state.grid.get_block(_lamp_cells[0]) == BlockType.LAMP_LIT:
            break

    # **사람이 장치를 가리면 안 된다.** 카메라는 사람을 따라가므로 그대로
    # 두면 회로가 화면 밑동으로 밀려 글줄과 손에 잡히는 줄에 잘린다.
    # 사람과 장치 사이를 본다.
    _look_between(here, hand)
    _main.world_view().rebuild()
    _main.wire_view().rebuild()
    _main.lamp_lights().look_at_point(_main.character_view().target_position())
    _main.lamp_lights().sync()


## 자동 농장. 감지기(작물) → 되풀이 → 작동기 → 밭.
##
## 부품이 셋으로 늘고 **되풀이가 처음 나온다.** 사람이 없어도 도는 것이
## 무엇인지 이 그림이 말해야 한다.
func _build_the_farm() -> void:
    var state: Object = _main.simulation.state
    var here: Vector3i = state.character.cell()
    for dy in range(-5, 6):
        for dx in range(-5, 6):
            var floor_cell := here + Vector3i(dx, dy, -1)
            state.grid.set_block(floor_cell, BlockType.GROUND)
            state.grid.set_block(floor_cell + VoxelGrid.UP, BlockType.EMPTY)

    # 감지기는 세 칸 안의 다 자란 작물을 본다. 작동기는 맞닿은 여섯 칸을
    # 거둔다. **둘을 함께 만족하는 자리에 밭이 있어야** 회로가 돈다.
    # 격자 (-1,-1) 이 화면 위쪽이다. 사람 뒤에 세운다.
    var eye := here + Vector3i(-2, -2, 0)
    var turns := here + Vector3i(-5, -2, 0)
    var hand := here + Vector3i(-3, -3, 0)
    _field_cells = [
        hand + Vector3i(1, 0, 0), hand + Vector3i(0, 1, 0), hand + Vector3i(0, -1, 0),
    ]
    for cell in _field_cells:
        state.grid.set_block(cell, BlockType.FIELD)
        state.crops.plant(cell)

    _put(eye, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_CROP]))
    _put(turns, BlockType.REPEATER, PackedInt32Array([RepeaterPart.MODE_FOREVER, 0, 10]))
    _put(hand, BlockType.ACTUATOR, PackedInt32Array())
    state.circuit.link(eye, turns)
    state.circuit.link(turns, hand)

    # **다 자란 작물이 있어야 감지기가 본다.** 갓 심은 밭 앞에서는 배선이
    # 내내 흐린 색이고, 그러면 죽은 회로를 찍는 것이다.
    _main.simulation.advance(CropField.MATURE_TICKS + 40)

    _look_between(here, hand)
    _main.world_view().rebuild()
    _main.wire_view().rebuild()


## 08 단계가 놓은 작동기와 감지기의 자리.
func _auto_door_parts() -> Array[Vector3i]:
    return _door_parts


## 사람과 장치 사이를 본다.
##
## 카메라는 사람을 따라간다. 장치를 사람 옆에 세우면 그대로는 화면 한쪽으로
## 밀려 밑동 글줄과 손에 잡히는 줄에 잘린다. 둘의 가운데를 잡고 조금 물린다.
func _look_between(person: Vector3i, device: Vector3i) -> void:
    var middle := SimViewCoords.cell_to_world(person).lerp(
        SimViewCoords.cell_to_world(device), 0.5)
    _main.camera().zoom_by(-4)
    _main.camera().focus_on(middle)


func _target_at(cell: Vector3i) -> BlockTarget:
    var target := BlockTarget.new()
    target.hit = true
    target.cell = cell
    target.normal = VoxelGrid.UP
    return target


## 밤으로 건너뛴다. 어두워지고 위협이 나오는지 본다.
## 손에 잡히는 줄을 채운다.
##
## 열일곱 장 가운데 셋이 아홉 칸을 전부 비운 채로 찍혀 있었다. 스팀
## 스크린샷에서 빈 인벤토리는 "할 게 없는 게임"으로 읽힌다. **첫 그림
## (01_spawn)만은 비워 둔다** — 빈손으로 시작하는 것이 이 게임의 규칙이고,
## 거기서는 그것이 사실이다.
func _fill_the_hand() -> void:
    var bag: Object = _main.simulation.state.inventory
    for entry: Array in [
        [BlockType.WOOD_PICK, 1], [BlockType.STONE_PICK, 1], [BlockType.STONE_AXE, 1],
        [BlockType.TORCH, 12], [BlockType.PLANK, 24], [BlockType.WOOD, 8],
        [BlockType.ROCK, 32], [BlockType.EMBER, 6], [BlockType.CROP, 4],
    ]:
        bag.add(int(entry[0]), int(entry[1]))


func _fall_of_night() -> void:
    _main.simulation.advance(DayCycle.DAY_TICKS - _main.simulation.current_tick() + 20)

    # **밤 그림에 빛이 하나도 없었다.** 화면이 고르게 어두워 "어둡게 칠한 낮"
    # 으로 보였다. 대비가 있어야 밤이 밤이 된다 — 지하 그림이 강한 까닭도
    # 등불 하나 때문이다.
    _fill_the_hand()
    var state: Object = _main.simulation.state
    var here: Vector3i = state.character.cell()
    for offset in [Vector3i(-2, -1, 0), Vector3i(2, 2, 0), Vector3i(-1, 3, 0)]:
        var cell: Vector3i = here + offset
        if state.grid.is_empty_cell(cell) and state.grid.is_solid(cell - VoxelGrid.UP):
            state.grid.set_block(cell, BlockType.TORCH)
    _main.world_view().rebuild()
    _main.lamp_lights().look_at_point(_main.character_view().target_position())
    _main.lamp_lights().sync()


## 부품을 나란히 늘어놓고 가까이 본다.
##
## 파스텔은 폭이 좁아 색만으로는 종류가 흐려진다. 생김새로 갈리는지는 멀리서
## 보아서는 알 수 없으므로 이 단계만 카메라를 당긴다.
##
## **회로에 넣어 세운다.** 격자에만 놓았을 때에는 지붕 위 설정 표시가 하나도
## 붙지 않았다 — [PartMarks] 는 격자가 아니라 회로를 읽기 때문이다. 그 표시를
## 보여야 할 그림에 그 표시가 없었다. 설정도 서로 다르게 준다. 같은 감지기
## 다섯이 저마다 다른 것을 보고 있는 줄이 이 게임의 깊이를 가장 잘 말한다.
func _line_up_the_parts() -> void:
    var state: Object = _main.simulation.state
    # 카메라는 사람을 따라간다. 무대를 사람 옆에 바짝 붙여야 화면에 들어온다.
    var centre: Vector3i = state.character.cell() + Vector3i(1, -1, 0)

    # 낮으로 되돌린다. 밤 화면에서는 형태가 아니라 어둠이 보인다.
    state.tick = 0

    # [블록, 설정]. 부품은 회로에 들어가고 나머지는 격자에만 놓인다.
    var kinds: Array = [
        [BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER])],
        [BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_THREAT])],
        [BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_TIME])],
        [BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_CROP])],
        [BlockType.BRANCH, PackedInt32Array([BranchPart.MODE_TRUTH, 0])],
        [BlockType.BRANCH, PackedInt32Array([BranchPart.MODE_AND, 0])],
        [BlockType.REPEATER, PackedInt32Array([RepeaterPart.MODE_COUNT, 3, 10])],
        [BlockType.REPEATER, PackedInt32Array([RepeaterPart.MODE_FOREVER, 0, 10])],
    ]
    # 바닥을 고른다. 기복 위에 늘어놓으면 부품이 저마다 다른 높이에 서서
    # 줄로 읽히지 않는다. 견주려고 세운 무대이므로 바닥이 평평해야 한다.
    for dy in range(-3, 4):
        for dx in range(-5, 6):
            var floor_cell := centre + Vector3i(dx, dy, -1)
            state.grid.set_block(floor_cell, BlockType.GROUND)
            state.grid.set_block(floor_cell + VoxelGrid.UP, BlockType.EMPTY)

    # 한 칸씩 띄운다. 붙여 놓으면 키 큰 것이 뒤의 것을 가려 견줄 수가 없다.
    for i in kinds.size():
        var cell := centre + Vector3i((i % 4) * 2 - 3, (i / 4) * 2 - 1, 0)
        state.grid.set_block(cell - VoxelGrid.UP, BlockType.GROUND)
        var kind: int = kinds[i][0]
        if BlockType.is_part(kind):
            _put(cell, kind, kinds[i][1])
        else:
            state.grid.set_block(cell, kind)

    _main.camera().zoom_by(-20)
    _main.world_view().rebuild()
    _main.part_marks().rebuild()


## 멀리 물러나 물가를 본다.
##
## 지금까지는 섬 끝이 허공으로 끊겨 어디가 뭍이고 어디가 바깥인지 알 수 없었다.
func _pull_back_to_the_shore() -> void:
    _main.camera().zoom_by(40)


## 모은 재료로 부품을 만든다. 드는 재료가 화면 아래 한 줄에 뜨는지 본다.
## 손으로 만들고, 만든 것을 세워 본다.
##
## **앞 단계와 같은 그림이 나오고 있었다.** 만들었다는 사실이 손에 잡히는 줄의
## 숫자로만 나타나서, 화면에서는 아무 일도 일어나지 않았다. 열일곱 장 가운데
## 두 장이 같은 그림이면 상점에 걸 장수가 두 장 준다.
##
## 만든 것을 실제로 세운다. 스펙 §3.6 의 "나무 넷이 문 하나가 된다"가
## 그림으로 읽혀야 한다.
## 만들 것을 고른다. 만들기 고르기(C)는 제작법을 차례로 돈다.
func _choose_recipe(wanted: int) -> void:
    var controller := _main.input_controller()
    for i in RecipeBook.count():
        if controller.recipe_output() == wanted:
            return
        controller.cycle_recipe()


func _make_something_by_hand() -> void:
    _main.simulation = IslandBuilder.start(GameMain.SEED)
    _main.adopt_simulation()
    _main.first_steps().silence()
    _main.notice().visible = false

    var state: Object = _main.simulation.state
    var controller := _main.input_controller()
    var here: Vector3i = state.character.cell()

    # 무대를 고른다. 세운 것이 기복에 묻히면 만든 보람이 안 보인다.
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            var floor_cell := here + Vector3i(dx, dy, -1)
            state.grid.set_block(floor_cell, BlockType.GROUND)
            state.grid.set_block(floor_cell + VoxelGrid.UP, BlockType.EMPTY)

    state.inventory.add(BlockType.WOOD, 12)
    state.inventory.add(BlockType.ORE, 6)

    # **나무를 판자로 켜고 그 판자로 문을 만든다.** 만들기가 한 단 깊어졌다(§3.6).
    # 나무 12 로 판자 16 을 얻고, 그것으로 문 넷을 만든다.
    _choose_recipe(BlockType.PLANK)
    for i in 4:
        controller.submit_craft()
        _main.simulation.advance(2)
    _choose_recipe(BlockType.DOOR_CLOSED)
    for i in 4:
        controller.submit_craft()
        _main.simulation.advance(2)

    # 하나는 손에 남긴다. 손이 비면 화면 밑동 한 줄이 "빈 손"이라고 적어,
    # 방금 만든 것이 무엇인지 그림이 말하지 못한다.
    var made := 0
    for dx in range(-1, 2):
        var spot := here + Vector3i(dx, -2, 0)
        if state.inventory.count_of(BlockType.DOOR_CLOSED) <= 1:
            break
        state.inventory.take(BlockType.DOOR_CLOSED, 1)
        state.grid.set_block(spot, BlockType.DOOR_CLOSED)
        made += 1
    _made_by_hand = made

    controller.select_block(BlockType.DOOR_CLOSED)
    _main.camera().zoom_by(-14)
    _main.world_view().rebuild()


## 판을 적어 두었다 되살린다. 알림 한 줄이 화면에 뜨는지, 되살린 판이 그대로
## 그려지는지 본다.
func _write_and_read_back() -> void:
    if not _main.save_game():
        _fail("07_save", "판을 적어 두지 못했다")
        return

    var saved: String = _main.simulation.state_hash()
    _main.simulation.advance(40)

    if not _main.load_game():
        _fail("07_save", "적어 둔 판을 불러오지 못했다")
        return
    if _main.simulation.state_hash() != saved:
        _fail("07_save", "불러온 판이 적어 둔 판과 다르다")


## 스토어에 걸 그림 한 장.
##
## 이 게임이 팔릴 근거는 하나다 — **"내가 조립한 장치가 돌아가고, 그것을 한
## 칸으로 압축해 다시 쓴다."** 그 근거가 한 그림에 다 들어가야 한다.
##
## 해 질 녘. 밭과 문이 있고, 감지기에서 갈림길·되풀이·상자를 지나 작동기까지
## 배선이 훤히 보이며 신호가 흐른다. 회로가 실제로 한 일이
## 나란히 놓여 "저게 저 한 칸이 됐다"가 그림만으로 읽힌다.
##
## 러너가 결정론적으로 같은 그림을 다시 뽑아 주므로, 아트가 바뀔 때마다
## 이 장면도 함께 갱신된다. **검사 도구가 곧 마케팅 자산이다.**
func _pose_for_the_store() -> void:
    # **새 판에서 찍는다.** 앞 단계들이 파 놓은 구덩이와 세워 둔 탑과 밤에
    # 나온 것들이 남아 있으면 그림이 어수선해진다.
    _main.simulation = IslandBuilder.start(GameMain.SEED)
    _main.adopt_simulation()
    _main.first_steps().silence()
    _main.notice().visible = false

    var state: Object = _main.simulation.state
    var controller := _main.input_controller()

    # **한낮으로 맞춘다.** 해 질 녘은 색이 곱지만 무엇을 하는 게임인지가
    # 어둠에 묻힌다. 상점 첫 그림은 분위기가 아니라 **장치가 도는 것**을
    # 보여야 한다. 밤 그림은 따로 있다(11_night).
    state.tick = DayCycle.DAY_TICKS / 4
    # **틱을 직접 쓰면 날이 밝는 순간을 건너뛴다.** 그래서 밤에 나온 위협이
    # 그대로 남아 상점 그림에 한낮의 괴물이 서 있었다. 재어 보면 틱만 옮겼을
    # 때 넷이 그대로고, 하루를 마저 돌리면 0 이다. 건너뛴 만큼 손으로 치운다.
    state.threats.clear()
    _fill_the_hand()

    # 요 45도에서 화면 오른쪽은 격자 (1,-1), 화면 아래는 격자 (1,1) 이다.
    # 카메라가 사람을 따라가므로 사람을 가운데 두고 그 둘레에 세운다.
    var here: Vector3i = state.character.cell()
    var right := Vector3i(1, -1, 0)
    var down := Vector3i(1, 1, 0)

    for dy in range(-8, 9):
        for dx in range(-8, 9):
            var floor_cell := here + Vector3i(dx, dy, -1)
            state.grid.set_block(floor_cell, BlockType.GROUND)
            state.grid.set_block(floor_cell + VoxelGrid.UP, BlockType.EMPTY)

    # **회로를 한 줄로 늘어놓지 않는다.**
    #
    # 다섯을 나란히 붙여 두었더니 배선 길이가 사실상 0 이 되어, 노란 막대
    # 하나가 부품 여섯을 관통하는 그림이 나왔다. 그것은 회로가 아니라
    # "물건을 늘어놓은 것"으로 읽힌다. 레드스톤 그림이 회로로 보이는 까닭은
    # **꺾이고 사이가 벌어져** 있기 때문이다.
    #
    # 그래서 한 칸씩 띄우고 한 번 꺾는다. 배선이 실제로 보이는 길이를 갖고,
    # 신호 점이 달려가는 구간이 생긴다.
    #
    # 감지기는 사람을 세 칸 안에서 본다. 신호가 실제로 흐르는 순간을 찍으려면
    # 그 안에 들어와야 한다. 배선이 흐린 색이면 아무것도 증명하지 못한다.
    # 오른쪽으로 둘, 아래로 꺾고, 다시 왼쪽으로 돌아온다 — **ㄷ자**다.
    # 한쪽으로만 뻗으면 화면 밖으로 나가고, 되돌아오면 꺾이는 마디가 셋이 된다.
    #
    # 눈은 줄의 첫머리에 둔다. 사람과 두 칸이라 [constant DetectorPart.SENSE_RADIUS]
    # 안이다. 여기를 벌리면 감지기가 사람을 못 봐 회로가 통째로 죽는다.
    var row := here + down
    var eye := row
    var branch := row + right * 2
    var repeater := branch + right * 2
    var box := repeater + down * 2
    var hand := box - right * 2
    # **문은 작동기와 격자에서 맞닿아야 한다.** 화면의 오른쪽은 격자로 (1,-1)
    # 이라 대각선이고, 작동기는 맞닿은 여섯 쪽만 건드린다. 화면에서 나란히
    # 보이던 문이 실은 손이 닿지 않는 자리에 있어서 열리지 않았다.
    var door := hand + Vector3i(1, 0, 0)
    # 켜진 등 하나를 더 붙인다. 열린 문은 얇은 판이라 한 장의 그림에서
    # 놓치기 쉽다. **회로가 한 일이 한눈에 보여야 한다.**
    var lamp := hand + Vector3i(0, 1, 0)

    state.grid.set_block(door, BlockType.DOOR_CLOSED)
    state.grid.set_block(lamp, BlockType.LAMP_DARK)

    _put(eye, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER]))
    _put(branch, BlockType.BRANCH, PackedInt32Array([BranchPart.MODE_TRUTH, 0]))
    _put(repeater, BlockType.REPEATER,
        PackedInt32Array([RepeaterPart.MODE_FOREVER, 0, 10]))
    _put(box, BlockType.BOX, PackedInt32Array([BoxPart.SHAPE_ROUND]))
    _put(hand, BlockType.ACTUATOR, PackedInt32Array())

    for pair in [[eye, branch], [branch, repeater], [repeater, box], [box, hand]]:
        state.circuit.link(pair[0], pair[1])

    # 신호가 끝까지 닿아 문이 열릴 때까지 돌린다. **닫힌 문 앞에 선 그림은
    # 아무것도 증명하지 못한다.** 회로가 한 일이 화면에 남아야 한다.
    for i in 24:
        _main.simulation.step()
        if state.grid.get_block(door) == BlockType.DOOR_OPEN:
            break
    _worked["17_store"] = (state.grid.get_block(door) == BlockType.DOOR_OPEN
        and state.grid.get_block(lamp) == BlockType.LAMP_LIT)
    _main.lamp_lights().look_at_point(_main.character_view().target_position())

    # 회로를 ㄷ자로 펴면서 차지하는 자리가 넓어졌다. 당겨 보면 아래 팔이
    # 화면 밖과 밑동 글줄에 잘린다. 회로 전체가 한 프레임에 들어와야
    # "저것이 하나로 도는 것"이 읽힌다.
    _main.camera().zoom_by(6)
    _main.camera().focus_on(_main.character_view().target_position()
        + SimViewCoords.cell_to_world(Vector3i(3, 1, 0))
        - SimViewCoords.cell_to_world(Vector3i.ZERO))
    _main.world_view().rebuild()
    _main.canopy_view().rebuild()
    _main.ground_cover().rebuild()
    # 배선을 다시 세워 신호 점이 출발점에서 새로 달리게 한다.
    _main.wire_view().rebuild()


## 무대에 부품 하나를 세운다. 재료를 세지 않는다. 그림을 위한 자리다.
func _put(cell: Vector3i, part_type: int, settings: PackedInt32Array) -> void:
    var state: Object = _main.simulation.state
    var part := CircuitPartFactory.create(part_type, cell, settings)
    if part == null:
        return
    state.grid.set_block(cell, part_type)
    state.circuit.add_part(part)


## 땅을 파고 내려가 등을 켠다.
##
## 지하가 대낮처럼 밝으면 파고 내려가는 일이 아무 느낌이 없고 등을 만들
## 이유도 없다. 어두운지, 그리고 등이 실제로 밝히는지 본다.
##
## **널찍한 방을 파고 찍고 있었다.** 아홉 칸 사방을 통째로 비우면 그 안의
## 광맥까지 지워져서, 파고 내려온 보람이 화면에 남지 않는 빈 회색 방이
## 나왔다. 좁은 굴을 뚫는다 — 벽이 생성기가 만든 그대로 남아야 거기 박힌
## 광석이 보이고, 그래야 자기가 만든 지형을 검증하는 그림이 된다.
func _dig_down() -> void:
    _main.simulation = IslandBuilder.start(GameMain.SEED)
    _main.adopt_simulation()
    _main.first_steps().silence()
    _main.notice().visible = false

    var state: Object = _main.simulation.state
    var here: Vector3i = state.character.cell()

    # 좁은 굴을 뚫는다. 위가 뚫려 있으면 볕이 들어 어둠이 보이지 않으므로
    # 지붕은 남겨 둔다.
    var floor_z: int = VoxelGrid.BEDROCK_Z + 1
    for dy in range(-5, 6):
        for dx in range(-1, 2):
            for z in range(floor_z, floor_z + 3):
                state.grid.set_block(Vector3i(here.x + dx, here.y + dy, z), BlockType.EMPTY)
    # 갈래 하나를 옆으로 낸다. 굴이 이어진다는 것이 보여야 한다.
    for dx in range(-5, 2):
        for z in range(floor_z, floor_z + 3):
            state.grid.set_block(Vector3i(here.x + dx, here.y + 2, z), BlockType.EMPTY)

    var bottom := Vector3i(here.x, here.y, floor_z)
    state.character.place_at(bottom)
    _main.character_view().snap()
    _main.camera().focus_on(_main.character_view().target_position())

    # 등을 켠다. 작동기가 켜는 것과 같은 결과다.
    for offset in [Vector3i(0, -3, 0), Vector3i(-4, 2, 0)]:
        state.grid.set_block(bottom + offset, BlockType.LAMP_LIT)
    # **관솔불도 함께 놓는다.** 첫 굴의 빛은 등이 아니라 이쪽이다 — 등은
    # 광석이 들고 광석은 돌 곡괭이가 있어야 캐는데, 파고 내려오기 시작하는
    # 것은 나무 곡괭이일 때다. 굴 그림에 그것이 없으면 새로 넣은 단이
    # 열일곱 장 어디에도 나오지 않는다.
    for offset in [Vector3i(0, 3, 0), Vector3i(0, 1, 0)]:
        state.grid.set_block(bottom + offset, BlockType.TORCH)

    _fill_the_hand()
    _main.input_controller().select_block(BlockType.TORCH)
    _ore_in_sight = _count_ore_on_the_walls(bottom)

    _main.camera().zoom_by(-4)
    _main.world_view().rebuild()
    _main.lamp_lights().look_at_point(_main.character_view().target_position())
    _main.lamp_lights().sync()


## 뚫은 굴의 벽에 광석이 몇 칸이나 드러나 있는가.
##
## 스펙 §3.1 이 "벽에 박힌 광석이 눈에 걸려야 그것이 목적지가 된다"고 적었다.
## 하나도 없으면 파고 내려온 보람이 화면에 없는 것이다.
func _count_ore_on_the_walls(bottom: Vector3i) -> int:
    var grid: Object = _main.simulation.state.grid
    var found := 0
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            for dz in range(0, 4):
                var cell := bottom + Vector3i(dx, dy, dz)
                if grid.get_block(cell) != BlockType.ORE:
                    continue
                for step: Vector3i in VoxelGrid.NEIGHBOURS:
                    if grid.get_block(cell + step) == BlockType.EMPTY:
                        found += 1
                        break
    return found


## 가진 것을 펼쳐 보고 궤짝을 열어 본다.
##
## 손이 모자라야 왕복에 값이 붙고(스펙 §3.6), 넣어 둘 곳이 있어야
## 그것이 짜증이 아니라 살림이 된다.
func _open_the_bag() -> void:
    _main.simulation = IslandBuilder.start(GameMain.SEED)
    _main.adopt_simulation()
    _main.first_steps().silence()
    _main.notice().visible = false

    var state: Object = _main.simulation.state
    var here: Vector3i = state.character.cell()
    var spot := here + Vector3i(1, 0, 0)
    for z in range(here.z, VoxelGrid.SIZE_Z):
        state.grid.set_block(Vector3i(spot.x, spot.y, z), BlockType.EMPTY)
    state.grid.set_block(spot - VoxelGrid.UP, BlockType.GROUND)

    # 손에 이것저것 채워 넣고 궤짝을 하나 놓는다.
    for pair in [
        [BlockType.GROUND, 64], [BlockType.ROCK, 37], [BlockType.WOOD, 22],
        [BlockType.ORE, 15], [BlockType.LAMP_DARK, 6], [BlockType.DOOR_CLOSED, 3],
        [BlockType.DETECTOR, 2], [BlockType.CROP, 9],
    ]:
        state.inventory.add(int(pair[0]), int(pair[1]))
    state.chests.place(spot)
    state.grid.set_block(spot, BlockType.CHEST)
    state.chests.inside(spot).add(BlockType.ORE, 48)
    state.chests.inside(spot).add(BlockType.WOOD, 31)

    _main.open_chest(spot)
    _main.world_view().rebuild()


func _begin_step() -> void:
    var action: Callable = _steps[_index][1]
    action.call()
    _wait = SETTLE_FRAMES
    _phase = 1


func _tick_wait() -> bool:
    _wait -= 1
    return _wait <= 0


func _capture() -> Image:
    var texture := root.get_texture()
    if texture == null:
        return null
    return texture.get_image()


func _evaluate(without_subject: Image) -> void:
    var name: String = _steps[_index][0]

    if _with_subject == null or without_subject == null:
        _fail(name, "화면을 캡처하지 못했다. 렌더링 드라이버를 확인할 것")
        return

    # 자동문을 세운 단계들은 그 문이 열려 있어야 한다. 감지기가 사람을 보고
    # 작동기가 문을 여는 것이 스펙 §5 의 첫 장치다.
    var state: Object = _main.simulation.state
    match name:
        "08_auto_door":
            _worked[name] = state.grid.get_block(_door_cell) == BlockType.DOOR_OPEN
        "09_lamp":
            _worked[name] = (not _lamp_cells.is_empty()
                and state.grid.get_block(_lamp_cells[0]) == BlockType.LAMP_LIT)
        "10_farm":
            # 거둔 것이 손에 들어왔으면 회로가 실제로 돈 것이다.
            _worked[name] = state.inventory.count_of(BlockType.CROP) > 0

    var path := "%s/%s.png" % [OUT_DIR, name]
    _with_subject.save_png(path)

    var problems := ScreenshotCheck.problems(_with_subject)
    for problem in problems:
        _fail(name, problem)

    if not COVERED_STEPS.has(name) and not ScreenshotCheck.subject_visible(
        _with_subject, without_subject, _subject_rect()):
        _fail(name, "캐릭터가 있어야 할 자리에 아무것도 그려지지 않았다")

    # 밀려나 보이지 않는 칸이 있으면 무엇을 눌러야 하는지 알 수 없다.
    if not _main.hotbar().all_slots_visible():
        _fail(name, "핫바 %d칸 중 화면 밖으로 밀려난 것이 있다" % _main.hotbar().slot_count())
    if not _main.part_hint().fully_visible():
        _fail(name, "부품 설명이 화면 밖으로 밀려났다")
    if not _main.part_hint().is_single_line():
        _fail(name, "부품 설명이 가로 한 줄이 아니다")

    # 회로를 보이는 단계는 회로가 한 일도 함께 보여야 한다.
    # 닫힌 문 앞에 선 그림은 아무것도 증명하지 못한다.
    if _worked.has(name) and not _worked[name]:
        _fail(name, "회로가 한 일이 화면에 없다. 죽은 회로를 찍고 있다")

    # 파고 내려온 보람이 화면에 있어야 한다. 벽이 회색뿐이면 갈 까닭이 없다.
    if name == "15_underground" and _ore_in_sight <= 0:
        _fail(name, "굴 벽에 드러난 광석이 없다. 파고 내려올 까닭이 화면에 없다")

    # 만든 것이 세상에 서 있어야 한다. 손에 잡히는 줄의 숫자만 바뀌면
    # 화면에서는 아무 일도 일어나지 않은 것이다.
    if name == "14_craft" and _made_by_hand <= 0:
        _fail(name, "만든 것이 화면에 없다. 숫자만 바뀌었다")

    if problems.is_empty():
        _report.append("  OK   %s  (색 %d종, 밝기 %.2f, 어둠 %.2f)" % [
            name,
            ScreenshotCheck.distinct_colours(_with_subject),
            ScreenshotCheck.average_luminance(_with_subject),
            _main.sky_view().darkness(),
        ])


## 캐릭터가 화면 어디에 있어야 하는지 계산해 그 둘레만 본다.
##
## 상자는 시점을 당긴 만큼 함께 줄인다. 멀리 물러나면 캐릭터가 작아지는데
## 상자가 그대로면 빈 땅만 잔뜩 세게 되어 "안 그려졌다"고 잘못 판정한다.
func _subject_rect() -> Rect2i:
    var camera := _main.camera()
    var centre := camera.unproject_position(_main.character_view().target_position())
    var scale := IsometricCamera.DEFAULT_VIEW_SIZE / camera.view_size()
    var box := Vector2i(Vector2(SUBJECT_BOX) * scale).maxi(16)
    return Rect2i(Vector2i(centre) - box / 2, box)


func _fail(step_name: String, reason: String) -> void:
    _failures += 1
    _report.append("  FAIL %s  %s" % [step_name, reason])


func _finish() -> bool:
    var lines := PackedStringArray(["스크린샷 검증 결과"])
    lines.append_array(_report)
    lines.append("총 %d단계, 이상 %d건" % [_steps.size(), _failures])

    var text := "\n".join(lines)
    print(text)

    var file := FileAccess.open("%s/REPORT.txt" % OUT_DIR, FileAccess.WRITE)
    if file != null:
        file.store_string(text + "\n")
        file.close()

    quit(1 if _failures > 0 else 0)
    return true
