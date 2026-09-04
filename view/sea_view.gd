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
## 물낯은 **사람이 팔 수 있는 층보다 아래**에 둔다.
##
## 처음에는 지면 윗면 바로 아래에 두었더니 파 놓은 구덩이마다 물이 차 보였다.
## 시뮬레이션에는 빈 칸인데 화면이 물이라고 말한 것이다. 보이는 것이 사실이
## 아니면 안 된다.
##
## 바닥층(z=0)은 부술 수 없으므로 그 윗면보다 낮으면 구덩이에 물이 비치지
## 않는다. 물가에서는 여전히 한 칸쯤의 벼랑이 보인다.

## 바닥층 윗면에서 물낯까지 더 내려가는 깊이. 겹쳐 보이지 않을 만큼만.
const BELOW_BEDROCK := 0.05

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


## 물낯의 높이. 부술 수 없는 바닥층 윗면보다 조금 아래다.
static func water_level() -> float:
    var bedrock_top := float(VoxelGrid.BEDROCK_Z + 1) * SimViewCoords.CELL_SIZE
    return bedrock_top - BELOW_BEDROCK


func surface_height() -> float:
    return position.y
