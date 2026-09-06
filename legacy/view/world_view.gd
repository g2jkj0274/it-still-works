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
## **지붕 아래에 들어가면 머리 위 층을 걷어낸다.** 고정 아이소메트릭에서는
## 지붕이 있으면 그 아래가 통째로 가려진다. 걷어내지 않으면 지하는 있어도
## 볼 수가 없고, 파고 내려가는 일이 성립하지 않는다.
##
## 머리 위가 트여 있으면 그대로 둔다. 늘 걷어내면 제가 세운 건물이 사라진다.
##
## **땅속은 어둡다.** 지표에서 멀어질수록 칸이 어둡게 그려진다. 대낮처럼 밝으면
## 파고 내려가는 일이 아무 느낌이 없다.
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

## 칸 수가 늘 때 한 번에 잡아 두는 여유분.
##
## MultiMesh 의 instance_count 를 한 칸씩 늘리면 그때마다 버퍼를 다시 잡고
## **앞서 넣어 둔 것이 지워진다.** 넉넉히 잡아 두고 보이는 수만 조절한다.
const GROWTH := 512

## 지표에서 이만큼 아래면 가장 어둡다.
const DARK_DEPTH := 5

## 가장 깊은 곳의 밝기. 완전히 검게 하면 아무것도 안 보인다.
const DEEPEST_SHADE := 0.30

## 광석이 어둠에 눌릴 수 있는 한계.
##
## **광맥이 벽에 박혀 있어도 어둠에 먹혀 검은 벽과 구별되지 않았다.** 스펙
## §3.1 이 광맥을 "눈이 목적지를 잡는" 것으로 정의했는데, 목적지가 안 보이면
## 굴을 파도 어디로 갈지 모른 채 아무 데나 파게 된다. 등불 밖에서도 형체가
## 남을 만큼만 띄운다 — 대낮처럼 밝히는 것이 아니다.
const ORE_FLOOR_SHADE := 0.62

## 지금 보고 있는 자리와, 그 자리에서 머리 위를 걷어내고 있는지.
var _eye: Vector3i = Vector3i(-1, -1, -1)
var _cutting: bool = false

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


## 누가 어디서 보고 있는지 알린다. 지붕 아래면 머리 위 층을 걷어낸다.
##
## 서 있는 높이가 그대로일 때는 아무 일도 하지 않는다. 걷어내는 경계가
## 달라졌을 때만 다시 그린다 — 한 층을 통째로 고치는 것보다 그편이 싸다.
func look_from(cell: Vector3i) -> void:
    if _grid == null:
        return

    var cutting := _is_roofed(cell)
    if cutting == _cutting and (not cutting or cell.z == _eye.z):
        _eye = cell
        return

    _eye = cell
    _cutting = cutting
    rebuild()


## 머리 위가 막혀 있는가. 트여 있으면 걷어낼 이유가 없다.
func _is_roofed(cell: Vector3i) -> bool:
    for z in range(cell.z + CharacterState.HEIGHT, VoxelGrid.SIZE_Z):
        if _grid.is_solid(Vector3i(cell.x, cell.y, z)):
            return true
    return false


## 지금 머리 위라서 걷어낸 칸인가.
##
## 서 있는 높이보다 위는 통째로 걷어낸다. 둘레만 도려내면 방의 벽이 함께
## 사라져 섬에 구덩이가 뚫린 것처럼 보인다.
func is_cut_away(pos: Vector3i) -> bool:
    return _cutting and pos.z > _eye.z


## 지금 머리 위를 걷어내고 있는가.
func is_cutting() -> bool:
    return _cutting


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
                if not _grid.is_exposed(pos) or is_cut_away(pos):
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
        if not _layers.has(wanted) or not _grid.is_exposed(pos) or is_cut_away(pos):
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
    return _drawn[block_type].size()


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
    _layers[block_type].multimesh.visible_instance_count = last


func _remember(pos: Vector3i, block_type: int) -> void:
    var cells: Array = _drawn[block_type]
    cells.append(pos)
    var at := cells.size() - 1
    _slot_of[pos] = [block_type, at]
    _reserve(block_type, cells.size())
    _layers[block_type].multimesh.visible_instance_count = cells.size()
    _write_instance(block_type, at, pos)


func _write_instance(block_type: int, at: int, cell: Vector3i) -> void:
    var multimesh := _layers[block_type].multimesh
    multimesh.set_instance_transform(at, Transform3D(Basis(), SimViewCoords.cell_to_world(cell)))
    # 칸마다 명암을 아주 조금 달리해 넓은 면이 한 덩어리로 보이지 않게 한다.
    # 색은 면이 정하므로(BlockMeshes) 여기서는 배수만 넘긴다.
    # 켜진 등은 스스로 빛나므로 깊이에 눌리지 않는다.
    var lit := block_type == BlockType.LAMP_LIT
    var daylight := 1.0 if lit else _daylight_at(cell)
    # 광석은 어둠을 덜 먹는다. 캄캄한 벽에서도 여기가 목적지임이 보여야 한다.
    if block_type == BlockType.ORE:
        daylight = maxf(daylight, ORE_FLOOR_SHADE)
    var shade := Palette.variation_of(cell) * daylight
    multimesh.set_instance_color(at, Color(shade, shade, shade))


## 그 칸에 볕이 얼마나 드는가.
##
## 땅속이 대낮처럼 밝으면 파고 내려가는 일이 아무 느낌이 없고, 등을 만들
## 이유도 생기지 않는다. 지표에서 멀어질수록 어두워진다.
##
## 빛을 칸마다 퍼뜨려 재지는 않는다. 그건 값이 비싸다. 여기서 재는 것은
## "얼마나 묻혀 있는가"뿐이고, 등이 밝히는 것은 진짜 빛이 맡는다.
func _daylight_at(cell: Vector3i) -> float:
    var depth := _grid.height_at(cell.x, cell.y) - cell.z
    if depth <= 1:
        return 1.0
    if depth >= DARK_DEPTH:
        return DEEPEST_SHADE
    return lerpf(1.0, DEEPEST_SHADE, float(depth - 1) / float(DARK_DEPTH - 1))


func _make_layer(block_type: int) -> MultiMeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    if block_type == BlockType.LAMP_LIT:
        # 어두운 땅속에서 등이 켜졌다는 것이 한눈에 보여야 한다.
        material.emission_enabled = true
        material.emission = Palette.LAMP_LIT
        material.emission_energy_multiplier = 0.9
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
    _reserve(block_type, cells.size())
    _layers[block_type].multimesh.visible_instance_count = cells.size()
    for i in cells.size():
        _write_instance(block_type, i, cells[i])


## 그만큼 담을 자리를 잡아 둔다.
##
## 자리를 다시 잡으면 넣어 둔 것이 지워지므로, 넉넉히 잡고 그 안에서만 논다.
## 다시 잡아야 할 때는 이미 그리던 것을 도로 채워 넣는다.
func _reserve(block_type: int, needed: int) -> void:
    var multimesh := _layers[block_type].multimesh
    if multimesh.instance_count >= needed:
        return

    multimesh.instance_count = needed + GROWTH
    var cells: Array = _drawn[block_type]
    for i in mini(cells.size(), needed):
        _write_instance(block_type, i, cells[i])
