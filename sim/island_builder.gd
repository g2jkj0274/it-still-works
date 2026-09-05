class_name IslandBuilder
extends RefCounted

## 프로토타입 섬 하나를 격자에 배치한다.
##
## 수작업 배치다. 아래 상수들이 곧 지형 원본이며 난수를 쓰지 않는다.
## 절차적 생성으로 바꾸게 되면 반드시 시드 고정 RNG 를 거쳐야 한다.
##
## 초기 배치는 명령을 거치지 않는다. 명령을 거쳐야 하는 것은 입력에서 온
## 상태 변경이고, 이것은 월드를 세우는 일이다.

const CENTER := Vector2i(32, 32)
const ISLAND_RADIUS := 29

## 물가에서 이만큼 안쪽까지가 해안이다. 그 사이에서 지표가 해안 높이로 눕는다.
##
## 눕히지 않고 그냥 낮추면 해안선의 높이가 기복을 따라 들쭉날쭉해져서,
## 물낯을 어디에 두어도 어떤 곳은 잠기고 어떤 곳은 절벽이 된다.
const SHORE_BAND := 6

## 해안의 높이. 물낯은 이 바로 위에 놓인다.
const SHORE_Z := GROUND_TOP_Z - 2

## 평지의 윗면 높이. 캐릭터는 그 위 칸에 선다.
##
## 예전에는 1 이었다. 세계가 세로로 스물넷인데 두 층만 쓰고 있었고, 바닥층은
## 부술 수 없으므로 **팔 수 있는 땅이 한 층뿐이었다.** 파고 내려갈 곳이 없으니
## 캐는 일이 성립하지 않았다.
const GROUND_TOP_Z := 8

## 흙은 지표에서 이만큼만이다. 그 아래는 돌이다.
const SOIL_DEPTH := 2

## 기복의 폭. 지표가 이 사이에서 오르내린다.
const RELIEF := 3

## 기복 격자의 간격. 진폭의 두 배보다 넓어야 한 칸 넘는 턱이 생기지 않는다.
const RELIEF_SPAN := 8

## 이어 붙인 값의 눈금.
const SMOOTH_SCALE := 1000

## 언덕. 기복 위에 더 얹는다.
const HILL_CENTER := Vector2i(44, 40)
const HILL_RADIUS := 9
const HILL_PEAK_RADIUS := 5

## 이 깊이 아래에만 광맥이 든다. 얕은 곳에서 나오면 내려갈 이유가 없다.
const VEIN_TOP_Z := 6

## 광맥이 드는 문턱. 이 값을 넘는 곳에 든다. 깊을수록 문턱이 내려간다.
const VEIN_LEVEL := 760
const VEIN_LEVEL_PER_DEPTH := 34
const VEIN_SPAN_XY := 5
const VEIN_SPAN_Z := 3

## 동굴 벽에서 문턱이 이만큼 내려간다.
##
## **땅속에 들어갈 까닭이 있어야 한다.** 광맥이 바위 속에만 들면 굴을 파고
## 들어가도 회색 벽뿐이라, 어디를 파야 할지 알 수 없고 그저 아무 데나 파게
## 된다. 드러난 벽에 광석이 박혀 있으면 눈이 목적지를 잡는다 — 그것이
## 땅속을 다니는 이유가 된다.
const VEIN_LEVEL_AT_WALL := 120

## 동굴이 뚫리는 문턱과 뚫릴 수 있는 깊이.
const CAVE_LEVEL := 640
const CAVE_TOP_Z := 7
const CAVE_SPAN_XY := 7
const CAVE_SPAN_Z := 3

## 광석 자원지. 기지에서 떨어져 있어야 왕복이 자동 운반 장치의 동기가 된다.
const ORE_SITES: Array[Vector2i] = [
    Vector2i(18, 47),
    Vector2i(49, 19),
    Vector2i(17, 19),
]
const ORE_SITE_RADIUS := 2

## 나무 줄기 위치. 섬 곳곳에 손으로 찍었다.
const TREES: Array[Vector2i] = [
    Vector2i(22, 26),
    Vector2i(26, 40),
    Vector2i(38, 22),
    Vector2i(44, 52),
    Vector2i(52, 34),
    Vector2i(20, 34),
    Vector2i(34, 50),
    Vector2i(46, 28),
    Vector2i(28, 20),
    Vector2i(30, 46),
]
const TREE_HEIGHT := 3

## 저절로 난 작물. 손으로 뜯어 먹을 수 있다.
##
## 이것이 없으면 **첫날 밤에 닿을 수가 없다.** 배는 4분에 비고 5분 40초에
## 쓰러지는데 첫 밤은 7분에 온다. 그런데 밭에서 거두는 것은 작동기뿐이고
## (스펙 §3.6) 작동기를 만들려면 스무 칸 밖 광석 자원지를 다녀와야 한다.
##
## 시작 자리 둘레에 흩어 둔다. 몇 개는 첫 화면에 보인다.
##
## **다시 나지 않는다.** 그래서 첫날은 이것으로 넘기고 둘째 날부터는 밭과
## 작동기가 필요해진다. 스펙 §6 의 완료 판정 기준이 겨누는 자리가 거기다.
##
## 언덕이나 자원지와 겹치면 놓이지 않는다. 하나라도 빠지면 테스트가 잡는다.
const WILD_CROPS: Array[Vector2i] = [
    Vector2i(29, 30), Vector2i(35, 30), Vector2i(31, 27), Vector2i(34, 36),
    Vector2i(28, 35), Vector2i(36, 34), Vector2i(30, 38), Vector2i(37, 29),
    Vector2i(27, 32), Vector2i(38, 33), Vector2i(33, 25), Vector2i(25, 29),
    Vector2i(39, 28), Vector2i(26, 38),
]

## 캐릭터가 처음 서는 기둥. 높이는 그 자리의 지표를 따라간다.
const SPAWN_COLUMN := Vector2i(32, 32)

## 시작할 때 손에 무언가를 쥐여 줄 것인가.
##
## 이 게임은 **빈손으로 시작한다.** 첫 블록은 손으로 부숴 얻는다(스펙 §3.1).
##
## 한동안은 켜 두었다. 부품을 만들 방법이 없어 회로를 시험해 볼 길이 없었기
## 때문이다. **제작법이 생겨 껐다.** 이제 나무를 부수고 광석을 캐서 만든다.
##
## 손으로 살펴볼 일이 있으면 잠깐 켜도 된다. 다만 켠 채로 두면 광석 자원지가
## 뜻을 잃는다. 왕복이 자동 운반 장치를 만들 이유이기 때문이다(스펙 §3.6).
const GIVE_STARTING_KIT := false

const STARTING_PARTS := 20
const STARTING_BLOCKS := 64
const STARTING_CROPS := 8


## 새 판 하나. 시뮬레이션을 만들고 섬을 세워 돌려준다.
##
## 게임 화면과 불러오기가 같은 자리에서 판을 시작해야 한다. 두 곳에서 따로
## 세우면 언젠가 어긋나고, 그러면 불러온 판이 저장한 판과 달라진다.
static func start(p_seed: int) -> Simulation:
    var simulation := Simulation.new(p_seed)
    populate(simulation.state)
    return simulation


## 격자에 섬을 배치하고 캐릭터를 시작 위치에 세운다.
static func populate(state: WorldState) -> void:
    build(state.grid)
    if GIVE_STARTING_KIT:
        stock_starting_kit(state.inventory)
    state.spawn = spawn_cell()
    state.character.place_at(state.spawn)
    state.character.facing = Vector3i(0, 1, 0)


## 캐릭터가 처음 서는 칸. 지표 바로 위다.
static func spawn_cell() -> Vector3i:
    return Vector3i(SPAWN_COLUMN.x, SPAWN_COLUMN.y, surface_z(SPAWN_COLUMN) + 1)


## 판정에 필요한 것을 미리 쥐여 준다.
static func stock_starting_kit(inventory: Inventory) -> void:
    for block_type in [BlockType.GROUND, BlockType.ORE, BlockType.WOOD]:
        inventory.add(block_type, STARTING_BLOCKS)
    for part_type in [
        BlockType.DOOR_CLOSED, BlockType.FIELD, BlockType.DETECTOR,
        BlockType.ACTUATOR, BlockType.REPEATER, BlockType.BOX, BlockType.BRANCH,
    ]:
        inventory.add(part_type, STARTING_PARTS)
    inventory.add(BlockType.CROP, STARTING_CROPS)


static func build(grid: VoxelGrid) -> void:
    _fill_ground(grid)
    _carve_caves(grid)
    _seed_veins(grid)
    _place_ore(grid)
    _plant_trees(grid)
    _scatter_wild_crops(grid)


## 그 기둥의 지표 높이. 기복과 언덕을 함께 친다.
##
## 좌표에서 뽑는다. 난수를 쓰지 않으므로 실행마다 같은 섬이 나온다.
## 시뮬레이션의 RNG 를 당겨 쓰면 그 순간 결정론의 뜻이 흐려진다.
static func surface_z(column: Vector2i) -> int:
    if not _within(column, CENTER, ISLAND_RADIUS):
        return -1

    var height := GROUND_TOP_Z + _relief_at(column)

    # 물가로 갈수록 해안 높이로 눕는다. 해안선이 고르게 이어져야 물낯을 둘 수 있다.
    #
    # 거리를 정수로 어림하므로 맨 바깥 줄이 한 칸 안쪽으로 잡히기도 한다.
    # 그래서 한 칸을 더 물려 물가 두 줄이 확실히 해안 높이가 되게 한다.
    var edge := ISLAND_RADIUS - _distance_to(column, CENTER)
    var blend := clampi(edge - 1, 0, SHORE_BAND)
    if blend < SHORE_BAND:
        height = SHORE_Z + (height - SHORE_Z) * blend / SHORE_BAND

    # 언덕은 한 칸씩 오른다. 한 번에 두 칸 솟으면 그 위로 올라갈 길이 없다.
    var to_hill := _distance_to(column, HILL_CENTER)
    if to_hill <= HILL_RADIUS:
        height += (HILL_RADIUS - to_hill + 1) / 2

    return clampi(height, VoxelGrid.BEDROCK_Z + 1, VoxelGrid.SIZE_Z - 4)


## 완만한 기복.
##
## **이웃한 기둥끼리 한 칸 넘게 벌어지면 안 된다.** 캐릭터는 한 칸 턱만 오르므로
## (스펙 §3.3) 두 칸 절벽이 생기면 그 위로 올라갈 길이 없다. 그래서 성긴 격자에
## 값을 두고 그 사이를 곧게 이어 채운다. 격자 간격이 진폭의 두 배보다 넓으면
## 기울기가 1 을 넘지 않는다.
static func _relief_at(column: Vector2i) -> int:
    var raised := _smooth(Vector3i(column.x, column.y, 0), RELIEF_SPAN, 1, 7)
    return raised * (RELIEF * 2) / SMOOTH_SCALE - RELIEF


## 성긴 격자 위의 값을 곧게 이어 0..[constant SMOOTH_SCALE] 로 돌려준다.
##
## 칸마다 따로 뽑으면 소금을 뿌린 것처럼 되어 지형도 동굴도 이어지지 않는다.
## 사이를 이어야 언덕이 언덕이 되고 동굴이 동굴이 된다.
static func _smooth(cell: Vector3i, span_xy: int, span_z: int, salt: int) -> int:
    var gx := cell.x / span_xy
    var gy := cell.y / span_xy
    var gz := cell.z / span_z
    var fx := cell.x % span_xy
    var fy := cell.y % span_xy
    var fz := cell.z % span_z

    var near := _lerp_plane(gx, gy, gz, fx, fy, span_xy, salt)
    if span_z <= 1:
        return near
    var far := _lerp_plane(gx, gy, gz + 1, fx, fy, span_xy, salt)
    return (near * (span_z - fz) + far * fz) / span_z


static func _lerp_plane(gx: int, gy: int, gz: int, fx: int, fy: int, span: int, salt: int) -> int:
    var top := _corner(gx, gy, gz, salt) * (span - fx) + _corner(gx + 1, gy, gz, salt) * fx
    var bottom := _corner(gx, gy + 1, gz, salt) * (span - fx) + _corner(gx + 1, gy + 1, gz, salt) * fx
    return (top * (span - fy) + bottom * fy) / (span * span)


static func _corner(gx: int, gy: int, gz: int, salt: int) -> int:
    return _noise(Vector3i(gx, gy, gz * 31 + salt)) % (SMOOTH_SCALE + 1)


static func _fill_ground(grid: VoxelGrid) -> void:
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            var column := Vector2i(x, y)
            var top := surface_z(column)
            if top < 0:
                continue
            for z in top + 1:
                # 지표 가까이는 흙, 그 아래는 돌. 바닥층은 부술 수 없는 돌이다.
                var kind := BlockType.GROUND if z > top - SOIL_DEPTH else BlockType.ROCK
                grid.set_block(Vector3i(x, y, z), kind)


## 땅속에 빈 곳을 판다. 파고 내려갈 이유가 되고, 광맥이 드러나는 자리가 된다.
static func _carve_caves(grid: VoxelGrid) -> void:
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            var column := Vector2i(x, y)
            var top := surface_z(column)
            if top < 0:
                continue
            for z in range(VoxelGrid.BEDROCK_Z + 1, mini(CAVE_TOP_Z, top - SOIL_DEPTH)):
                var cell := Vector3i(x, y, z)
                if _smooth(cell, CAVE_SPAN_XY, CAVE_SPAN_Z, 41) < CAVE_LEVEL:
                    continue
                grid.set_block(cell, BlockType.EMPTY)


## 돌 사이에 광맥을 심는다. 깊을수록 흔하다.
static func _seed_veins(grid: VoxelGrid) -> void:
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            for z in range(VoxelGrid.BEDROCK_Z + 1, VEIN_TOP_Z + 1):
                var cell := Vector3i(x, y, z)
                if grid.get_block(cell) != BlockType.ROCK:
                    continue
                var depth := VEIN_TOP_Z - z
                var level := VEIN_LEVEL - depth * VEIN_LEVEL_PER_DEPTH
                # 드러난 벽에는 더 잘 든다. 광석을 바위에 묻어 두면 땅속에
                # 들어갈 까닭이 없다.
                if _is_bare(grid, cell):
                    level -= VEIN_LEVEL_AT_WALL
                if _smooth(cell, VEIN_SPAN_XY, VEIN_SPAN_Z, 83) >= level:
                    grid.set_block(cell, BlockType.ORE)


## 그 칸이 빈 곳에 맞닿아 밖에서 보이는가.
##
## 광석을 넣어도 빈 칸이 되지는 않으므로, 넣는 차례가 결과를 바꾸지 않는다.
static func _is_bare(grid: VoxelGrid, cell: Vector3i) -> bool:
    for step: Vector3i in _NEIGHBOURS:
        if grid.get_block(cell + step) == BlockType.EMPTY:
            return true
    return false


## 맞닿은 여섯 쪽. 차례가 결과를 바꾸지 않지만 늘 같아야 한다.
const _NEIGHBOURS: Array[Vector3i] = [
    Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
    Vector3i(0, 1, 0), Vector3i(0, -1, 0),
    Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


## 자리에서 뽑은 값. 난수가 아니라 뒤섞기라 실행마다 같은 섬이 나온다.
static func _noise(cell: Vector3i) -> int:
    var mixed := cell.x * 374761393 + cell.y * 668265263 + cell.z * 1442695041
    mixed = (mixed ^ (mixed >> 13)) * 1274126177
    return absi(mixed ^ (mixed >> 16))


## 정수 거리. 제곱근을 쓰지 않으려고 어림으로 잡는다.
static func _distance_to(pos: Vector2i, centre: Vector2i) -> int:
    var offset := pos - centre
    var squared := offset.x * offset.x + offset.y * offset.y
    var guess := 0
    while (guess + 1) * (guess + 1) <= squared:
        guess += 1
    return guess


## 광석 자원지를 놓는다. 가운데가 솟은 더미로 쌓는다.
##
## 납작하게 깔면 스무 칸 밖에서 보이지 않는다. **갈 곳을 모르면 왕복이
## 시작되지 않고**, 그러면 자원지를 멀리 둔 뜻(§3.6)이 통째로 사라진다.
## 솟아 있으면 지형이 스스로 "저기 뭔가 있다"고 말한다.
static func _place_ore(grid: VoxelGrid) -> void:
    for site in ORE_SITES:
        for y in range(site.y - ORE_SITE_RADIUS, site.y + ORE_SITE_RADIUS + 1):
            for x in range(site.x - ORE_SITE_RADIUS, site.x + ORE_SITE_RADIUS + 1):
                var column := Vector2i(x, y)
                if not _within(column, site, ORE_SITE_RADIUS):
                    continue
                var top := surface_z(column)
                if top < 0:
                    continue

                # 가운데로 갈수록 높다. 바깥 테두리는 한 칸, 한가운데는 세 칸.
                var offset := column - site
                var away := maxi(absi(offset.x), absi(offset.y))
                var height := ORE_SITE_RADIUS + 1 - away
                for step in height:
                    grid.set_block(Vector3i(x, y, top + 1 + step), BlockType.ORE)


static func _plant_trees(grid: VoxelGrid) -> void:
    for trunk in TREES:
        var top := surface_z(trunk)
        if top < 0:
            continue
        var base := Vector3i(trunk.x, trunk.y, top + 1)
        if not grid.is_solid(base - VoxelGrid.UP) or grid.is_solid(base):
            continue
        for offset in TREE_HEIGHT:
            grid.set_block(base + VoxelGrid.UP * offset, BlockType.WOOD)


## 저절로 난 작물을 시작 자리 둘레에 흩어 둔다.
static func _scatter_wild_crops(grid: VoxelGrid) -> void:
    for column in WILD_CROPS:
        var top := surface_z(column)
        if top < 0:
            continue
        var cell := Vector3i(column.x, column.y, top + 1)
        if not grid.is_solid(cell - VoxelGrid.UP) or grid.is_solid(cell):
            continue
        grid.set_block(cell, BlockType.CROP)


## 정수 거리 판정. 제곱 비교라 제곱근이 필요 없고 실수도 끼지 않는다.
static func _within(pos: Vector2i, center: Vector2i, radius: int) -> bool:
    var offset := pos - center
    return offset.x * offset.x + offset.y * offset.y <= radius * radius
