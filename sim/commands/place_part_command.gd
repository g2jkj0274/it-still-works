class_name PlacePartCommand
extends SimCommand

## 회로 부품을 놓는다.
##
## 부품도 블록이라 격자 한 칸을 차지한다. 다만 회로에 등록해야 하므로 지형
## 블록과는 다른 명령을 쓴다.
##
## 부품의 설정은 놓을 때 정한다. 놓고 나서 바꾸지 못한다. 설정값의 뜻은
## 부품마다 다르다. 감지기는 무엇을 볼지, 되풀이는 어떻게 돌지, 묶음은 어느
## 설계도인지다.

const TYPE := &"place_part"

var position: Vector3i = Vector3i.ZERO
var part_type: int = BlockType.DETECTOR
var settings: PackedInt32Array = PackedInt32Array()


static func create(p_position: Vector3i, p_part_type: int, p_settings: PackedInt32Array = PackedInt32Array()) -> PlacePartCommand:
    var command := PlacePartCommand.new()
    command.position = p_position
    command.part_type = p_part_type
    command.settings = p_settings
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    if not BlockType.is_part(part_type):
        return
    if not state.grid.is_empty_cell(position):
        return
    if state.character.occupies(position):
        return
    if not _has_solid_neighbour(state.grid):
        return
    if state.circuit.has_part(position):
        return

    var part := CircuitPartFactory.create(part_type, position, settings, state.bundles)
    if part == null:
        return
    if not _pay(state, part):
        return

    state.grid.set_block(position, part_type)
    state.circuit.add_part(part)


## 손에 든 것에서 하나를 뺀다. 묶음은 번호마다 따로 센다.
func _pay(state: WorldState, part: CircuitPart) -> bool:
    if part is BundlePart:
        return state.inventory.take_bundle((part as BundlePart).bundle_id, 1)
    return state.inventory.take(part_type, 1)


func _has_solid_neighbour(grid: VoxelGrid) -> bool:
    for offset in VoxelGrid.NEIGHBOURS:
        if grid.is_solid(position + offset):
            return true
    return false


func write_payload(data: Dictionary) -> void:
    data["pos"] = [position.x, position.y, position.z]
    data["part"] = part_type
    data["settings"] = Array(settings)


func read_payload(data: Dictionary) -> void:
    var raw: Array = data.get("pos", [0, 0, 0])
    position = Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
    part_type = int(data.get("part", BlockType.DETECTOR))

    var raw_settings: Array = data.get("settings", [])
    settings = PackedInt32Array()
    for value in raw_settings:
        settings.append(int(value))
