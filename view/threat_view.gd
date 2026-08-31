class_name ThreatView
extends Node3D

## 밤에 나온 위협들을 그린다. 위협 목록을 읽기만 한다.

const RADIUS := 0.32
const COLOUR := Palette.THREAT

var _field: ThreatField
var _node: MultiMeshInstance3D


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = COLOUR

    var mesh := CapsuleMesh.new()
    mesh.radius = RADIUS
    mesh.height = Threat.HEIGHT * SimViewCoords.CELL_SIZE
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

    for i in threats.size():
        var feet := SimViewCoords.cell_to_world(threats[i].position)
        var centre := feet + Vector3.UP * (Threat.HEIGHT - 1) * SimViewCoords.CELL_SIZE * 0.5
        multimesh.set_instance_transform(i, Transform3D(Basis(), centre))


func drawn_count() -> int:
    return _node.multimesh.instance_count
