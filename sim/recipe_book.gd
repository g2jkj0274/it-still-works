class_name RecipeBook
extends RefCounted

## 무엇을 무엇으로 만드는가. 스펙 §6 은 열 개 이내로 못박는다.
##
## 딕셔너리가 아니라 순서 있는 배열이다. 순회 순서가 흔들리면 같은 재료로도
## 실행마다 다른 것이 만들어질 수 있다.
##
## 만드는 데 걸리는 시간은 없다. 재료가 있으면 그 틱에 만들어진다. 제작대도
## 없다. 프로토타입에서 회로가 코어이고 나머지는 최소한만 둔다는 원칙을 따른다.
##
## 재료의 뜻은 스펙 §3.6 을 따른다. 나무는 판자가 되어 거의 모든 것에 들고,
## 광석은 부품 제작, 작물은 식량이다. 그래서 **부품에는 반드시 광석이 든다.**
## 광석 자원지는 기지에서 떨어져 있고, 그 왕복이 자동 운반 장치를 만들 이유가 된다.

## 만드는 자리. **어디서 만들 수 있는가가 곧 테크트리의 마디다**(스펙 §3.6).
##
## 재료만으로는 층이 생기지 않는다. 손으로 만들 수 있는 것과 화로가 있어야
## 하는 것이 갈려야 "회로가 없으면 못 하는 것"이 무엇인지 분명해진다.
const HAND := 0
const FURNACE := 1
const BENCH := 2

## 작업대가 손에 닿는 거리(칸).
const BENCH_REACH := 3

## 만드는 법 하나. [만드는 것, 개수, [[재료, 몇 개], ...], 만드는 자리].
##
## 차례가 곧 만들기 화면에서 도는 차례다. **쉬운 것부터, 첫날에 쓰는 것부터.**
const RECIPES: Array = [
    # 나무 하나가 판자 넷이 된다. 이 환율이 첫날 예산을 세운다.
    # 판자는 아래 열다섯 가운데 열둘에 든다 — 사실상 모든 것의 뿌리다.
    [BlockType.PLANK, 4, [[BlockType.WOOD, 1]], HAND],

    # 도구. 맞는 곡괭이가 없으면 돌도 광석도 부숴지지 않는다(ToolRules).
    [BlockType.WOOD_PICK, 1, [[BlockType.PLANK, 3]], HAND],
    [BlockType.STONE_PICK, 1, [[BlockType.PLANK, 2], [BlockType.ROCK, 3]], HAND],
    [BlockType.STONE_AXE, 1, [[BlockType.PLANK, 2], [BlockType.ROCK, 3]], HAND],
    [BlockType.STONE_SHOVEL, 1, [[BlockType.PLANK, 2], [BlockType.ROCK, 1]], HAND],

    # 관솔불. 첫 굴의 빛이다. 등과 달리 광석이 들지 않아 나무 곡괭이만으로 닿는다.
    [BlockType.TORCH, 4, [[BlockType.PLANK, 1], [BlockType.EMBER, 1]], HAND],

    [BlockType.DOOR_CLOSED, 1, [[BlockType.PLANK, 4]], HAND],
    [BlockType.FIELD, 1, [[BlockType.GROUND, 3], [BlockType.PLANK, 1]], HAND],
    [BlockType.DETECTOR, 1, [[BlockType.ORE, 2], [BlockType.PLANK, 1]], HAND],
    [BlockType.ACTUATOR, 1, [[BlockType.ORE, 1], [BlockType.PLANK, 2]], HAND],
    [BlockType.REPEATER, 1, [[BlockType.ORE, 3], [BlockType.PLANK, 1]], HAND],
    [BlockType.BOX, 1, [[BlockType.PLANK, 3], [BlockType.ORE, 1]], HAND],
    [BlockType.BRANCH, 1, [[BlockType.ORE, 2], [BlockType.PLANK, 2]], HAND],
    # 등은 여럿 필요하다. 땅속을 밝히려면 몇 칸마다 하나씩 놓는다.
    [BlockType.LAMP_DARK, 2, [[BlockType.PLANK, 1], [BlockType.ORE, 1]], HAND],
    # 궤짝. 손이 모자란 것이 짜증이 아니라 살림이 되려면 넣어 둘 곳이 있어야 한다.
    [BlockType.CHEST, 1, [[BlockType.PLANK, 6]], HAND],
    # 화로. 손으로 세우지만 손으로 돌리지는 못한다.
    [BlockType.FURNACE, 1, [[BlockType.ROCK, 8]], HAND],

    # ── 화로에서. 작동기가 때려야 돈다 ──────────────────────────
    [BlockType.INGOT, 1, [[BlockType.ORE, 1], [BlockType.EMBER, 1]], FURNACE],
    [BlockType.BRICK, 1, [[BlockType.ROCK, 1], [BlockType.EMBER, 1]], FURNACE],
    [BlockType.GLASS, 1, [[BlockType.SAND, 1], [BlockType.EMBER, 1]], FURNACE],
    # 구우면 포만도가 두 배다. 밥걱정이 준다.
    [BlockType.COOKED_CROP, 1, [[BlockType.CROP, 1], [BlockType.EMBER, 1]], FURNACE],

    # ── 작업대에서. 쇳덩이가 드는 것 ────────────────────────────
    [BlockType.BENCH, 1, [[BlockType.PLANK, 4], [BlockType.INGOT, 2]], HAND],
    [BlockType.IRON_PICK, 1, [[BlockType.PLANK, 2], [BlockType.INGOT, 3]], BENCH],
    [BlockType.IRON_AXE, 1, [[BlockType.PLANK, 2], [BlockType.INGOT, 3]], BENCH],
    [BlockType.IRON_DOOR_CLOSED, 1, [[BlockType.INGOT, 4]], BENCH],
]

## 스펙이 정한 제작법 수의 상한.
##
## 열 개였다. 아홉을 쓰고 있었고 그 아홉이 두 단짜리 평면이라 파낸 돌에 쓸
## 곳이 없고 깊이 내려갈 이유가 없었다. 스펙 §6 이 서른다섯으로 다시 잡았고
## 여기 열다섯은 그 가운데 0~2단이다.
const MAX_RECIPES := 35


static func count() -> int:
    return RECIPES.size()


static func is_index(index: int) -> bool:
    return index >= 0 and index < RECIPES.size()


static func output_of(index: int) -> int:
    if not is_index(index):
        return BlockType.EMPTY
    return int(RECIPES[index][0])


static func yield_of(index: int) -> int:
    if not is_index(index):
        return 0
    return int(RECIPES[index][1])


## 그 법에 드는 재료들. [[재료, 몇 개], ...] 이고 적어 둔 차례 그대로다.
## 그것을 어디서 만드는가.
static func station_of(index: int) -> int:
    if not is_index(index):
        return HAND
    return int(RECIPES[index][3])


## 손에 든 것으로 그 자리에서 만들 수 있는 첫 제작법. 없으면 -1.
##
## **차례가 곧 우선순위다.** 적어 둔 차례가 고정이므로 언제 돌려도 같은 것이
## 나온다. 화로가 무엇을 구울지 여기서 정해진다.
static func first_makeable(inventory: Inventory, station: int) -> int:
    for i in RECIPES.size():
        if station_of(i) != station:
            continue
        if has_materials(inventory, i) and inventory.has_room_for(output_of(i)):
            return i
    return -1


static func inputs_of(index: int) -> Array:
    if not is_index(index):
        return []
    return (RECIPES[index][2] as Array).duplicate(true)


## 그것을 만드는 법의 번호. 만들 수 없는 것이면 -1.
static func index_for(block_type: int) -> int:
    for i in RECIPES.size():
        if int(RECIPES[i][0]) == block_type:
            return i
    return -1


static func can_be_made(block_type: int) -> bool:
    return index_for(block_type) >= 0


## 손에 든 것으로 그것을 만들 수 있는가.
static func has_materials(inventory: Inventory, index: int) -> bool:
    if not is_index(index):
        return false
    for entry: Array in RECIPES[index][2] as Array:
        if inventory.count_of(int(entry[0])) < int(entry[1]):
            return false
    return true


## 만든다. 재료가 하나라도 모자라면 **아무것도 쓰지 않고** 실패한다.
##
## 반쯤 쓰고 실패하면 재료만 사라진다. 되돌릴 길이 없으므로 먼저 다 보고 뺀다.
static func make(inventory: Inventory, index: int) -> bool:
    if not has_materials(inventory, index):
        return false
    # 만든 것을 받을 자리도 있어야 한다. 재료만 쓰고 결과가 사라지면 안 된다.
    if not inventory.has_room_for(output_of(index)):
        return false

    for entry: Array in RECIPES[index][2] as Array:
        inventory.take(int(entry[0]), int(entry[1]))
    inventory.add(output_of(index), yield_of(index))
    return true
