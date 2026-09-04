class_name PartMarks
extends Node3D

## 놓인 부품이 무엇으로 맞춰져 있는지 형태로 보여준다.
##
## 블록 메시는 종류 하나로만 갈린다([BlockMeshes]). 그래서 네모 상자와 둥근
## 상자가, 세 번 도는 되풀이와 끝없이 도는 되풀이가 전부 똑같이 생겼다.
##
## **상자 세 모양은 스펙 §4.2 가 명시한 것인데 구현되어 있지 않았다.**
## 네모(정수) / 둥근(실수) / 작은(불리언). 형변환 손실을 가르치는 유일한
## 시각 단서다 — 3.7 을 네모 상자에 넣으면 3 이 된다는 것을 알려면 상자가
## 네모라는 것부터 보여야 한다.
##
## 이것은 오류를 말해 주는 UI 가 아니다. 왜 안 도는지는 여전히 말하지 않는다.
## **눈에 안 보이던 사실을 눈에 보이게 하는 것**뿐이다.
##
## 회로를 읽기만 한다. 격자가 아니라 회로를 읽으므로 설정까지 알 수 있다.

## 표시가 부품 꼭대기에서 얼마나 위에 앉는가.
const LIFT := 0.46

## 표시 하나하나의 크기.
const MARK_SIZE := 0.30

## 표시 갈래. 순서가 곧 층 번호다.
const MARK_SQUARE := 0
const MARK_ROUND := 1
const MARK_SMALL := 2
const MARK_ENDLESS := 3
const MARK_COUNT := 4

var _circuit: Circuit
var _layers: Array[MultiMeshInstance3D] = []
var _signature: String = ""
var _build_count: int = 0


func _ready() -> void:
    for kind in MARK_COUNT:
        _layers.append(_make_layer(kind))


func bind(circuit: Circuit) -> void:
    _circuit = circuit
    _signature = ""


func sync() -> void:
    if _circuit == null:
        return
    if _read_signature() != _signature:
        rebuild()


func rebuild() -> void:
    if _circuit == null:
        return

    var placements: Array[Array] = []
    for kind in MARK_COUNT:
        placements.append([])

    for part in _circuit.parts():
        var kind := mark_for(part)
        if kind < 0:
            continue
        var top := SimViewCoords.cell_to_world(part.position) + Vector3.UP * LIFT
        placements[kind].append(Transform3D(Basis(), top))

    for kind in MARK_COUNT:
        var multimesh := _layers[kind].multimesh
        multimesh.instance_count = placements[kind].size()
        for i in placements[kind].size():
            multimesh.set_instance_transform(i, placements[kind][i])

    _signature = _read_signature()
    _build_count += 1


## 그 부품 위에 얹을 표시. 얹을 것이 없으면 -1.
static func mark_for(part: CircuitPart) -> int:
    if part == null:
        return -1
    if part.kind() == BlockType.BOX:
        match (part as BoxPart).shape:
            BoxPart.SHAPE_ROUND:
                return MARK_ROUND
            BoxPart.SHAPE_SMALL:
                return MARK_SMALL
            _:
                return MARK_SQUARE
    if part.kind() == BlockType.REPEATER:
        # 끝없이 도는 것만 다르게 보인다. 그것만 타 버리기 때문이다.
        if (part as RepeaterPart).mode == RepeaterPart.MODE_FOREVER:
            return MARK_ENDLESS
    return -1


func mark_count(kind: int) -> int:
    if kind < 0 or kind >= _layers.size():
        return 0
    return _layers[kind].multimesh.instance_count


func total_mark_count() -> int:
    var total := 0
    for kind in MARK_COUNT:
        total += mark_count(kind)
    return total


func build_count() -> int:
    return _build_count


## 회로가 바뀌었는지 보는 지문. 자리와 설정이 함께 들어간다.
func _read_signature() -> String:
    var marks := PackedStringArray()
    for part in _circuit.parts():
        marks.append("%s:%d" % [part.position, mark_for(part)])
    return "|".join(marks)


func _mesh_for(kind: int) -> Mesh:
    match kind:
        MARK_ROUND:
            var ball := SphereMesh.new()
            ball.radius = MARK_SIZE * 0.5
            ball.height = MARK_SIZE
            ball.radial_segments = 8
            ball.rings = 4
            return ball
        MARK_SMALL:
            var pebble := BoxMesh.new()
            pebble.size = Vector3.ONE * MARK_SIZE * 0.5
            return pebble
        MARK_ENDLESS:
            # 끝이 없다는 것을 고리로 보인다.
            var ring := TorusMesh.new()
            ring.inner_radius = MARK_SIZE * 0.28
            ring.outer_radius = MARK_SIZE * 0.6
            ring.rings = 8
            ring.ring_segments = 6
            return ring
        _:
            var cube := BoxMesh.new()
            cube.size = Vector3.ONE * MARK_SIZE
            return cube


func _make_layer(kind: int) -> MultiMeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Palette.PART_MARK

    var mesh := _mesh_for(kind)
    if mesh is PrimitiveMesh:
        (mesh as PrimitiveMesh).material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    var node := MultiMeshInstance3D.new()
    node.name = "Mark_%d" % kind
    node.multimesh = multimesh
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
    return node
