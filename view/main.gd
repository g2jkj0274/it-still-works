class_name GameMain
extends Node2D

## 게임 진입점. 시뮬레이션을 소유하고 고정 틱으로 굴린다.
##
## 시뮬레이션 갱신은 _process 에서 하지 않는다. 고정 간격으로 불리는
## _physics_process 안에서 TickDriver 가 모은 만큼만 진행한다.
## 경과 시간은 정수 마이크로초로 재므로 실수가 시뮬레이션 쪽으로 새지 않는다.
##
## 표현 레이어는 시뮬레이션을 읽기만 한다. 입력은 명령을 제출할 뿐 상태를 직접 만지지 않는다
## (SIM_ORDER 1). M1-5 까지 세계를 둘러보는 수단은 방향키 → SetLoadCenterCommand 하나다
## (DECISIONS 2026-09-07). 활성 층은 카메라와 같은 표현 상태라 sim 에 쓰지 않는다.

const SEED := 20250901

## _unhandled_input 이 판정하는 액션. 순서는 판정 순서.
const ACTIONS: Array[StringName] = [
    &"layer_up", &"layer_down",
    &"move_left", &"move_right", &"move_up", &"move_down",
]

var simulation: Simulation
var driver: TickDriver
var _last_usec: int = 0

## 마지막으로 제출한 로드 중심 목표(청크 좌표). 같은 틱 안에 여러 이동이 제출될 때
## `state.load_center` 는 아직 이전 값이므로, 누적은 이 값을 기준으로 한다.
var _pending_center: Vector2i = Vector2i.ZERO

## 이번 프레임에 다시 그려야 하는가. _physics_process 는 이 플래그만 세우고, 실제 refresh 는
## SceneTree.process_frame 에서 프레임당 최대 1회 한다. queue_redraw 를 물리 스텝 안에서 부르면
## SceneTree 가 물리 스텝마다 MessageQueue 를 flush 하므로 _draw 가 스텝 수만큼(최대 8회) 돈다.
var _needs_refresh: bool = false

@onready var world_view: WorldView = $WorldView
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
    simulation = Simulation.create_default(SEED)
    if simulation == null:
        push_error("Simulation.create_default 실패: data/blocks.json 또는 data/terrain.json 을 읽을 수 없다")
        return
    driver = TickDriver.new()
    world_view.simulation = simulation
    # 첫 틱에 세계가 뜬다. 제출은 한 번.
    _pending_center = Vector2i.ZERO
    simulation.submit(SetLoadCenterCommand.create(_pending_center.x, _pending_center.y))
    _last_usec = Time.get_ticks_usec()
    _update_camera()
    get_tree().process_frame.connect(_on_process_frame)


func _physics_process(_delta: float) -> void:
    if simulation == null:
        return
    var now := Time.get_ticks_usec()
    var elapsed := now - _last_usec
    _last_usec = now
    var ticks := driver.pump(elapsed)
    simulation.advance(ticks)
    if ticks > 0:
        _needs_refresh = true
        _update_camera()


## 프레임당 한 번. 물리 스텝이 몇 번 돌았든 다시 그리기는 한 번만 요청한다.
func _on_process_frame() -> void:
    if _needs_refresh:
        _needs_refresh = false
        world_view.refresh()


func _unhandled_input(event: InputEvent) -> void:
    # 한 번 누름 = 명령 하나. OS 키 반복률이 명령 로그에 새지 않게 echo 는 버린다.
    if event.is_echo():
        return
    for action: StringName in ACTIONS:
        if event.is_action_pressed(action):
            handle_action(action)
            return


## 액션 하나를 처리한다. 테스트가 Input 이벤트 주입 없이 직접 부른다.
func handle_action(action: StringName) -> void:
    if simulation == null:
        return
    if action == &"layer_up":
        world_view.set_active_layer(world_view.active_layer + 1)
    elif action == &"layer_down":
        world_view.set_active_layer(world_view.active_layer - 1)
    elif action == &"move_left":
        _submit_move(-1, 0)
    elif action == &"move_right":
        _submit_move(1, 0)
    elif action == &"move_up":
        _submit_move(0, -1)
    elif action == &"move_down":
        _submit_move(0, 1)


## 로드 중심 목표를 (dx, dy) 청크만큼 옮기는 명령을 제출한다. 상태는 직접 쓰지 않는다.
func _submit_move(dx: int, dy: int) -> void:
    _pending_center += Vector2i(dx, dy)
    simulation.submit(SetLoadCenterCommand.create(_pending_center.x, _pending_center.y))


## 카메라를 로드 중심 셀의 다이아몬드 중심에 놓는다.
func _update_camera() -> void:
    var focus := world_view.focus_cell()
    camera.position = IsoProjection.cell_center(focus.x, focus.y)
