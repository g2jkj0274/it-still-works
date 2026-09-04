class_name SeaView
extends Node3D

## 섬을 둘러싼 바다.
##
## 표현일 뿐이다. 시뮬레이션에는 바다가 없고, 바다로 걸어 나가지 못하는 것은
## "딛을 곳이 없는 칸으로는 나가지 않는다"는 이동 규칙이 이미 막고 있다
## (스펙 §3.3). 여기서 하는 일은 **섬이 섬으로 보이게** 하는 것뿐이다.
##
## 지금까지는 섬 끝이 허공으로 끊겨 어디가 뭍이고 어디가 바깥인지 알 수 없었다.
##
## 물낯을 지면 윗면보다 조금 낮게 둔다. 같은 높이면 물가가 사라지고,
## 너무 낮으면 섬이 공중에 뜬 것처럼 보인다.

## 지면 윗면에서 물낯까지의 깊이.
const DEPTH := 0.34

## 물낯의 크기. 어느 쪽으로 시점을 돌려도 끝이 보이지 않을 만큼 넓게.
const EXTENT := 400.0

var _surface: MeshInstance3D


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = Palette.SEA
    # 물은 지면보다 매끈하다. 빛을 조금 더 되쏜다.
    material.roughness = 0.4

    var mesh := PlaneMesh.new()
    mesh.size = Vector2(EXTENT, EXTENT)
    mesh.material = material

    _surface = MeshInstance3D.new()
    _surface.name = "Surface"
    _surface.mesh = mesh
    # 물낯은 그림자를 받기만 하고 드리우지는 않는다.
    _surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_surface)

    position = Vector3(0.0, water_level(), 0.0)


## 물낯의 높이. 지면 윗면 바로 아래다.
static func water_level() -> float:
    var ground_top := float(IslandBuilder.GROUND_TOP_Z + 1) * SimViewCoords.CELL_SIZE
    return ground_top - DEPTH


func surface_height() -> float:
    return position.y
