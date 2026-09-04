class_name GameMain
extends Node3D

## 게임 진입점. 시뮬레이션을 소유하고 표현 레이어를 붙인다.
##
## 시뮬레이션 갱신은 _process 에서 하지 않는다. 고정 간격으로 불리는
## _physics_process 안에서 TickDriver 가 모은 만큼만 진행한다.
## 경과 시간은 정수 마이크로초로 재므로 실수가 시뮬레이션 쪽으로 새지 않는다.
##
## 표현 레이어는 시뮬레이션을 읽기만 한다. 입력은 명령을 만들어 큐에 넣는다.

const SEED := 20250901

## 캐릭터와 카메라가 목표를 따라가는 정도. 표현일 뿐 시뮬레이션과 무관하다.
const CHARACTER_FOLLOW := 0.25
const CAMERA_FOLLOW := 0.12

## 마우스 광선을 따라갈 거리. 직교 카메라가 멀리 있어 넭넉히 잡는다.
const RAY_DISTANCE := 300.0

var simulation: Simulation
var driver: TickDriver

var _world_view: WorldView
var _ground_cover: GroundCover
var _canopy_view: CanopyView
var _lamp_lights: LampLights
var _character_view: CharacterView
var _camera: IsometricCamera
var _highlight: BlockHighlight
var _bundle_marks: BundleMarks
var _input: InputController
var _wire_view: WireView
var _part_marks: PartMarks
var _sky_view: SkyView
var _sea_view: SeaView
var _threat_view: ThreatView
var _vitals_bar: VitalsBar
var _day_clock: DayClock
var _part_hint: PartHint
var _help_overlay: HelpOverlay
var _hotbar: Hotbar
var _notice: Notice
var _first_steps: FirstSteps
var _sound_board: SoundBoard
var _last_usec: int = 0


func _ready() -> void:
    simulation = IslandBuilder.start(SEED)
    driver = TickDriver.new()

    _build_environment()
    _build_views()
    _build_input()
    _build_hint()

    _last_usec = Time.get_ticks_usec()


func _physics_process(_delta: float) -> void:
    var now := Time.get_ticks_usec()
    var elapsed := now - _last_usec
    _last_usec = now

    update_target()
    _input.poll(simulation.current_tick())
    simulation.advance(driver.pump(elapsed))
    sync_views()


## 마우스가 가리키는 칸을 찾아 입력과 강조 표시에 알린다.
func update_target() -> void:
    var target := pick_target()
    if target != null and target.is_usable(simulation.state.character.cell()):
        _input.set_target(target)
        _highlight.show_cell(target.cell)
        return
    _input.clear_target()
    _highlight.clear()


## 화면의 [param screen_position] (기본값은 마우스 자리)에서 격자로 광선을 줏다.
func pick_target(screen_position: Vector2 = Vector2(-1, -1)) -> BlockTarget:
    var viewport := get_viewport()
    if viewport == null:
        return null

    var point := screen_position
    if point.x < 0.0:
        point = viewport.get_mouse_position()

    var origin := SimViewCoords.world_to_grid_point(_camera.project_ray_origin(point))
    var direction := SimViewCoords.world_to_grid_direction(_camera.project_ray_normal(point))
    return BlockTarget.raycast(simulation.state.grid, origin, direction, RAY_DISTANCE)


func block_highlight() -> BlockHighlight:
    return _highlight


func bundle_marks() -> BundleMarks:
    return _bundle_marks


func hotbar() -> Hotbar:
    return _hotbar


func wire_view() -> WireView:
    return _wire_view


func part_marks() -> PartMarks:
    return _part_marks


func sky_view() -> SkyView:
    return _sky_view


func sea_view() -> SeaView:
    return _sea_view


func threat_view() -> ThreatView:
    return _threat_view


func vitals_bar() -> VitalsBar:
    return _vitals_bar


func day_clock() -> DayClock:
    return _day_clock


func part_hint() -> PartHint:
    return _part_hint


func help_overlay() -> HelpOverlay:
    return _help_overlay


## 시뮬레이션 상태를 읽어 화면을 맞춘다. 시뮬레이션은 건드리지 않는다.
func sync_views() -> void:
    var eye := simulation.state.character.cell()
    _world_view.look_from(eye)
    _world_view.sync()
    _ground_cover.cut_above(eye.z, _world_view.is_cutting())
    _ground_cover.sync()
    _canopy_view.cut_above(eye.z, _world_view.is_cutting())
    _canopy_view.sync()
    _lamp_lights.look_at_point(_character_view.target_position())
    _lamp_lights.sync()
    _character_view.sync(CHARACTER_FOLLOW)
    _wire_view.sync()
    _part_marks.sync()
    _bundle_marks.sync()
    _threat_view.sync()
    _sky_view.apply(simulation.current_tick())
    _day_clock.apply(simulation.current_tick())
    _hotbar.sync()
    _part_hint.sync()
    _vitals_bar.sync()
    _camera.follow(_character_view.target_position(), CAMERA_FOLLOW)
    _sound_board.forget()
    _sound_board.sync()
    _first_steps.check()


func input_controller() -> InputController:
    return _input


func world_view() -> WorldView:
    return _world_view


func ground_cover() -> GroundCover:
    return _ground_cover


func canopy_view() -> CanopyView:
    return _canopy_view


func lamp_lights() -> LampLights:
    return _lamp_lights


func character_view() -> CharacterView:
    return _character_view


func camera() -> IsometricCamera:
    return _camera


func _build_environment() -> void:
    _sky_view = SkyView.new()
    _sky_view.name = "Sky"
    add_child(_sky_view)

    _sea_view = SeaView.new()
    _sea_view.name = "Sea"
    add_child(_sea_view)


func _build_views() -> void:
    _world_view = WorldView.new()
    _world_view.name = "WorldView"
    add_child(_world_view)
    _world_view.bind(simulation.state.grid)
    _world_view.rebuild()

    _ground_cover = GroundCover.new()
    _ground_cover.name = "GroundCover"
    add_child(_ground_cover)
    _ground_cover.bind(simulation.state.grid)
    _ground_cover.rebuild()

    _canopy_view = CanopyView.new()
    _canopy_view.name = "CanopyView"
    add_child(_canopy_view)
    _canopy_view.bind(simulation.state.grid)
    _canopy_view.rebuild()

    _lamp_lights = LampLights.new()
    _lamp_lights.name = "LampLights"
    add_child(_lamp_lights)
    _lamp_lights.bind(simulation.state.grid)

    _character_view = CharacterView.new()
    _character_view.name = "CharacterView"
    add_child(_character_view)
    _character_view.bind(simulation.state.character)
    _character_view.snap()

    _wire_view = WireView.new()
    _wire_view.name = "WireView"
    add_child(_wire_view)
    _wire_view.bind(simulation.state.circuit)
    _wire_view.rebuild()

    _part_marks = PartMarks.new()
    _part_marks.name = "PartMarks"
    add_child(_part_marks)
    _part_marks.bind(simulation.state.circuit)
    _part_marks.rebuild()

    _threat_view = ThreatView.new()
    _threat_view.name = "ThreatView"
    add_child(_threat_view)
    _threat_view.bind(simulation.state.threats)

    _camera = IsometricCamera.new()
    _camera.name = "Camera"
    add_child(_camera)
    _camera.focus_on(_character_view.target_position())
    _camera.make_current()

    _highlight = BlockHighlight.new()
    _highlight.name = "Highlight"
    add_child(_highlight)

    _bundle_marks = BundleMarks.new()
    _bundle_marks.name = "BundleMarks"
    add_child(_bundle_marks)


func _build_input() -> void:
    # 소리판을 먼저 세운다. 입력이 붙는 신호가 이것을 부른다.
    _sound_board = SoundBoard.new()
    _sound_board.name = "SoundBoard"
    add_child(_sound_board)
    _sound_board.bind(simulation)

    InputController.install_actions()
    _input = InputController.new()
    _input.name = "Input"
    add_child(_input)
    _input.bind(simulation)
    _input.bind_camera(_camera)
    _bundle_marks.bind(_input)
    _input.help_toggled.connect(_on_help_toggled)
    _input.crafted.connect(_sound_board.note_crafted)
    _input.save_requested.connect(save_game)
    _input.load_requested.connect(load_game)

    _hotbar = Hotbar.new()
    _hotbar.name = "Hotbar"
    add_child(_hotbar)
    _hotbar.bind(simulation.state.inventory, _input)
    _hotbar.sync()

    _vitals_bar = VitalsBar.new()
    _vitals_bar.name = "Vitals"
    add_child(_vitals_bar)
    _vitals_bar.bind(simulation.state.vitals)
    _vitals_bar.sync()

    _day_clock = DayClock.new()
    _day_clock.name = "DayClock"
    add_child(_day_clock)
    _day_clock.apply(simulation.current_tick())

    _part_hint = PartHint.new()
    _part_hint.name = "PartHint"
    add_child(_part_hint)
    _part_hint.bind(_input)
    _part_hint.sync()


## 조작 안내는 기본으로 숨긴다. H 로 켜고 끈다.
func _build_hint() -> void:
    _help_overlay = HelpOverlay.new()
    _help_overlay.name = "Help"
    add_child(_help_overlay)
    _help_overlay.set_shown(_input.help_shown())

    _notice = Notice.new()
    _notice.name = "Notice"
    add_child(_notice)

    _first_steps = FirstSteps.new()
    _first_steps.name = "FirstSteps"
    add_child(_first_steps)
    _first_steps.bind(simulation, _notice)
    _sound_board.bind(simulation)


func notice() -> Notice:
    return _notice


func first_steps() -> FirstSteps:
    return _first_steps


func sound_board() -> SoundBoard:
    return _sound_board


## 판을 적어 둔다. 명령을 만지는 일이 아니라 파일을 만지는 일이라 여기서 한다.
func save_game() -> bool:
    var saved := SaveSlot.save(simulation)
    _notice.say("적어 두었다" if saved else "적어 두지 못했다")
    return saved


## 적어 둔 판을 되살린다. 없거나 읽을 수 없으면 지금 판을 그대로 둔다.
func load_game() -> bool:
    var restored := SaveSlot.restore()
    if restored == null:
        _notice.say("적어 둔 판이 없다")
        return false

    simulation = restored
    adopt_simulation()
    _notice.say("불러왔다")
    return true


## 표현 레이어를 새 판에 다시 붙인다.
##
## 붙이는 곳을 한 군데로 모아 둔다. 빠뜨린 것이 하나라도 있으면 화면이 옛 판을
## 계속 읽어 실제와 어긋난다.
func adopt_simulation() -> void:
    var state := simulation.state

    _world_view.bind(state.grid)
    _world_view.rebuild()
    _ground_cover.bind(state.grid)
    _ground_cover.rebuild()
    _canopy_view.bind(state.grid)
    _canopy_view.rebuild()
    _lamp_lights.bind(state.grid)

    _character_view.bind(state.character)
    _character_view.snap()

    _wire_view.bind(state.circuit)
    _wire_view.rebuild()
    _part_marks.bind(state.circuit)
    _part_marks.rebuild()
    _threat_view.bind(state.threats)
    _vitals_bar.bind(state.vitals)

    _first_steps.bind(simulation, _notice)
    _sound_board.bind(simulation)
    _input.bind(simulation)
    _input.clear_chosen()
    _input.clear_link_source()
    _hotbar.bind(state.inventory, _input)

    _camera.focus_on(_character_view.target_position())
    sync_views()


func _on_help_toggled(shown: bool) -> void:
    _help_overlay.set_shown(shown)
