class_name PartMarks
extends Node3D

## 놓인 부품이 무엇으로 맞춰져 있는지 형태로 보여준다.
##
## 블록 메시는 종류 하나로만 갈린다([BlockMeshes]). 그래서 사람을 보는 감지기와
## 밤을 보는 감지기가, 세 번 도는 되풀이와 끝없이 도는 되풀이가, 네모 상자와
## 둥근 상자가 전부 똑같이 생겼다.
##
## **이 게임은 부품이 다섯 종뿐인 대신 설정으로 갈린다.** 그 설정이 안 보이면
## 판을 통째로 눈으로 읽을 수가 없고, 감지기 스무 개가 놓인 회로는 하나씩
## 겨냥해서 확인해야 하는 판이 된다. 레드스톤의 리피터는 딜레이가 손잡이
## 자리로 보이고 비교기는 모드가 횃불 색으로 보인다 — 그것이 눈으로 읽는
## 즐거움이다. 여기서 그것을 잃으면 "레드스톤보다 깊다"가 아니라
## "레드스톤보다 안 읽힌다"가 된다.
##
## 이것은 오류를 말해 주는 UI 가 아니다. 왜 안 도는지는 여전히 말하지 않는다.
## **눈에 안 보이던 사실을 눈에 보이게 하는 것**뿐이고, 스펙 §4.2 가 그렇게 적었다.
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

## 되풀이가 어떻게 도는가. 끝없이 도는 것은 위의 [constant MARK_ENDLESS] 다.
const MARK_TURNS := 14
const MARK_WHILE := 15

## 감지기가 무엇을 보는가. 대상마다 다른 모양이 지붕에 앉는다.
const MARK_EYE_PLAYER := 4
const MARK_EYE_THREAT := 5
const MARK_EYE_TIME := 6
const MARK_EYE_CROP := 7
const MARK_EYE_ITEM := 8

## 갈림길이 무엇을 재는가.
const MARK_TRUTH := 9
const MARK_COMPARE := 10
const MARK_BOTH := 11
const MARK_EITHER := 12

## 묶음. 안에 든 것이 많을수록 높이 쌓인다.
##
## 묶음은 밖에서 보면 전부 같은 상자다. 부품 셋을 접은 것과 열둘을 접은 것이
## 같아 보이면, 판에 놓인 묶음 다섯 개 가운데 어느 것이 큰 장치인지 알 수
## 없다. 숫자를 적지 않는다 — 쌓인 높이로 보인다.
const MARK_BUNDLE := 13
const MARK_BUNDLE_BIG := 16
const MARK_BUNDLE_HUGE := 17

## 묶음 표시가 한 단 높아지는 부품 수.
const BUNDLE_STEP := 4

const MARK_COUNT := 18

## 감지기 대상 번호 → 표시.
const _EYES: Dictionary[int, int] = {
    DetectorPart.TARGET_PLAYER: MARK_EYE_PLAYER,
    DetectorPart.TARGET_THREAT: MARK_EYE_THREAT,
    DetectorPart.TARGET_TIME: MARK_EYE_TIME,
    DetectorPart.TARGET_CROP: MARK_EYE_CROP,
    DetectorPart.TARGET_ITEM: MARK_EYE_ITEM,
}

## 갈림길 판정 → 표시. 견줄 수가 있는 것들은 한 갈래로 묶는다.
const _JUDGEMENTS: Dictionary[int, int] = {
    BranchPart.MODE_TRUTH: MARK_TRUTH,
    BranchPart.MODE_GREATER_EQUAL: MARK_COMPARE,
    BranchPart.MODE_LESS: MARK_COMPARE,
    BranchPart.MODE_EQUAL: MARK_COMPARE,
    BranchPart.MODE_AND: MARK_BOTH,
    BranchPart.MODE_OR: MARK_EITHER,
}

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

    match part.kind():
        BlockType.BOX:
            match (part as BoxPart).shape:
                BoxPart.SHAPE_ROUND:
                    return MARK_ROUND
                BoxPart.SHAPE_SMALL:
                    return MARK_SMALL
                _:
                    return MARK_SQUARE
        BlockType.REPEATER:
            match (part as RepeaterPart).mode:
                RepeaterPart.MODE_FOREVER:
                    return MARK_ENDLESS
                RepeaterPart.MODE_WHILE:
                    return MARK_WHILE
                _:
                    return MARK_TURNS
        BlockType.DETECTOR:
            return _EYES.get((part as DetectorPart).target, -1)
        BlockType.BRANCH:
            return _JUDGEMENTS.get((part as BranchPart).mode, -1)
        BlockType.BUNDLE:
            return bundle_mark_for((part as BundlePart).inner_part_count())
        _:
            return -1


## 안에 든 것이 그만큼일 때 얹히는 표시.
static func bundle_mark_for(inner: int) -> int:
    if inner >= BUNDLE_STEP * 2:
        return MARK_BUNDLE_HUGE
    if inner >= BUNDLE_STEP:
        return MARK_BUNDLE_BIG
    return MARK_BUNDLE


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


## 표시마다의 생김새.
##
## 그림도 글자도 쓰지 않는다. 화면에 프로그래밍 용어를 내보내지 않는다는 규칙은
## 기호에도 걸린다. 서 있는 것 · 웅크린 것 · 하늘을 보는 것 · 싹 · 쌓인 것처럼
## 뜻이 형태에 담긴 것만 쓴다.
func _mesh_for(kind: int) -> Mesh:
    match kind:
        MARK_ROUND:
            return _ball(MARK_SIZE * 0.5)
        MARK_SMALL:
            return _cube(Vector3.ONE * MARK_SIZE * 0.5)
        MARK_ENDLESS:
            # 끝이 없다는 것을 고리로 보인다.
            var ring := TorusMesh.new()
            ring.inner_radius = MARK_SIZE * 0.28
            ring.outer_radius = MARK_SIZE * 0.6
            ring.rings = 8
            ring.ring_segments = 6
            return ring
        MARK_EYE_PLAYER:
            # 사람. 서 있는 것.
            return _cube(Vector3(MARK_SIZE * 0.34, MARK_SIZE * 1.3, MARK_SIZE * 0.34))
        MARK_EYE_THREAT:
            # 밤에 오는 것. 납작하고 넓다 — 위협을 그린 것과 같은 실루엣이다.
            return _ball(MARK_SIZE * 0.62)
        MARK_EYE_TIME:
            # 밤. 하늘을 보는 접시.
            return _cube(Vector3(MARK_SIZE * 1.3, MARK_SIZE * 0.22, MARK_SIZE * 1.3))
        MARK_EYE_CROP:
            # 다 자란 작물. 위로 뻗은 싹.
            var sprout := CylinderMesh.new()
            sprout.top_radius = 0.0
            sprout.bottom_radius = MARK_SIZE * 0.5
            sprout.height = MARK_SIZE * 1.2
            sprout.radial_segments = 6
            return sprout
        MARK_EYE_ITEM:
            # 손에 든 것. 쌓인 더미.
            return _cube(Vector3(MARK_SIZE * 1.1, MARK_SIZE * 0.5, MARK_SIZE * 0.7))
        MARK_TRUTH:
            # 온 대로 흘려보낸다. 곧게 지나가는 막대.
            return _cube(Vector3(MARK_SIZE * 1.4, MARK_SIZE * 0.24, MARK_SIZE * 0.24))
        MARK_COMPARE:
            # 견준다. 두 층이 어긋나 있다.
            return _cube(Vector3(MARK_SIZE * 0.9, MARK_SIZE * 0.6, MARK_SIZE * 0.3))
        MARK_BOTH:
            # 둘 다 와야 한다. 나란히 선 둘.
            return _cube(Vector3(MARK_SIZE * 1.2, MARK_SIZE * 0.4, MARK_SIZE * 1.2))
        MARK_EITHER:
            # 하나라도 오면 된다. 하나뿐.
            return _ball(MARK_SIZE * 0.42)
        MARK_TURNS:
            # 정해진 횟수만 돈다. 끝이 있는 막대.
            return _cube(Vector3(MARK_SIZE * 0.26, MARK_SIZE * 0.9, MARK_SIZE * 0.26))
        MARK_WHILE:
            # 조건이 참인 동안 돈다. 열린 반 고리 — 언제 멈출지는 밖에 달렸다.
            var arc := CylinderMesh.new()
            arc.top_radius = MARK_SIZE * 0.5
            arc.bottom_radius = MARK_SIZE * 0.5
            arc.height = MARK_SIZE * 0.24
            arc.radial_segments = 6
            return arc
        MARK_BUNDLE:
            # 묶음. 접혀 들어간 것을 층으로 보인다.
            return _cube(Vector3(MARK_SIZE * 0.8, MARK_SIZE * 0.5, MARK_SIZE * 0.8))
        MARK_BUNDLE_BIG:
            return _cube(Vector3(MARK_SIZE * 0.8, MARK_SIZE * 1.0, MARK_SIZE * 0.8))
        MARK_BUNDLE_HUGE:
            return _cube(Vector3(MARK_SIZE * 0.8, MARK_SIZE * 1.6, MARK_SIZE * 0.8))
        _:
            return _cube(Vector3.ONE * MARK_SIZE)


func _cube(size: Vector3) -> BoxMesh:
    var mesh := BoxMesh.new()
    mesh.size = size
    return mesh


func _ball(radius: float) -> SphereMesh:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 8
    mesh.rings = 4
    return mesh


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
