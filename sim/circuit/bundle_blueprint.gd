class_name BundleBlueprint
extends RefCounted

## 묶음 하나의 설계도.
##
## 완성한 회로를 그대로 떠 놓은 것이다. 부품과 배선의 자리는 고른 칸 가운데
## 맨 앞의 것을 기준으로 한 상대 좌표로 담는다. 그래야 어디에 놓아도 같다.
##
## 설계도는 만들고 나면 바뀌지 않는다. 같은 묶음을 열 개 놓아도 설계도는 하나고,
## 굴러가는 상태는 놓인 것마다 따로 생긴다. 그래서 묶음 안의 상자는 서로 남이다.
##
## **들어오는 자리**는 바깥 배선이 닿는 곳이다. 이어진 차례대로 첫째 배선이
## 첫째 자리에 닿는다.
##
## **나가는 자리**는 값이 밖으로 나가는 곳이다. 그 부품의 첫 출구를 내보낸다.
## 갈림길의 거짓 쪽을 밖으로 내보내려면 안에서 다른 부품으로 받아 그것을
## 두 번째 나가는 자리로 삼는다.

## 부품 하나. [블록 종류, 자리(상대), 설정값].
var _parts: Array = []

## 배선 하나. [출발(상대), 도착(상대), 출구 번호].
var _links: Array = []

## 값이 들어오는 자리들. 고른 차례 그대로다.
var _inputs: Array[Vector3i] = []

## 값이 나가는 자리들. 고른 차례가 곧 출구 번호다.
var _outputs: Array[Vector3i] = []


## 회로에서 [param cells] 에 놓인 부품들을 떠낸다. 뜰 수 없으면 null.
##
## 뜰 수 없는 경우는 셋이다. 부품이 없는 칸을 골랐거나, 같은 칸을 두 번
## 골랐거나, 타 버려 재료가 돌아오지 않는 부품을 골랐거나.
static func capture(
    circuit: Circuit,
    cells: Array[Vector3i],
    inputs: Array[Vector3i],
    outputs: Array[Vector3i],
) -> BundleBlueprint:
    if circuit == null or cells.is_empty():
        return null

    var ordered := _ordered(cells)
    if ordered.size() != cells.size():
        return null

    for cell in ordered:
        var part := circuit.part_at(cell)
        if part == null or not part.yields_material():
            return null

    if _has_repeat(inputs) or _has_repeat(outputs):
        return null
    if not _all_inside(inputs, ordered) or not _all_inside(outputs, ordered):
        return null

    var origin: Vector3i = ordered[0]
    var blueprint := BundleBlueprint.new()

    for cell in ordered:
        var part := circuit.part_at(cell)
        blueprint._parts.append([part.kind(), cell - origin, part.parameters()])

    # 고른 칸 밖으로 나가거나 밖에서 들어오는 배선은 함께 가지 않는다.
    # 부품이 사라지면 그 배선도 사라지기 때문이다.
    for link: Array in circuit.links():
        if not ordered.has(link[0]) or not ordered.has(link[1]):
            continue
        blueprint._links.append([link[0] - origin, link[1] - origin, link[2]])

    for cell in inputs:
        blueprint._inputs.append(cell - origin)
    for cell in outputs:
        blueprint._outputs.append(cell - origin)
    return blueprint


func part_count() -> int:
    return _parts.size()


func link_count() -> int:
    return _links.size()


func parts() -> Array:
    return _parts.duplicate(true)


func links() -> Array:
    return _links.duplicate(true)


func inputs() -> Array[Vector3i]:
    return _inputs.duplicate()


func outputs() -> Array[Vector3i]:
    return _outputs.duplicate()


func input_count() -> int:
    return _inputs.size()


func output_count() -> int:
    return _outputs.size()


## 이 설계도가 품고 있는 다른 묶음들의 번호.
##
## 묶음 안에 묶음을 넣을 수 있다. 다만 자기 자신은 넣을 수 없다.
## 그 판정은 [BundleLibrary] 가 한다.
func references() -> PackedInt32Array:
    var ids := PackedInt32Array()
    for entry: Array in _parts:
        if int(entry[0]) != BlockType.BUNDLE:
            continue
        var values: PackedInt32Array = entry[2]
        ids.append(values[0] if values.size() > 0 else -1)
    return ids


func to_hash_fields(prefix: String) -> Array:
    var fields: Array = [
        [prefix + ".parts", _parts.size()],
        [prefix + ".links", _links.size()],
        [prefix + ".inputs", _inputs.size()],
        [prefix + ".outputs", _outputs.size()],
    ]
    for i in _parts.size():
        var entry: Array = _parts[i]
        var values: PackedInt32Array = entry[2]
        fields.append(["%s.part.%d" % [prefix, i], "%d@%s:%s" % [
            int(entry[0]), entry[1], Array(values)]])
    for i in _links.size():
        var link: Array = _links[i]
        fields.append(["%s.link.%d" % [prefix, i], "%s>%s@%d" % [link[0], link[1], link[2]]])
    for i in _inputs.size():
        fields.append(["%s.in.%d" % [prefix, i], str(_inputs[i])])
    for i in _outputs.size():
        fields.append(["%s.out.%d" % [prefix, i], str(_outputs[i])])
    return fields


## 전송·저장 가능한 형태로 펼친다. 명령이 직렬화될 때 함께 실린다.
func to_dict() -> Dictionary:
    var raw_parts: Array = []
    for entry: Array in _parts:
        raw_parts.append([int(entry[0]), _cell_to_array(entry[1]), Array(entry[2] as PackedInt32Array)])

    var raw_links: Array = []
    for link: Array in _links:
        raw_links.append([_cell_to_array(link[0]), _cell_to_array(link[1]), int(link[2])])

    return {
        "parts": raw_parts,
        "links": raw_links,
        "inputs": _cells_to_array(_inputs),
        "outputs": _cells_to_array(_outputs),
    }


static func from_dict(data: Dictionary) -> BundleBlueprint:
    var blueprint := BundleBlueprint.new()

    for entry: Array in data.get("parts", []) as Array:
        var values := PackedInt32Array()
        for value in entry[2] as Array:
            values.append(int(value))
        blueprint._parts.append([int(entry[0]), _array_to_cell(entry[1]), values])

    for link: Array in data.get("links", []) as Array:
        blueprint._links.append([_array_to_cell(link[0]), _array_to_cell(link[1]), int(link[2])])

    blueprint._inputs = _array_to_cells(data.get("inputs", []))
    blueprint._outputs = _array_to_cells(data.get("outputs", []))
    return blueprint


## 정해진 차례로 늘어놓는다. 같은 칸이 겹쳐 있으면 하나로 줄어든다.
static func _ordered(cells: Array[Vector3i]) -> Array[Vector3i]:
    var unique: Array[Vector3i] = []
    for cell in cells:
        if not unique.has(cell):
            unique.append(cell)
    unique.sort_custom(Circuit.cell_before)
    return unique


static func _has_repeat(cells: Array[Vector3i]) -> bool:
    var seen: Array[Vector3i] = []
    for cell in cells:
        if seen.has(cell):
            return true
        seen.append(cell)
    return false


static func _all_inside(cells: Array[Vector3i], allowed: Array[Vector3i]) -> bool:
    for cell in cells:
        if not allowed.has(cell):
            return false
    return true


static func _cell_to_array(cell: Vector3i) -> Array:
    return [cell.x, cell.y, cell.z]


static func _array_to_cell(raw: Variant) -> Vector3i:
    var values: Array = raw
    return Vector3i(int(values[0]), int(values[1]), int(values[2]))


static func _cells_to_array(cells: Array[Vector3i]) -> Array:
    var raw: Array = []
    for cell in cells:
        raw.append(_cell_to_array(cell))
    return raw


static func _array_to_cells(raw: Variant) -> Array[Vector3i]:
    var cells: Array[Vector3i] = []
    for entry in raw as Array:
        cells.append(_array_to_cell(entry))
    return cells
