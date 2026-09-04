class_name CharacterView
extends Node3D

## 캐릭터를 그린다.
##
## 캐릭터 상태를 읽기만 한다. 시뮬레이션은 서브유닛으로 움직이므로 화면은
## 그 값을 그대로 따라가되, 20틱과 화면 프레임 사이의 틈만 보간으로 메운다.
##
## 비율은 치비다. 머리가 크고 몸이 작다. 밝고 경쾌한 톤에 맞춘 모양이다.
##
## **어느 쪽을 보고 있는지가 보여야 한다.** 겨냥한 곳이 없으면 바라보는 앞 칸에
## 놓이고, 제자리에서 돌아설 수 있어야 놓을 목표를 정한다(스펙 §3.3, §3.4).
## 그런데 공 하나로는 어느 쪽을 보는지 알 수가 없었다. 모자챙이 그것을 가리키고,
## 몸 전체가 그 쪽으로 돌아선다.

## 몸 한가운데를 원점으로 놓고 위아래로 벌린다.
const BODY_HEIGHT := 0.52
const BODY_WIDTH := 0.44
const BODY_DEPTH := 0.34
const BODY_CENTRE_Y := -0.38

const HEAD_RADIUS := 0.40
const HEAD_CENTRE_Y := 0.22

const ARM_SIZE := Vector3(0.12, 0.36, 0.12)
const ARM_OFFSET_X := 0.30
const ARM_CENTRE_Y := -0.36

const LEG_SIZE := Vector3(0.16, 0.36, 0.16)
const LEG_OFFSET_X := 0.13
const LEG_CENTRE_Y := -0.82

## 모자챙. 보고 있는 쪽으로 튀어나와 방향을 가리킨다.
const BRIM_SIZE := Vector3(0.46, 0.10, 0.32)
const BRIM_CENTRE_Y := 0.30
const BRIM_FORWARD := 0.40

var _character: CharacterState

## 몸 전체. 자리는 이 노드의 부모가, 방향은 이 노드가 맡는다.
var _rig: Node3D

var _body: MeshInstance3D
var _head: MeshInstance3D
var _brim: MeshInstance3D


func _ready() -> void:
    _rig = Node3D.new()
    _rig.name = "Rig"
    add_child(_rig)

    for side in [-1.0, 1.0]:
        _add_part("Leg", _box(LEG_SIZE), Palette.CHARACTER_LEGS,
            Vector3(side * LEG_OFFSET_X, LEG_CENTRE_Y, 0.0))
        _add_part("Arm", _box(ARM_SIZE), Palette.CHARACTER_SKIN,
            Vector3(side * ARM_OFFSET_X, ARM_CENTRE_Y, 0.0))

    _body = _add_part("Body", _box(Vector3(BODY_WIDTH, BODY_HEIGHT, BODY_DEPTH)),
        Palette.CHARACTER_BODY, Vector3(0.0, BODY_CENTRE_Y, 0.0))
    _head = _add_part("Head", _sphere(), Palette.CHARACTER_SKIN,
        Vector3(0.0, HEAD_CENTRE_Y, 0.0))
    # 노드는 -Z 쪽을 앞으로 본다. 챙도 그 쪽에 둔다.
    _brim = _add_part("Brim", _box(BRIM_SIZE), Palette.CHARACTER_LEGS,
        Vector3(0.0, BRIM_CENTRE_Y, -BRIM_FORWARD))


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
    _face_the_way()


## [param weight] 만큼 목표 쪽으로 다가간다.
func sync(weight: float) -> void:
    if _character == null:
        return
    position = position.lerp(target_position(), clampf(weight, 0.0, 1.0))
    _face_the_way()


## 지금 몸이 돌아서 있는 쪽. 격자 방향이 아니라 화면 쪽 벡터다.
func facing_direction() -> Vector3:
    return -_rig.transform.basis.z


func head_radius() -> float:
    return HEAD_RADIUS


func body_radius() -> float:
    return BODY_WIDTH * 0.5


func head_height() -> float:
    return _head.position.y


func body_height() -> float:
    return _body.position.y


## 몸에서 가장 낮은 곳과 가장 높은 곳. 두 칸 안에 드는지 재는 데 쓴다.
func lowest_point() -> float:
    return LEG_CENTRE_Y - LEG_SIZE.y * 0.5


func highest_point() -> float:
    return HEAD_CENTRE_Y + HEAD_RADIUS


## 보고 있는 쪽으로 몸을 돌린다.
##
## 격자는 z 가 높이고 Godot 은 y 가 위다. 그 축 바꿈은 여기서도 같은 규칙을 따른다.
func _face_the_way() -> void:
    if _character == null:
        return
    var facing := _character.facing
    var direction := Vector3(float(facing.x), 0.0, float(facing.y))
    if direction.length_squared() < 0.0001:
        return
    _rig.basis = Basis.looking_at(direction.normalized(), Vector3.UP)


func _box(size: Vector3) -> BoxMesh:
    var mesh := BoxMesh.new()
    mesh.size = size
    return mesh


func _sphere() -> SphereMesh:
    var mesh := SphereMesh.new()
    mesh.radius = HEAD_RADIUS
    mesh.height = HEAD_RADIUS * 2.0
    return mesh


func _add_part(part_name: String, mesh: PrimitiveMesh, colour: Color, where: Vector3) -> MeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = colour
    mesh.material = material

    var node := MeshInstance3D.new()
    node.name = part_name
    node.mesh = mesh
    node.position = where
    _rig.add_child(node)
    return node
