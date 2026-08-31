class_name WorldView
extends Node3D

## 복셀 격자를 그린다.
##
## 격자를 읽기만 한다. 여기서 격자를 고치면 표현이 시뮬레이션을 되돌아 밀게 되어
## 결정론이 깨진다.
##
## 속에 묻힌 블록은 그리지 않는다. 이웃 여섯 칸이 모두 단단하면 어차피 보이지 않는다.
## 종류마다 MultiMesh 하나를 써서 수천 칸을 한 번에 낸다.

const _COLOURS: Dictionary[int, Color] = {
    BlockType.GROUND: Color(0.56, 0.78, 0.51),
    BlockType.STONE: Color(0.62, 0.67, 0.75),
    BlockType.WOOD: Color(0.76, 0.60, 0.44),
    BlockType.DOOR_CLOSED: Color(0.85, 0.66, 0.42),
    BlockType.DOOR_OPEN: Color(0.85, 0.66, 0.42, 0.30),
    BlockType.DETECTOR: Color(0.58, 0.74, 0.86),
    BlockType.ACTUATOR: Color(0.88, 0.66, 0.72),
    BlockType.REPEATER: Color(0.80, 0.80, 0.56),
}

var _grid: VoxelGrid
var _layers: Dictionary[int, MultiMeshInstance3D] = {}
var _last_version: int = -1
var _build_count: int = 0


## 종류별 대표 색. 프로토타입이므로 단색 프리미티브만 쓴다.
static func colour_of(block_type: int) -> Color:
    return _COLOURS.get(block_type, Color.MAGENTA)


func _ready() -> void:
    for block_type in _COLOURS:
        _layers[block_type] = _make_layer(block_type)


func bind(grid: VoxelGrid) -> void:
    _grid = grid
    _last_version = -1


## 격자가 바뀌었을 때만 다시 만든다.
func sync() -> void:
    if _grid == null or _grid.version() == _last_version:
        return
    rebuild()


func rebuild() -> void:
    if _grid == null:
        return

    var cells: Dictionary[int, Array] = {}
    for block_type in _layers:
        cells[block_type] = []

    for z in VoxelGrid.SIZE_Z:
        for y in VoxelGrid.SIZE_Y:
            for x in VoxelGrid.SIZE_X:
                var pos := Vector3i(x, y, z)
                var block_type := _grid.get_block(pos)
                if not cells.has(block_type):
                    continue
                if not _grid.is_exposed(pos):
                    continue
                cells[block_type].append(pos)

    for block_type in _layers:
        _fill_layer(_layers[block_type], cells[block_type])

    _last_version = _grid.version()
    _build_count += 1


func instance_count(block_type: int) -> int:
    if not _layers.has(block_type):
        return 0
    return _layers[block_type].multimesh.instance_count


func total_instance_count() -> int:
    var total := 0
    for block_type in _layers:
        total += instance_count(block_type)
    return total


## 다시 만든 횟수. 테스트가 불필요한 재구축을 잡는 데 쓴다.
func build_count() -> int:
    return _build_count


func _make_layer(block_type: int) -> MultiMeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = colour_of(block_type)

    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE * SimViewCoords.CELL_SIZE
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    var node := MultiMeshInstance3D.new()
    node.name = "Layer_" + BlockType.name_of(block_type)
    node.multimesh = multimesh
    add_child(node)
    return node


func _fill_layer(node: MultiMeshInstance3D, cells: Array) -> void:
    var multimesh := node.multimesh
    multimesh.instance_count = cells.size()
    for i in cells.size():
        var origin: Vector3 = SimViewCoords.cell_to_world(cells[i])
        multimesh.set_instance_transform(i, Transform3D(Basis(), origin))
