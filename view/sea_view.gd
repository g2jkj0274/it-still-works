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
## 물낯은 **섬 바깥에만** 있다. 가운데가 뚫린 고리로 그린다.
##
## 평평한 판으로 깔면 섬 아래까지 물이 지나간다. 그러면 땅을 파서 물낯보다
## 아래로 내려가는 순간 구덩이에 물이 차 보인다. 시뮬레이션에는 빈 칸인데
## 화면이 물이라고 말하는 것이다. 지하를 파는 게임에서는 그 일이 늘 일어난다.
##
## 고리로 두르면 섬 안에서는 아무리 파도 물이 비치지 않고, 물가에서는 여전히
## 바다가 보인다.

## 고리의 안지름. 섬 반지름보다 조금 작아 물가와 맞물린다.
const INNER_MARGIN := 1.5

## 고리의 바깥지름. 어느 쪽으로 시점을 돌려도 끝이 보이지 않을 만큼 넓게.
const EXTENT := 400.0

## 고리를 몇 조각으로 나눌 것인가. 각진 세계라 매끄러울 필요는 없다.
const SEGMENTS := 48

## 해안 윗면에서 물낯까지 내려가는 깊이.
const BELOW_SHORE := 0.3

var _surface: MeshInstance3D


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = Palette.SEA
    # 물은 지면보다 매끈하다. 빛을 조금 더 되쏜다.
    material.roughness = 0.4
    # 고리는 위에서만 보인다. 뒷면을 자를 이유가 없다.
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var mesh := _ring()
    mesh.surface_set_material(0, material)

    _surface = MeshInstance3D.new()
    _surface.name = "Surface"
    _surface.mesh = mesh
    # 물낯은 그림자를 받기만 하고 드리우지는 않는다.
    _surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_surface)

    position = Vector3(0.0, water_level(), 0.0)


## 가운데가 뚫린 고리. 섬 자리는 비워 둔다.
func _ring() -> ArrayMesh:
    var centre := SimViewCoords.cell_to_world(
        Vector3i(IslandBuilder.CENTER.x, IslandBuilder.CENTER.y, 0))
    var inner := float(IslandBuilder.ISLAND_RADIUS) - INNER_MARGIN
    var outer := EXTENT

    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in SEGMENTS:
        var a := TAU * i / SEGMENTS
        var b := TAU * (i + 1) / SEGMENTS
        var corners: Array[Vector3] = [
            _on_ring(centre, inner, a), _on_ring(centre, outer, a),
            _on_ring(centre, outer, b), _on_ring(centre, inner, b),
        ]
        for index in [0, 1, 2, 0, 2, 3]:
            tool.set_normal(Vector3.UP)
            tool.add_vertex(corners[index])
    return tool.commit()


static func _on_ring(centre: Vector3, radius: float, angle: float) -> Vector3:
    return Vector3(centre.x + cos(angle) * radius, 0.0, centre.z + sin(angle) * radius)


## 물낯의 높이. 해안 윗면 바로 아래다.
static func water_level() -> float:
    var shore_top := float(IslandBuilder.SHORE_Z + 1) * SimViewCoords.CELL_SIZE
    return shore_top - BELOW_SHORE


func surface_height() -> float:
    return position.y


## 물낯이 차지하는 자리. 고리가 제대로 만들어졌는지 재는 데 쓴다.
func mesh_bounds() -> AABB:
    return _surface.mesh.get_aabb()
