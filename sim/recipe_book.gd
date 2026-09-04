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
## **묶음은 여기 없다.** 묶음은 재료로 만드는 것이 아니라 이미 지어 놓은 회로를
## 압축해 얻는다. 스펙 §4.3.
##
## 재료의 뜻은 스펙 §3.6 을 따른다. 목재는 기본 건축과 문, 광석은 부품 제작,
## 작물은 식량이다. 그래서 **부품에는 반드시 광석이 든다.** 광석 자원지는
## 기지에서 떨어져 있고, 그 왕복이 자동 운반 장치를 만들 이유가 된다.

## 만드는 법 하나. [만드는 것, 한 번에 나오는 개수, [[재료, 몇 개], ...]].
const RECIPES: Array = [
    [BlockType.DOOR_CLOSED, 1, [[BlockType.WOOD, 4]]],
    [BlockType.FIELD, 1, [[BlockType.GROUND, 3], [BlockType.WOOD, 1]]],
    [BlockType.DETECTOR, 1, [[BlockType.ORE, 2], [BlockType.WOOD, 1]]],
    [BlockType.ACTUATOR, 1, [[BlockType.ORE, 1], [BlockType.WOOD, 2]]],
    [BlockType.REPEATER, 1, [[BlockType.ORE, 3], [BlockType.WOOD, 1]]],
    [BlockType.BOX, 1, [[BlockType.WOOD, 3], [BlockType.ORE, 1]]],
    [BlockType.BRANCH, 1, [[BlockType.ORE, 2], [BlockType.WOOD, 2]]],
    # 등은 여럿 필요하다. 땅속을 밝히려면 몇 칸마다 하나씩 놓는다.
    [BlockType.LAMP_DARK, 2, [[BlockType.WOOD, 1], [BlockType.ORE, 1]]],
]

## 스펙이 정한 제작법 수의 상한.
const MAX_RECIPES := 10


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
