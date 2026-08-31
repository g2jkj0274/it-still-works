class_name CharacterView
extends Node3D

## 캐릭터를 그린다.
##
## 캐릭터 상태를 읽기만 한다. 시뮬레이션은 서브유닛으로 움직이므로 화면은
## 그 값을 그대로 따라가되, 20틱과 화면 프레임 사이의 틈만 보간으로 메운다.
##
## 비율은 치비다. 머리가 크고 몸이 작다. 밝고 경쾌한 톤에 맞춘 모양이다.

## 몸 한가운데를 원점으로 놓고 위아래로 벌린다.
const BODY_HEIGHT := 0.90
const BODY_RADIUS := 0.26
const BODY_CENTRE_Y := -0.55

const HEAD_RADIUS := 0.42
const HEAD_CENTRE_Y := 0.30

var _character: CharacterState
var _body: MeshInstance3D
var _head: MeshInstance3D


func _ready() -> void:
    _body = _add_part("Body", _capsule(), Palette.CHARACTER_BODY, BODY_CENTRE_Y)
    _head = _add_part("Head", _sphere(), Palette.CHARACTER_SKIN, HEAD_CENTRE_Y)


func bind(character: CharacterState) -> void:
    _character = character


## 몸 한가운데의 월드 좌표. 발 칸보다 반 칸 위다.
func target_position() -> Vector3:
    if _character == null:
        return Vector3.ZERO
    var feet := SimViewCoords.sub_to_world(_character.sub_position)
    return feet + Vector3.UP * (CharacterState.HEIGHT - 1) * SimViewCoords.CELL_SIZE * 0.5


func snap() -> void:
    position = target_position()


## [param weight] 만큼 목표 쪽으로 다가간다.
func sync(weight: float) -> void:
    if _character == null:
        return
    position = position.lerp(target_position(), clampf(weight, 0.0, 1.0))


func head_radius() -> float:
    return HEAD_RADIUS


func body_radius() -> float:
    return BODY_RADIUS


func head_height() -> float:
    return _head.position.y


func body_height() -> float:
    return _body.position.y


func _capsule() -> CapsuleMesh:
    var mesh := CapsuleMesh.new()
    mesh.radius = BODY_RADIUS
    mesh.height = BODY_HEIGHT
    return mesh


func _sphere() -> SphereMesh:
    var mesh := SphereMesh.new()
    mesh.radius = HEAD_RADIUS
    mesh.height = HEAD_RADIUS * 2.0
    return mesh


func _add_part(part_name: String, mesh: PrimitiveMesh, colour: Color, height: float) -> MeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = colour
    mesh.material = material

    var node := MeshInstance3D.new()
    node.name = part_name
    node.mesh = mesh
    node.position = Vector3(0.0, height, 0.0)
    add_child(node)
    return node
