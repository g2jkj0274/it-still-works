class_name BlockHighlight
extends Node3D

## 시선이 가리키는 칸을 덧그린다.
##
## 어느 칸에 손이 닿는지 눈으로 알려주는 것이 전부다. 왜 안 되는지는 말하지 않는다.

## 블록보다 살짝 크게 그려 안쪽 면과 겹치지 않게 한다.
const MARGIN := 0.03
const COLOUR := Color(1.0, 1.0, 1.0, 0.30)

var _cell: Vector3i = Vector3i.ZERO
var _mesh: MeshInstance3D


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = COLOUR
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE * (SimViewCoords.CELL_SIZE + MARGIN * 2.0)
    mesh.material = material

    _mesh = MeshInstance3D.new()
    _mesh.name = "Box"
    _mesh.mesh = mesh
    add_child(_mesh)
    visible = false


func show_cell(cell: Vector3i) -> void:
    _cell = cell
    position = SimViewCoords.cell_to_world(cell)
    visible = true


func clear() -> void:
    visible = false


func is_showing() -> bool:
    return visible


func targeted_cell() -> Vector3i:
    return _cell
