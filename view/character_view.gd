class_name CharacterView
extends Node3D

## 캐릭터를 그린다.
##
## 캐릭터 상태를 읽기만 한다. 시뮬레이션은 칸 단위로만 움직이므로 칸 사이를
## 메우는 부드러운 움직임은 여기서 만든다. 이 보간은 표현일 뿐이라 시뮬레이션
## 결과에 아무 영향을 주지 않는다.

const RADIUS := 0.3
const COLOUR := Color(0.92, 0.74, 0.52)

var _character: CharacterState
var _mesh: MeshInstance3D


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = COLOUR

    var mesh := CapsuleMesh.new()
    mesh.radius = RADIUS
    mesh.height = CharacterState.HEIGHT * SimViewCoords.CELL_SIZE
    mesh.material = material

    _mesh = MeshInstance3D.new()
    _mesh.name = "Body"
    _mesh.mesh = mesh
    add_child(_mesh)


func bind(character: CharacterState) -> void:
    _character = character


## 몸 한가운데의 월드 좌표. 발 칸보다 반 칸 위다.
func target_position() -> Vector3:
    if _character == null:
        return Vector3.ZERO
    var feet := SimViewCoords.cell_to_world(_character.position)
    return feet + Vector3.UP * (CharacterState.HEIGHT - 1) * SimViewCoords.CELL_SIZE * 0.5


func snap() -> void:
    position = target_position()


## [param weight] 만큼 목표 쪽으로 다가간다.
func sync(weight: float) -> void:
    if _character == null:
        return
    position = position.lerp(target_position(), clampf(weight, 0.0, 1.0))
