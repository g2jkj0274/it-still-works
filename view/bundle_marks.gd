class_name BundleMarks
extends Node3D

## 묶으려고 고른 칸을 덧그린다.
##
## 어느 칸을 골랐는지, 그 칸이 값이 드나드는 자리인지만 보여준다.
## 회로가 왜 안 도는지는 말하지 않는다.
##
## 입력을 읽기만 한다. 여기서 고른 것을 바꾸지 않는다.

## 블록보다 살짝 크게 그려 안쪽 면과 겹치지 않게 한다.
const MARGIN := 0.05

var _controller: InputController
var _node: MultiMeshInstance3D
var _cells: Array[Vector3i] = []


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE * (SimViewCoords.CELL_SIZE + MARGIN * 2.0)
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    _node = MultiMeshInstance3D.new()
    _node.name = "Marks"
    _node.multimesh = multimesh
    add_child(_node)


func bind(controller: InputController) -> void:
    _controller = controller


func sync() -> void:
    if _controller == null:
        return

    _cells = _controller.chosen_cells()
    var multimesh := _node.multimesh
    multimesh.instance_count = _cells.size()

    for i in _cells.size():
        var cell := _cells[i]
        multimesh.set_instance_transform(
            i, Transform3D(Basis(), SimViewCoords.cell_to_world(cell)))
        multimesh.set_instance_color(i, colour_of_role(_controller.role_of(cell)))

    visible = not _cells.is_empty()


func marked_count() -> int:
    return _node.multimesh.instance_count


func marked_cells() -> Array[Vector3i]:
    return _cells.duplicate()


## 맡은 몫마다 다른 색. 배선 색과 짝을 맞춰 둔다.
static func colour_of_role(role: int) -> Color:
    match role:
        InputController.ROLE_ENTRY:
            return Palette.MARK_ENTRY
        InputController.ROLE_EXIT:
            return Palette.MARK_EXIT
        _:
            return Palette.MARK_CHOSEN
