class_name MovePlayerCommand
extends SimCommand

## 플레이어를 한 칸 걷게 한다 (M1-6a-2).
##
## 방향 (dx, dy) 는 8방향 중 하나여야 한다([MovementRules.DIRECTIONS]). 그 밖의 값(0,0 포함)은
## 아무것도 하지 않는다 — `create(0, 0)` 은 허용되는 no-op 이다.
##
## 순서:
##   1. facing 을 방향으로 돌린다. 걷기가 거부돼도 돌린다 — 벽 쪽을 보고 서야 M1-7 채집 목표가 된다.
##   2. 이미 걷는 중이면 무시한다. 이동은 한 칸 단위로 결정된다.
##   3. [MovementRules.resolve_walk] 가 목적지를 정한다. 제자리면 거부.
##
## 청크 로드·언로드는 하지 않는다. 로드 중심은 Simulation.step() 이 플레이어 발 칸에서 유도한다
## (SIM_ORDER 1-M1b). 첫 틱(tick 0)에는 로드 집합이 비어 모든 걷기가 거부된다 — 버그가 아니다.

const TYPE := &"move_player"

var dx: int = 0
var dy: int = 0


static func create(p_dx: int, p_dy: int) -> MovePlayerCommand:
    var command := MovePlayerCommand.new()
    command.dx = p_dx
    command.dy = p_dy
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    var dir := Vector2i(dx, dy)
    if not MovementRules.is_direction(dir):
        return
    state.player.facing = dir
    if state.player.is_moving():
        return
    var feet := state.player.cell()
    var dest := MovementRules.resolve_walk(state.chunks, state.registry, feet, state.player.layer, dir)
    if dest != feet:
        state.player.walk_to(dest)


func write_payload(data: Dictionary) -> void:
    data["dx"] = dx
    data["dy"] = dy


func read_payload(data: Dictionary) -> void:
    dx = int(data.get("dx", 0))
    dy = int(data.get("dy", 0))
