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

## 캐릭터가 처음 서는 칸.
const SPAWN := Vector3i(32, 32, GROUND_TOP_Z + 1)


## 격자에 섬을 배치하고 캐릭터를 시작 위치에 세운다.
static func populate(state: WorldState) -> void:
    build(state.grid)
    state.character.position = SPAWN
    state.character.facing = Vector3i(0, 1, 0)


static func build(grid: VoxelGrid) -> void:
    _fill_ground(grid)
    _raise_hill(grid)
    _place_ore(grid)
    _plant_trees(grid)


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


static func _place_ore(grid: VoxelGrid) -> void:
    for site in ORE_SITES:
        for y in range(site.y - ORE_SITE_RADIUS, site.y + ORE_SITE_RADIUS + 1):
            for x in range(site.x - ORE_SITE_RADIUS, site.x + ORE_SITE_RADIUS + 1):
                var column := Vector2i(x, y)
                if not _within(column, site, ORE_SITE_RADIUS):
                    continue
                if not grid.is_solid(Vector3i(x, y, GROUND_TOP_Z)):
                    continue
                grid.set_block(Vector3i(x, y, GROUND_TOP_Z + 1), BlockType.STONE)


static func _plant_trees(grid: VoxelGrid) -> void:
    for trunk in TREES:
        var base := Vector3i(trunk.x, trunk.y, GROUND_TOP_Z + 1)
        if not grid.is_solid(base - VoxelGrid.UP) or grid.is_solid(base):
            continue
        for offset in TREE_HEIGHT:
            grid.set_block(base + VoxelGrid.UP * offset, BlockType.WOOD)


## 정수 거리 판정. 제곱 비교라 제곱근이 필요 없고 실수도 끼지 않는다.
static func _within(pos: Vector2i, center: Vector2i, radius: int) -> bool:
    var offset := pos - center
    return offset.x * offset.x + offset.y * offset.y <= radius * radius
