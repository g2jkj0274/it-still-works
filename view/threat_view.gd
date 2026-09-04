class_name ThreatView
extends Node3D

## 밤에 나온 위협들을 그린다. 위협 목록을 읽기만 한다.
##
## 사람과 한눈에 갈려야 한다. 색은 파스텔 폭이 좁아 믿을 수 없으므로
## **형태와 움직임**으로 가른다. 사람은 서 있는 치비고, 이것은 납작하고
## 넓은 덩어리이며 걸을 때 위아래로 튄다.
##
## 무섭게 만들지 않는다(스펙 §1). 통통 튀는 젤리 덩어리다.

## 사람보다 넓고 낮다. 실루엣이 곧 구별이다.
const RADIUS := 0.42
const HEIGHT_SCALE := 0.62

## 통통 튀는 폭과 빠르기. 표현일 뿐이라 결정론과 무관하다.
const BOB_HEIGHT := 0.14
const BOB_SPEED := 5.0

const COLOUR := Palette.THREAT

var _field: ThreatField
var _node: MultiMeshInstance3D


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = COLOUR

    var mesh := SphereMesh.new()
    mesh.radius = RADIUS
    mesh.height = Threat.HEIGHT * SimViewCoords.CELL_SIZE * HEIGHT_SCALE
    # 각진 세계에 매끈한 공은 겉돈다. 면을 줄여 뭉툭하게 깎는다.
    mesh.radial_segments = 9
    mesh.rings = 4
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    _node = MultiMeshInstance3D.new()
    _node.name = "Threats"
    _node.multimesh = multimesh
    add_child(_node)


func bind(field: ThreatField) -> void:
    _field = field


func sync() -> void:
    if _field == null:
        return

    var threats := _field.threats()
    var multimesh := _node.multimesh
    multimesh.instance_count = threats.size()

    var beat := Time.get_ticks_msec() / 1000.0 * BOB_SPEED
    for i in threats.size():
        var feet := SimViewCoords.cell_to_world(threats[i].position)
        var centre := feet + Vector3.UP * (Threat.HEIGHT - 1) * SimViewCoords.CELL_SIZE * 0.5
        # 하나씩 어긋나게 튄다. 넷이 한 몸처럼 움직이면 기계 같다.
        var bob := absf(sin(beat + i * 0.8)) * BOB_HEIGHT
        multimesh.set_instance_transform(i, Transform3D(Basis(), centre + Vector3.UP * bob))


func drawn_count() -> int:
    return _node.multimesh.instance_count
