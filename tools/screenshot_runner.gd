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
const TOGGLE_FRAMES := 3

## 캐릭터가 있어야 할 화면 영역의 크기(픽셀).
const SUBJECT_BOX := Vector2i(120, 160)

var _main: GameMain
var _steps: Array = []
var _index := 0
var _phase := 0
var _wait := 0
var _with_subject: Image
var _report: Array[String] = []
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


## 단계 목록. 각 항목은 [이름, 준비 동작] 이다.
func _build_steps() -> Array:
    return [
        ["01_spawn", func() -> void: pass],
        ["02_walk", _walk],
        ["03_gather", _gather],
        ["04_place", _place],
        ["05_break", _break],
        ["06_build_tower", _build_tower],
        ["07_auto_door", _build_auto_door],
        ["08_choose", _choose_the_auto_door],
        ["09_bundle", _bundle_the_auto_door],
        ["10_night", _fall_of_night],
        ["11_parts", _line_up_the_parts],
        ["12_island", _pull_back_to_the_shore],
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

    var here: Vector3i = state.character.cell()
    var door := here + Vector3i(2, 0, 0)
    var actuator := here + Vector3i(3, 0, 0)
    var detector := here + Vector3i(4, 0, 0)

    var start := _main.simulation.current_tick()
    _main.simulation.submit_at(PlaceBlockCommand.create(door, BlockType.DOOR_CLOSED), start)
    _main.simulation.submit_at(PlacePartCommand.create(actuator, BlockType.ACTUATOR), start + 2)
    _main.simulation.submit_at(
        PlacePartCommand.create(detector, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER])), start + 4)
    _main.simulation.submit_at(ConnectPartsCommand.create(detector, actuator), start + 6)


## 자동문을 이룬 두 부품을 고른다. 고른 표시가 화면에 나오는지 본다.
func _choose_the_auto_door() -> void:
    var controller := _main.input_controller()
    for cell in _auto_door_parts():
        controller.set_target(_target_at(cell))
        controller.toggle_chosen()
    # 마지막에 고른 칸을 값이 나가는 자리로 삼아 색이 갈리는지 본다.
    controller.cycle_role()
    controller.cycle_role()

    # 고른 칸이 실제로 표시되는지는 그림만 봐서는 가려질 수 있다. 수로 확인한다.
    _main.bundle_marks().sync()
    var marked := _main.bundle_marks().marked_count()
    if marked != _auto_door_parts().size():
        _fail("08_choose", "고른 칸 %d개 중 %d개만 표시됐다" % [
            _auto_door_parts().size(), marked])


## 고른 것을 묶어 한 칸에 다시 놓는다. 스펙 §4.3, §6 의 마지막 검증 단계다.
func _bundle_the_auto_door() -> void:
    var controller := _main.input_controller()
    var spot: Vector3i = _auto_door_parts()[0]

    controller.submit_bundle()
    _main.simulation.step()
    controller.refresh_held_bundle()
    controller.cycle_held_bundle()

    # 방금 비워진 작동기 자리에 그대로 놓는다. 문 옆이라 다시 여닫힌다.
    controller.set_target(_target_at(spot - VoxelGrid.UP))
    controller.submit_place()


## 07 단계가 놓은 작동기와 감지기의 자리.
func _auto_door_parts() -> Array[Vector3i]:
    var here: Vector3i = _main.simulation.state.character.cell()
    return [here + Vector3i(3, 0, 0), here + Vector3i(4, 0, 0)]


func _target_at(cell: Vector3i) -> BlockTarget:
    var target := BlockTarget.new()
    target.hit = true
    target.cell = cell
    target.normal = VoxelGrid.UP
    return target


## 밤으로 건너뛴다. 어두워지고 위협이 나오는지 본다.
func _fall_of_night() -> void:
    _main.simulation.advance(DayCycle.DAY_TICKS - _main.simulation.current_tick() + 20)


## 부품을 나란히 늘어놓고 가까이 본다.
##
## 파스텔은 폭이 좁아 색만으로는 종류가 흐려진다. 생김새로 갈리는지는 멀리서
## 보아서는 알 수 없으므로 이 단계만 카메라를 당긴다.
func _line_up_the_parts() -> void:
    var state: Object = _main.simulation.state
    var centre: Vector3i = state.character.cell() + Vector3i(2, -2, 0)

    # 낮으로 되돌린다. 밤 화면에서는 형태가 아니라 어둠이 보인다.
    state.tick = 0

    # 키 큰 것을 뒤에 둔다. 앞의 것이 뒤의 것을 가리면 견줄 수가 없다.
    var kinds: Array[int] = [
        BlockType.DOOR_CLOSED, BlockType.DOOR_OPEN, BlockType.DETECTOR,
        BlockType.ACTUATOR, BlockType.REPEATER, BlockType.BOX,
        BlockType.BRANCH, BlockType.BUNDLE, BlockType.FIELD,
    ]
    for i in kinds.size():
        var cell := centre + Vector3i(i % 3 - 1, i / 3 - 1, 0)
        state.grid.set_block(cell - VoxelGrid.UP, BlockType.GROUND)
        state.grid.set_block(cell, kinds[i])

    _main.camera().zoom_by(-20)
    _main.world_view().rebuild()


## 멀리 물러나 물가를 본다.
##
## 지금까지는 섬 끝이 허공으로 끊겨 어디가 뭍이고 어디가 바깥인지 알 수 없었다.
func _pull_back_to_the_shore() -> void:
    _main.camera().zoom_by(40)


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

    var path := "%s/%s.png" % [OUT_DIR, name]
    _with_subject.save_png(path)

    var problems := ScreenshotCheck.problems(_with_subject)
    for problem in problems:
        _fail(name, problem)

    if not ScreenshotCheck.subject_visible(_with_subject, without_subject, _subject_rect()):
        _fail(name, "캐릭터가 있어야 할 자리에 아무것도 그려지지 않았다")

    # 밀려나 보이지 않는 칸이 있으면 무엇을 눌러야 하는지 알 수 없다.
    if not _main.hotbar().all_slots_visible():
        _fail(name, "핫바 %d칸 중 화면 밖으로 밀려난 것이 있다" % _main.hotbar().slot_count())
    if not _main.part_hint().fully_visible():
        _fail(name, "부품 설명이 화면 밖으로 밀려났다")
    if not _main.part_hint().is_single_line():
        _fail(name, "부품 설명이 가로 한 줄이 아니다")

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
