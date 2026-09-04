class_name WorldView
extends Node3D

## 복셀 격자를 그린다.
##
## 격자를 읽기만 한다. 여기서 격자를 고치면 표현이 시뮬레이션을 되돌아 밀게 되어
## 결정론이 깨진다.
##
## 속에 묻힌 블록은 그리지 않는다. 이웃 여섯 칸이 모두 단단하면 어차피 보이지 않는다.
## 종류마다 MultiMesh 하나를 써서 수천 칸을 한 번에 낸다.
##
## 생김새는 종류마다 다르다. [BlockMeshes] 가 정한다. 색만으로는 파스텔 열 종을
## 가르기 어렵고, 문은 열린 것과 닫힌 것이 아예 같은 색이다.
##
## **면의 색도 메시가 정한다.** 흙은 윗면이 풀이고 옆면이 흙이다. 그래서
## 여기서 인스턴스에 넘기는 것은 색이 아니라 칸마다의 명암 배수다.
##
## **바뀐 칸만 고친다.** 블록 하나를 놓을 때마다 격자 전체를 훑으면 육만 칸에
## 백 밀리초, 지하를 채우면 삼백 밀리초가 걸린다. 한 프레임이 십육 밀리초이니
## 놓을 때마다 화면이 멎는다. 격자가 어디가 달라졌는지 알려 주므로 그 일곱
## 칸씩만 다시 본다.

var _grid: VoxelGrid
var _layers: Dictionary[int, MultiMeshInstance3D] = {}

## 층마다 지금 그리고 있는 칸들. MultiMesh 의 인스턴스 번호와 나란히 간다.
var _drawn: Dictionary[int, Array] = {}

## 칸이 어느 층 몇 번째에 들어 있는가. [층 종류, 번호] 이고, 없으면 없다.
var _slot_of: Dictionary[Vector3i, Array] = {}

var _last_version: int = -1
var _build_count: int = 0
var _patch_count: int = 0


## 종류별 대표 색.
static func colour_of(block_type: int) -> Color:
    return Palette.of_block(block_type)


func _ready() -> void:
    for block_type in BlockType.COUNT:
        if block_type == BlockType.EMPTY:
            continue
        _layers[block_type] = _make_layer(block_type)
        _drawn[block_type] = []


func bind(grid: VoxelGrid) -> void:
    _grid = grid
    _last_version = -1


## 격자가 바뀌었을 때만 손댄다.
func sync() -> void:
    if _grid == null or _grid.version() == _last_version:
        return

    if _grid.needs_full_redraw():
        rebuild()
        return
    patch(_grid.take_dirty())


## 격자 전체를 다시 훑어 그린다. 처음 한 번과, 한꺼번에 많이 바뀌었을 때만.
func rebuild() -> void:
    if _grid == null:
        return

    for block_type in _layers:
        _drawn[block_type] = []
    _slot_of.clear()

    for z in VoxelGrid.SIZE_Z:
        for y in VoxelGrid.SIZE_Y:
            for x in VoxelGrid.SIZE_X:
                var pos := Vector3i(x, y, z)
                var block_type := _grid.get_block(pos)
                if not _layers.has(block_type):
                    continue
                if not _grid.is_exposed(pos):
                    continue
                _drawn[block_type].append(pos)
                _slot_of[pos] = [block_type, _drawn[block_type].size() - 1]

    for block_type in _layers:
        _fill_layer(block_type)

    _grid.take_dirty()
    _last_version = _grid.version()
    _build_count += 1


## 달라진 칸들만 고친다.
func patch(changed: Array[Vector3i]) -> void:
    if _grid == null:
        return

    for pos in changed:
        var wanted := _grid.get_block(pos)
        if not _layers.has(wanted) or not _grid.is_exposed(pos):
            wanted = BlockType.EMPTY

        var slot: Array = _slot_of.get(pos, [])
        var drawn_as: int = slot[0] if not slot.is_empty() else BlockType.EMPTY
        if drawn_as == wanted:
            continue

        if drawn_as != BlockType.EMPTY:
            _forget(pos, drawn_as, int(slot[1]))
        if wanted != BlockType.EMPTY:
            _remember(pos, wanted)

    _last_version = _grid.version()
    _patch_count += 1


func instance_count(block_type: int) -> int:
    if not _layers.has(block_type):
        return 0
    return _layers[block_type].multimesh.instance_count


func total_instance_count() -> int:
    var total := 0
    for block_type in _layers:
        total += instance_count(block_type)
    return total


## 통째로 다시 그린 횟수. 테스트가 불필요한 재구축을 잡는 데 쓴다.
func build_count() -> int:
    return _build_count


## 바뀐 칸만 고친 횟수.
func patch_count() -> int:
    return _patch_count


## 그 층에서 한 칸을 지운다. 마지막 것을 그 자리로 옮겨 구멍을 메운다.
func _forget(pos: Vector3i, block_type: int, at: int) -> void:
    var cells: Array = _drawn[block_type]
    var last := cells.size() - 1
    if at != last:
        var moved: Vector3i = cells[last]
        cells[at] = moved
        _slot_of[moved] = [block_type, at]
        _write_instance(block_type, at, moved)

    cells.resize(last)
    _slot_of.erase(pos)
    _layers[block_type].multimesh.instance_count = last


func _remember(pos: Vector3i, block_type: int) -> void:
    var cells: Array = _drawn[block_type]
    cells.append(pos)
    var at := cells.size() - 1
    _slot_of[pos] = [block_type, at]
    _layers[block_type].multimesh.instance_count = cells.size()
    _write_instance(block_type, at, pos)


func _write_instance(block_type: int, at: int, cell: Vector3i) -> void:
    var multimesh := _layers[block_type].multimesh
    multimesh.set_instance_transform(at, Transform3D(Basis(), SimViewCoords.cell_to_world(cell)))
    # 칸마다 명암을 아주 조금 달리해 넓은 면이 한 덩어리로 보이지 않게 한다.
    # 색은 면이 정하므로(BlockMeshes) 여기서는 배수만 넘긴다.
    var shade := Palette.variation_of(cell)
    multimesh.set_instance_color(at, Color(shade, shade, shade))


func _make_layer(block_type: int) -> MultiMeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    # 칸의 색(인스턴스)과 면의 밝기(정점)가 곱해져 한 면의 색이 된다.
    material.vertex_color_use_as_albedo = true
    # 감는 방향이 어긋나도 안이 비쳐 보이지 않게 한다. 빛은 법선을 따른다.
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var mesh := BlockMeshes.for_block(block_type)
    mesh.surface_set_material(0, material)

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    var node := MultiMeshInstance3D.new()
    node.name = "Layer_" + BlockType.name_of(block_type)
    node.multimesh = multimesh
    add_child(node)
    return node


func _fill_layer(block_type: int) -> void:
    var cells: Array = _drawn[block_type]
    _layers[block_type].multimesh.instance_count = cells.size()
    for i in cells.size():
        _write_instance(block_type, i, cells[i])
