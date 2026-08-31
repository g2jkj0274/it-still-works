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

const SKY_COLOUR := Color(0.63, 0.80, 0.90)
const AMBIENT_COLOUR := Color(0.78, 0.82, 0.90)

var simulation: Simulation
var driver: TickDriver

var _world_view: WorldView
var _character_view: CharacterView
var _camera: IsometricCamera
var _highlight: BlockHighlight
var _input: InputController
var _wire_view: WireView
var _hotbar: Hotbar
var _last_usec: int = 0


func _ready() -> void:
    simulation = Simulation.new(SEED)
    IslandBuilder.populate(simulation.state)
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


func hotbar() -> Hotbar:
    return _hotbar


func wire_view() -> WireView:
    return _wire_view


## 시뮬레이션 상태를 읽어 화면을 맞춘다. 시뮬레이션은 건드리지 않는다.
func sync_views() -> void:
    _world_view.sync()
    _character_view.sync(CHARACTER_FOLLOW)
    _wire_view.sync()
    _hotbar.sync()
    _camera.follow(_character_view.target_position(), CAMERA_FOLLOW)


func input_controller() -> InputController:
    return _input


func world_view() -> WorldView:
    return _world_view


func character_view() -> CharacterView:
    return _character_view


func camera() -> IsometricCamera:
    return _camera


func _build_environment() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = SKY_COLOUR
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = AMBIENT_COLOUR
    environment.ambient_light_energy = 0.7

    var holder := WorldEnvironment.new()
    holder.name = "Environment"
    holder.environment = environment
    add_child(holder)

    var light := DirectionalLight3D.new()
    light.name = "Sun"
    light.rotation_degrees = Vector3(-55.0, -40.0, 0.0)
    light.light_energy = 1.1
    add_child(light)


func _build_views() -> void:
    _world_view = WorldView.new()
    _world_view.name = "WorldView"
    add_child(_world_view)
    _world_view.bind(simulation.state.grid)
    _world_view.rebuild()

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

    _camera = IsometricCamera.new()
    _camera.name = "Camera"
    add_child(_camera)
    _camera.focus_on(_character_view.target_position())
    _camera.make_current()

    _highlight = BlockHighlight.new()
    _highlight.name = "Highlight"
    add_child(_highlight)


func _build_input() -> void:
    InputController.install_actions()
    _input = InputController.new()
    _input.name = "Input"
    add_child(_input)
    _input.bind(simulation)

    _hotbar = Hotbar.new()
    _hotbar.name = "Hotbar"
    add_child(_hotbar)
    _hotbar.bind(simulation.state.inventory, _input)
    _hotbar.sync()


func _build_hint() -> void:
    var label := Label.new()
    label.name = "Hint"
    label.text = "이동  W A S D
마우스로 결령
놓기  E
부수기  Q
재료  1 흙  2 돌  3 나무  4 문  5 눈  6 손  7 되풀이  8 상자
잎기  R 두 번
눈이 볼 것  T"
    label.position = Vector2(16, 16)
    label.add_theme_color_override("font_color", Color(0.15, 0.18, 0.22))

    var layer := CanvasLayer.new()
    layer.name = "Hud"
    layer.add_child(label)
    add_child(layer)
