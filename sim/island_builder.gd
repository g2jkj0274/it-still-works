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

## 지면의 윗면 높이. 캐릭터는 그 위 칸에 선다.
const GROUND_TOP_Z := 1

const HILL_CENTER := Vector2i(44, 40)
const HILL_RADIUS := 9
const HILL_PEAK_RADIUS := 5

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

## 캐릭터가 처음 서는 칸.
const SPAWN := Vector3i(32, 32, GROUND_TOP_Z + 1)

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
    state.spawn = SPAWN
    state.character.place_at(SPAWN)
    state.character.facing = Vector3i(0, 1, 0)


## 판정에 필요한 것을 미리 쥐여 준다.
static func stock_starting_kit(inventory: Inventory) -> void:
    for block_type in [BlockType.GROUND, BlockType.STONE, BlockType.WOOD]:
        inventory.add(block_type, STARTING_BLOCKS)
    for part_type in [
        BlockType.DOOR_CLOSED, BlockType.FIELD, BlockType.DETECTOR,
        BlockType.ACTUATOR, BlockType.REPEATER, BlockType.BOX, BlockType.BRANCH,
    ]:
        inventory.add(part_type, STARTING_PARTS)
    inventory.add(BlockType.CROP, STARTING_CROPS)


static func build(grid: VoxelGrid) -> void:
    _fill_ground(grid)
    _raise_hill(grid)
    _place_ore(grid)
    _plant_trees(grid)
    _scatter_wild_crops(grid)


static func _fill_ground(grid: VoxelGrid) -> void:
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            if not _within(Vector2i(x, y), CENTER, ISLAND_RADIUS):
                continue
            for z in GROUND_TOP_Z + 1:
                grid.set_block(Vector3i(x, y, z), BlockType.GROUND)


static func _raise_hill(grid: VoxelGrid) -> void:
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            var column := Vector2i(x, y)
            if not _within(column, CENTER, ISLAND_RADIUS):
                continue
            if _within(column, HILL_CENTER, HILL_RADIUS):
                grid.set_block(Vector3i(x, y, GROUND_TOP_Z + 1), BlockType.GROUND)
            if _within(column, HILL_CENTER, HILL_PEAK_RADIUS):
                grid.set_block(Vector3i(x, y, GROUND_TOP_Z + 2), BlockType.GROUND)


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
                if not grid.is_solid(Vector3i(x, y, GROUND_TOP_Z)):
                    continue

                # 가운데로 갈수록 높다. 바깥 테두리는 한 칸, 한가운데는 세 칸.
                var offset := column - site
                var away := maxi(absi(offset.x), absi(offset.y))
                var height := ORE_SITE_RADIUS + 1 - away
                for step in height:
                    grid.set_block(Vector3i(x, y, GROUND_TOP_Z + 1 + step), BlockType.STONE)


static func _plant_trees(grid: VoxelGrid) -> void:
    for trunk in TREES:
        var base := Vector3i(trunk.x, trunk.y, GROUND_TOP_Z + 1)
        if not grid.is_solid(base - VoxelGrid.UP) or grid.is_solid(base):
            continue
        for offset in TREE_HEIGHT:
            grid.set_block(base + VoxelGrid.UP * offset, BlockType.WOOD)


## 저절로 난 작물을 시작 자리 둘레에 흩어 둔다.
static func _scatter_wild_crops(grid: VoxelGrid) -> void:
    for column in WILD_CROPS:
        var cell := Vector3i(column.x, column.y, GROUND_TOP_Z + 1)
        if not grid.is_solid(cell - VoxelGrid.UP) or grid.is_solid(cell):
            continue
        grid.set_block(cell, BlockType.CROP)


## 정수 거리 판정. 제곱 비교라 제곱근이 필요 없고 실수도 끼지 않는다.
static func _within(pos: Vector2i, center: Vector2i, radius: int) -> bool:
    var offset := pos - center
    return offset.x * offset.x + offset.y * offset.y <= radius * radius
