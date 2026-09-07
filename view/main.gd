class_name GameMain
extends Node2D

## 게임 진입점. 시뮬레이션을 소유하고 고정 틱으로 굴린다.
##
## 시뮬레이션 갱신은 _process 에서 하지 않는다. 고정 간격으로 불리는
## _physics_process 안에서 TickDriver 가 모은 만큼만 진행한다.
## 경과 시간은 정수 마이크로초로 재므로 실수가 시뮬레이션 쪽으로 새지 않는다.
##
## 표현 레이어는 시뮬레이션을 읽기만 한다. 입력은 명령을 제출할 뿐 상태를 직접 만지지 않는다
## (SIM_ORDER 1). 로드 중심은 플레이어 발 칸에서 sim 이 유도하므로 view 는 첫 틱에 아무 명령도
## 내지 않는다(DECISIONS 2026-09-08).
##
## 입력 둘:
##   - 층 전환(Q/E): 한 번 누름 = 한 번. _unhandled_input 이 받고 echo 는 버린다. view 상태다.
##   - 이동(방향키): 틱마다 눌린 방향 하나. _physics_process 가 틱마다 "제출 → step" 을 문자
##     그대로 돌린다 — 프레임 히치로 틱이 몰려도 끊기지 않는다. 걷는 중(player.is_moving, 읽기만)엔
##     제출하지 않으므로 명령 로그는 걷는 동안 4틱마다 1개다. 여러 키가 눌리면 MOVE_ACTIONS 순서의
##     첫 것 하나만 — 조합하지 않는다(대각선 합이 8방향 밖으로 나간다). 벽 쪽을 눌러도 제출은 된다.
##     view 는 판정을 모른다(DECISIONS 2026-09-08 "이동 입력은 틱마다 눌린 방향 하나").
## 키 → 방향은 화면 기준이다: 아이소 투영에서 +x 는 우하, +y 는 좌하이므로 화면 위 = (-1,-1),
## 아래 = (1,1), 왼쪽 = (-1,1), 오른쪽 = (1,-1). 활성 층은 카메라와 같은 표현 상태라 sim 에 쓰지
## 않는다. 카메라는 플레이어 발 위치(WorldView.focus_position)를 따르고, 활성 층은 틱마다
## 플레이어 층을 따라간다(WorldView.follow_player_layer).

const SEED := 20250901

## _unhandled_input 이 판정하는 액션. 순서는 판정 순서. 층 전환뿐 — 이동은 여기 없다.
const ACTIONS: Array[StringName] = [&"layer_up", &"layer_down"]

## 눌린 상태를 틱마다 읽는 이동 액션. 순서는 우선순위 — 동시에 눌리면 앞의 것 하나만.
const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]

## 이동 액션 → 격자 방향(화면 기준, iso +x 우하 +y 좌하).
const MOVE_DIRECTIONS: Dictionary = {
    &"move_up": Vector2i(-1, -1),
    &"move_down": Vector2i(1, 1),
    &"move_left": Vector2i(-1, 1),
    &"move_right": Vector2i(1, -1),
}

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
    world_view.follow_player_layer()
    _update_camera()
    get_tree().process_frame.connect(_on_process_frame)


func _physics_process(_delta: float) -> void:
    if simulation == null:
        return
    var now := Time.get_ticks_usec()
    var elapsed := now - _last_usec
    _last_usec = now
    var ticks := driver.pump(elapsed)
    # 틱마다 명령 하나를 문자 그대로: 눌린 방향을 제출하고 그 틱을 돌린다.
    for _i in ticks:
        _submit_held_move()
        simulation.step()
    if ticks > 0:
        _needs_refresh = true
        world_view.follow_player_layer()
        _update_camera()


## 프레임당 한 번. 물리 스텝이 몇 번 돌았든 다시 그리기는 한 번만 요청한다.
func _on_process_frame() -> void:
    if _needs_refresh:
        _needs_refresh = false
        world_view.refresh()


func _unhandled_input(event: InputEvent) -> void:
    # 층 전환은 한 번 누름 = 한 번. OS 키 반복률이 새지 않게 echo 는 버린다. 이동 키는 여기서
    # 보지 않는다 — 눌린 상태를 틱마다 읽는다(held_direction).
    if event.is_echo():
        return
    for action: StringName in ACTIONS:
        if event.is_action_pressed(action):
            handle_action(action)
            return


## 층 액션 하나를 처리한다. 테스트가 Input 이벤트 주입 없이 직접 부른다.
func handle_action(action: StringName) -> void:
    if simulation == null:
        return
    if action == &"layer_up":
        world_view.set_active_layer(world_view.active_layer + 1)
    elif action == &"layer_down":
        world_view.set_active_layer(world_view.active_layer - 1)


## 지금 눌린 이동 방향. MOVE_ACTIONS 순서로 첫 눌린 액션의 방향, 없으면 ZERO. 조합하지 않는다.
func held_direction() -> Vector2i:
    for action: StringName in MOVE_ACTIONS:
        if Input.is_action_pressed(action):
            return MOVE_DIRECTIONS[action]
    return Vector2i.ZERO


## 눌린 방향이 있고 플레이어가 걷는 중이 아니면 한 칸 걷기 명령을 제출한다. 상태는 읽기만 한다.
## 걸을 수 있는지는 묻지 않는다 — 판정은 sim 의 몫이라 벽 쪽 명령도 제출된다(facing 은 돈다).
func _submit_held_move() -> void:
    if simulation == null:
        return
    if simulation.state.player.is_moving():
        return
    var dir := held_direction()
    if dir == Vector2i.ZERO:
        return
    simulation.submit(MovePlayerCommand.create(dir.x, dir.y))


## 카메라를 플레이어 발 칸 다이아몬드 중심에 놓는다. 틱 사이 보간은 없다(부드러움은 M7 폴리시).
func _update_camera() -> void:
    camera.position = world_view.focus_position()
