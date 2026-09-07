class_name GameMain
extends Node2D

## 게임 진입점. 시뮬레이션을 소유하고 고정 틱으로 굴린다.
##
## 시뮬레이션 갱신은 _process 에서 하지 않는다. 고정 간격으로 불리는
## _physics_process 안에서 TickDriver 가 모은 만큼만 진행한다.
## 경과 시간은 정수 마이크로초로 재므로 실수가 시뮬레이션 쪽으로 새지 않는다.
##
## 표현 레이어는 시뮬레이션을 읽기만 한다. 입력은 명령을 제출할 뿐 상태를 직접 만지지 않는다
## (SIM_ORDER 1). 방향키 한 번 누름 = MovePlayerCommand 하나(한 칸). 로드 중심은 플레이어 발 칸에서
## sim 이 유도하므로 view 는 첫 틱에 아무 명령도 내지 않는다(DECISIONS 2026-09-08). 키 → 방향은
## 화면 기준이다: 아이소 투영에서 +x 는 우하, +y 는 좌하이므로 화면 위 = (-1,-1), 아래 = (1,1),
## 왼쪽 = (-1,1), 오른쪽 = (1,-1). 활성 층은 카메라와 같은 표현 상태라 sim 에 쓰지 않는다.
## 키 누름 유지·카메라의 플레이어 추적·플레이어 마커는 M1-6b.

const SEED := 20250901

## _unhandled_input 이 판정하는 액션. 순서는 판정 순서.
const ACTIONS: Array[StringName] = [
    &"layer_up", &"layer_down",
    &"move_left", &"move_right", &"move_up", &"move_down",
]

var simulation: Simulation
var driver: TickDriver
var _last_usec: int = 0

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
    # 첫 틱이 플레이어 발 칸의 청크를 로드한다. view 는 여기서 아무 명령도 내지 않는다.
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
        _submit_move(-1, 1)
    elif action == &"move_right":
        _submit_move(1, -1)
    elif action == &"move_up":
        _submit_move(-1, -1)
    elif action == &"move_down":
        _submit_move(1, 1)


## 플레이어를 (dx, dy) 방향으로 한 칸 걷게 하는 명령을 제출한다. 상태는 직접 쓰지 않는다.
func _submit_move(dx: int, dy: int) -> void:
    simulation.submit(MovePlayerCommand.create(dx, dy))


## 카메라를 로드 중심 셀의 다이아몬드 중심에 놓는다.
func _update_camera() -> void:
    var focus := world_view.focus_cell()
    camera.position = IsoProjection.cell_center(focus.x, focus.y)
