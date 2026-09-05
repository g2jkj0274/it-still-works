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

## 빛의 세기. 캄캄한 곳에서의 값이다.
const STRENGTH := 2.4

## 대낮 한복판에서 남는 세기의 몫.
##
## **한낮에도 같은 세기로 때리면 바닥이 하얗게 날아간다.** 그림에서는 켜진
## 등이 아니라 잘못 그려진 흰 상자로 보였다. 등이 값을 하는 곳은 밤과
## 땅속이고, 해가 떠 있을 때는 있는 듯 마는 듯해야 옳다.
const DAY_SHARE := 0.18

## 이만큼 묻히면 한밤중만큼 어둡다고 본다. [WorldView] 와 같은 값이다.
const DARK_DEPTH := 5.0

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
var _darkness: float = 1.0
var _last_darkness: float = -1.0


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


## 하늘이 얼마나 어두운가(0 한낮, 1 한밤). 등의 세기가 여기 딸린다.
func set_darkness(darkness: float) -> void:
    _darkness = clampf(darkness, 0.0, 1.0)


func sync() -> void:
    if _grid == null:
        return

    var version := _grid.version()
    if version != _last_version:
        _follow(version)
        _last_version = version
    _light_the_nearest()
    _last_darkness = _darkness


## 등 목록을 바뀐 칸만큼만 고친다.
##
## **세계를 통째로 훑고 있었다.** 9만 8천 칸을 삼중 루프로 도는 일이 블록을
## 하나 부술 때마다 벌어졌고, 누르고 있으면 초당 네 번이었다. 파고 내려가는
## 것이 새로 붙인 유인인데 그 동작이 프레임을 가장 자주 흔들었다.
##
## 변경 기록은 오래된 것을 버리므로([constant VoxelGrid.CHANGE_MEMORY]),
## 그보다 많이 밀렸으면 놓친 것이 있을 수 있다. 그때만 통째로 훑는다.
func _follow(version: int) -> void:
    if _last_version < 0 or version - _last_version > VoxelGrid.CHANGE_MEMORY:
        _find_lamps()
        return

    for change: Array in _grid.changes_since(_last_version):
        var cell: Vector3i = change[0]
        var was := int(change[1])
        var now := int(change[2])
        if now == BlockType.LAMP_LIT:
            if not _lit.has(cell):
                _lit.append(cell)
        elif was == BlockType.LAMP_LIT:
            _lit.erase(cell)


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
        light.light_energy = strength_at(ordered[i])
        light.visible = true


## 그 자리에 놓인 등이 낼 세기.
##
## 밤이거나 깊이 묻혔으면 온 힘을 낸다. 한낮 지표에서는 거의 내지 않는다.
## 땅속은 하늘이 밝아도 캄캄하므로 둘 가운데 어두운 쪽을 따른다.
func strength_at(cell: Vector3i) -> float:
    var buried := 0.0
    if _grid != null:
        var top := _grid.height_at(cell.x, cell.y)
        buried = clampf(float(top - cell.z) / DARK_DEPTH, 0.0, 1.0)
    var dark := maxf(_darkness, buried)
    return STRENGTH * lerpf(DAY_SHARE, 1.0, dark)


func _nearer(left: Vector3i, right: Vector3i) -> bool:
    return (SimViewCoords.cell_to_world(left) - _focus).length_squared() < (
        SimViewCoords.cell_to_world(right) - _focus).length_squared()
