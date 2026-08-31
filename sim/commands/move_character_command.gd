class_name MoveCharacterCommand
extends SimCommand

## 캐릭터를 한 칸 옮긴다. 이동은 오직 이 명령을 통해서만 일어난다.

const TYPE := &"move_character"

var direction: Vector3i = Vector3i.ZERO


static func create(p_direction: Vector3i) -> MoveCharacterCommand:
    var command := MoveCharacterCommand.new()
    command.direction = p_direction
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    if not MovementRules.is_direction(direction):
        return

    # 갈 수 없어도 방향은 바뀐다. 제자리에서 돌아설 수 있어야 한다.
    state.character.facing = direction

    # 이미 걷는 중이면 새 걸음을 받지 않는다. 칸 경계에 정확히 서야 다음 판정이 맞는다.
    if state.character.is_moving():
        return

    var here := state.character.cell()
    var destination := MovementRules.resolve_walk(state.grid, here, direction)
    if destination == here:
        return
    state.character.walk_to(destination)


func write_payload(data: Dictionary) -> void:
    data["dir"] = [direction.x, direction.y, direction.z]


func read_payload(data: Dictionary) -> void:
    var raw: Array = data.get("dir", [0, 0, 0])
    direction = Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
