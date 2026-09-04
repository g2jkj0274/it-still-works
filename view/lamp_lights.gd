class_name LampLights
extends Node3D

## 켜진 등이 둘레를 밝힌다.
##
## 격자를 읽기만 한다. 켜졌는지 꺼졌는지는 시뮬레이션이 정하고(작동기가
## 블록을 바꾼다) 여기서는 켜진 자리에 빛을 하나 놓을 뿐이다.
##
## 땅속은 지표에서 멀어질수록 어둡게 그려진다([WorldView]). 그건 "얼마나
## 묻혀 있는가"를 재는 것이고, **여기서 다는 것은 진짜 빛이다.** 그래서
## 등을 놓으면 둘레의 벽과 바닥이 실제로 밝아진다.
##
## 스펙 §5 의 "자동 조명" — 감지기(시간=밤) → 작동기(등) — 이 이것으로
## 눈에 보이는 장치가 된다.

## 빛이 닿는 거리(칸).
const REACH := 7.0

## 빛의 세기.
const STRENGTH := 2.4

## 한 번에 켜 둘 수 있는 빛의 수.
##
## 등을 백 개 놓아도 화면이 버텨야 한다. 가까운 것부터 켠다 — 멀리 있는 등은
## 어차피 화면 밖이라 켜 봐야 보이지 않는다.
const MAX_LIGHTS := 24

var _grid: VoxelGrid
var _lights: Array[OmniLight3D] = []
var _lit: Array[Vector3i] = []
var _last_version: int = -1
var _focus: Vector3 = Vector3.ZERO


func _ready() -> void:
    for i in MAX_LIGHTS:
        var light := OmniLight3D.new()
        light.name = "Lamp_%d" % i
        light.omni_range = REACH
        light.light_energy = STRENGTH
        light.light_color = Palette.LAMP_LIT
        # 등마다 그림자를 치면 값이 감당이 안 된다.
        light.shadow_enabled = false
        light.visible = false
        add_child(light)
        _lights.append(light)


func bind(grid: VoxelGrid) -> void:
    _grid = grid
    _last_version = -1


## 화면이 보고 있는 자리. 가까운 등부터 켜는 데 쓴다.
func look_at_point(where: Vector3) -> void:
    _focus = where


func sync() -> void:
    if _grid == null:
        return
    if _grid.version() != _last_version:
        _find_lamps()
        _last_version = _grid.version()
    _light_the_nearest()


func lit_count() -> int:
    return _lit.size()


## 지금 실제로 켜 둔 빛의 수.
func shining_count() -> int:
    var shining := 0
    for light in _lights:
        if light.visible:
            shining += 1
    return shining


func _find_lamps() -> void:
    _lit.clear()
    for z in VoxelGrid.SIZE_Z:
        for y in VoxelGrid.SIZE_Y:
            for x in VoxelGrid.SIZE_X:
                var cell := Vector3i(x, y, z)
                if _grid.get_block(cell) == BlockType.LAMP_LIT:
                    _lit.append(cell)


## 보고 있는 자리에서 가까운 것부터 켠다.
func _light_the_nearest() -> void:
    var ordered := _lit.duplicate()
    if ordered.size() > MAX_LIGHTS:
        ordered.sort_custom(_nearer)
        ordered.resize(MAX_LIGHTS)

    for i in _lights.size():
        var light := _lights[i]
        if i >= ordered.size():
            light.visible = false
            continue
        light.position = SimViewCoords.cell_to_world(ordered[i])
        light.visible = true


func _nearer(left: Vector3i, right: Vector3i) -> bool:
    return (SimViewCoords.cell_to_world(left) - _focus).length_squared() < (
        SimViewCoords.cell_to_world(right) - _focus).length_squared()
