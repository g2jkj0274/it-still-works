class_name RecipeBook
extends RefCounted

## 무엇을 무엇으로 만드는가.
##
## **재료를 격자에 놓아 만든다.** 목록에서 골라 누르는 방식이었다. 그러면
## 만드는 일이 "스물넉 줄에서 하나 찾기"가 되어, 제작법이 늘수록 나빠지기만
## 한다. 마인크래프트가 삼십 년 가까이 격자를 쓰는 까닭은 **놓는 자리가 곧
## 기억**이기 때문이다. 곡괭이 모양은 한 번 배우면 잊히지 않는다.
##
## 짜임은 두 가지다.
##
## - **모양이 있는 것**(SHAPED): 어디에 놓느냐가 뜻을 갖는다. 곡괭이와 도끼는
##   재료가 같고 모양만 다르다. 좌우를 뒤집은 것도 같은 것으로 본다
## - **모양이 없는 것**(SHAPELESS): 무엇을 몇 개 놓았는지만 본다. 나무를
##   판자로 쪼개는 데 자리가 무슨 상관인가
##
## **만드는 자리는 크기가 정한다.** 두 칸 안에 들어가면 손으로 만들고, 그보다
## 크면 작업대가 있어야 한다. 따로 "이건 작업대에서만" 이라고 적어 두지
## 않는다 — 마인크래프트가 그렇고, 그래야 규칙이 하나뿐이라 외울 것이 없다.
##
## 굽는 것은 격자에 놓지 않는다. 화로는 재료를 받아 굽는 것이지 모양을 만드는
## 것이 아니다(스펙 §3.6). 그것만 따로 아래 [constant SMELTING] 에 있다.
##
## 딕셔너리를 쓰지 않는다. 순회 순서가 흔들리면 같은 재료로도 실행마다 다른
## 것이 만들어질 수 있다. 전부 차례 있는 배열이다.

## 만드는 자리.
const HAND := 0
const FURNACE := 1
const BENCH := 2

## 작업대가 손에 닿는 거리(칸).
const BENCH_REACH := 3

## 격자 한 변의 최대 칸 수. 작업대가 이만큼이다.
const GRID_SIZE := 3

## 손으로 쓰는 격자 한 변의 칸 수.
const HAND_SIZE := 2

## 격자 칸 수. 손이든 작업대든 같은 그릇을 쓰고 손은 왼쪽 위만 쓴다.
const GRID_SLOTS := GRID_SIZE * GRID_SIZE

## 짜임.
const SHAPED := 0
const SHAPELESS := 1

## 빈 칸. 무늬 안에서만 쓴다. 무늬가 눈으로 읽혀야 하므로 짧게 잡는다.
const NONE := BlockType.EMPTY

## 만드는 법 하나. [만드는 것, 개수, 짜임, 무늬].
##
## 모양이 있는 것의 무늬는 **줄의 배열**이고, 줄 하나는 블록 종류의 배열이다.
## 모양이 없는 것의 무늬는 재료 하나에 한 자리씩 늘어놓은 평평한 배열이다.
##
## 칸 하나는 재료 하나를 쓴다. 그래서 무늬에 놓인 칸 수가 곧 드는 재료 수다.
##
## 차례가 곧 만들기 책에 뜨는 차례다. **쉬운 것부터, 첫날에 쓰는 것부터.**
const RECIPES: Array = [
    # 나무 하나가 판자 넷이 된다. 이 환율이 첫날 예산을 세운다.
    # 쪼개는 데 자리가 무슨 상관인가 — 모양이 없다.
    [BlockType.PLANK, 4, SHAPELESS, [BlockType.WOOD]],

    # 작업대. **판자 넷, 첫날.** 이것이 서야 세 칸짜리 무늬에 손이 닿는다.
    # 쇳덩이를 물려 두었더니 화로가 먼저 필요했고, 화로는 회로가 있어야
    # 도는 것이라 첫 곡괭이조차 못 만드는 매듭이 됐다.
    [BlockType.BENCH, 1, SHAPED, [
        [BlockType.PLANK, BlockType.PLANK],
        [BlockType.PLANK, BlockType.PLANK],
    ]],

    # 문. 판자 여섯을 두 줄로 세운다. 작업대와 같은 넉 장 이 대 이로 두었더니
    # 무늬가 겹쳐서 둘 중 하나는 영영 만들 수 없었다. 마인크래프트의 문도
    # 이 모양이고, 세로가 셋이라 작업대가 있어야 한다.
    [BlockType.DOOR_CLOSED, 1, SHAPED, [
        [BlockType.PLANK, BlockType.PLANK],
        [BlockType.PLANK, BlockType.PLANK],
        [BlockType.PLANK, BlockType.PLANK],
    ]],

    # 관솔불. 불씨돌을 판자 위에 얹는다. 첫 굴의 빛이다.
    [BlockType.TORCH, 4, SHAPED, [
        [BlockType.EMBER],
        [BlockType.PLANK],
    ]],

    # 등. 광석을 판자 위에 얹는다. 관솔불과 나란한 모양이라 견주어 외운다.
    [BlockType.LAMP_DARK, 2, SHAPED, [
        [BlockType.ORE],
        [BlockType.PLANK],
    ]],

    # ── 도구. 날이 위에 서고 자루가 아래로 내린다 ────────────────
    [BlockType.WOOD_PICK, 1, SHAPED, [
        [BlockType.PLANK, BlockType.PLANK, BlockType.PLANK],
    ]],
    [BlockType.STONE_PICK, 1, SHAPED, [
        [BlockType.ROCK, BlockType.ROCK, BlockType.ROCK],
        [NONE, BlockType.PLANK, NONE],
        [NONE, BlockType.PLANK, NONE],
    ]],
    [BlockType.STONE_AXE, 1, SHAPED, [
        [BlockType.ROCK, BlockType.ROCK],
        [BlockType.ROCK, BlockType.PLANK],
        [NONE, BlockType.PLANK],
    ]],
    [BlockType.STONE_SHOVEL, 1, SHAPED, [
        [BlockType.ROCK],
        [BlockType.PLANK],
        [BlockType.PLANK],
    ]],

    # ── 살림 ────────────────────────────────────────────────
    [BlockType.FIELD, 1, SHAPED, [
        [BlockType.GROUND, BlockType.GROUND, BlockType.GROUND],
        [NONE, BlockType.PLANK, NONE],
    ]],
    [BlockType.CHEST, 1, SHAPED, [
        [BlockType.PLANK, BlockType.PLANK, BlockType.PLANK],
        [BlockType.PLANK, BlockType.PLANK, BlockType.PLANK],
    ]],
    # 화로. 돌 여덟이 가운데를 비우고 두른다.
    [BlockType.FURNACE, 1, SHAPED, [
        [BlockType.ROCK, BlockType.ROCK, BlockType.ROCK],
        [BlockType.ROCK, NONE, BlockType.ROCK],
        [BlockType.ROCK, BlockType.ROCK, BlockType.ROCK],
    ]],

    # ── 부품 다섯. **광석이 반드시 든다**(스펙 §3.6) ──────────────
    # 광석이 눈처럼 둘, 그 아래 판자.
    [BlockType.DETECTOR, 1, SHAPED, [
        [BlockType.ORE, BlockType.ORE],
        [NONE, BlockType.PLANK],
    ]],
    # 광석 하나가 판자 둘 위에 얹혀 때린다.
    [BlockType.ACTUATOR, 1, SHAPED, [
        [NONE, BlockType.ORE],
        [BlockType.PLANK, BlockType.PLANK],
    ]],
    # 광석 셋이 줄지어 돈다.
    [BlockType.REPEATER, 1, SHAPED, [
        [BlockType.ORE, BlockType.ORE, BlockType.ORE],
        [NONE, BlockType.PLANK, NONE],
    ]],
    # 판자로 담을 두르고 광석 하나를 담는다.
    [BlockType.BOX, 1, SHAPED, [
        [BlockType.PLANK, BlockType.PLANK, BlockType.PLANK],
        [NONE, BlockType.ORE, NONE],
    ]],
    # 길이 둘로 갈린다. 어긋나게 놓는다.
    [BlockType.BRANCH, 1, SHAPED, [
        [BlockType.ORE, BlockType.PLANK],
        [BlockType.PLANK, BlockType.ORE],
    ]],

    # ── 쇠. 화로가 돌아야 닿는다 ─────────────────────────────
    [BlockType.IRON_PICK, 1, SHAPED, [
        [BlockType.INGOT, BlockType.INGOT, BlockType.INGOT],
        [NONE, BlockType.PLANK, NONE],
        [NONE, BlockType.PLANK, NONE],
    ]],
    [BlockType.IRON_AXE, 1, SHAPED, [
        [BlockType.INGOT, BlockType.INGOT],
        [BlockType.INGOT, BlockType.PLANK],
        [NONE, BlockType.PLANK],
    ]],
    # 튼튼한 문. 쇳덩이 여섯을 두 줄로 세운다.
    [BlockType.IRON_DOOR_CLOSED, 1, SHAPED, [
        [BlockType.INGOT, BlockType.INGOT],
        [BlockType.INGOT, BlockType.INGOT],
        [BlockType.INGOT, BlockType.INGOT],
    ]],
]

## 굽는 법. [굽는 것, 개수, [[재료, 몇 개], ...]].
##
## 격자에 놓지 않는다. 화로는 모양을 만드는 것이 아니라 재료를 받아 굽는다.
## **손으로는 못 돌린다.** 작동기가 때려야 한 번 돈다(스펙 §3.6).
const SMELTING: Array = [
    [BlockType.INGOT, 1, [[BlockType.ORE, 1], [BlockType.EMBER, 1]]],
    [BlockType.BRICK, 1, [[BlockType.ROCK, 1], [BlockType.EMBER, 1]]],
    [BlockType.GLASS, 1, [[BlockType.SAND, 1], [BlockType.EMBER, 1]]],
    # 구우면 포만도가 두 배다. 밥걱정이 준다.
    [BlockType.COOKED_CROP, 1, [[BlockType.CROP, 1], [BlockType.EMBER, 1]]],
]

## 스펙이 정한 제작법 수의 상한.
const MAX_RECIPES := 35


## 격자에 놓아 만드는 법의 수.
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


static func form_of(index: int) -> int:
    if not is_index(index):
        return SHAPELESS
    return int(RECIPES[index][2])


## 그 법의 무늬. 모양이 있으면 줄의 배열, 없으면 재료의 평평한 배열.
static func pattern_of(index: int) -> Array:
    if not is_index(index):
        return []
    return RECIPES[index][3]


## 무늬가 몇 칸을 차지하는가. [가로, 세로].
static func size_of(index: int) -> Vector2i:
    if form_of(index) == SHAPELESS:
        # 늘어놓기만 하면 되므로 재료 수만큼 칸이 있으면 된다.
        var loose: Array = pattern_of(index)
        if loose.size() <= HAND_SIZE * HAND_SIZE:
            return Vector2i(HAND_SIZE, HAND_SIZE)
        return Vector2i(GRID_SIZE, GRID_SIZE)

    var rows: Array = pattern_of(index)
    var wide := 0
    for row: Array in rows:
        wide = maxi(wide, row.size())
    return Vector2i(wide, rows.size())


## 그것을 어디서 만드는가. **크기가 정한다.**
##
## 두 칸 안에 들어가면 손으로, 그보다 크면 작업대에서. 따로 적어 두지 않으므로
## 규칙이 하나뿐이고 외울 것이 없다.
static func station_of(index: int) -> int:
    var size := size_of(index)
    if size.x <= HAND_SIZE and size.y <= HAND_SIZE:
        return HAND
    return BENCH


## 그 법에 드는 재료. [[재료, 몇 개], ...]. 만들기 책에 적는 데 쓴다.
##
## 무늬에서 세어 만든다. 무늬와 따로 적어 두면 언젠가 둘이 어긋난다.
static func inputs_of(index: int) -> Array:
    var kinds := PackedInt32Array()
    var counts := PackedInt32Array()

    for kind in _cells_of(index):
        if kind == BlockType.EMPTY:
            continue
        var at := kinds.find(kind)
        if at < 0:
            kinds.append(kind)
            counts.append(1)
        else:
            counts[at] += 1

    var listed: Array = []
    for i in kinds.size():
        listed.append([kinds[i], counts[i]])
    return listed


## 무늬에 놓인 칸을 차례대로. 빈 칸도 그대로 들어간다.
static func _cells_of(index: int) -> PackedInt32Array:
    var cells := PackedInt32Array()
    if form_of(index) == SHAPELESS:
        for kind: int in pattern_of(index):
            cells.append(kind)
        return cells

    for row: Array in pattern_of(index):
        for kind: int in row:
            cells.append(kind)
    return cells


## 그것을 만드는 법의 번호. 만들 수 없는 것이면 -1.
static func index_for(block_type: int) -> int:
    for i in RECIPES.size():
        if int(RECIPES[i][0]) == block_type:
            return i
    return -1


static func can_be_made(block_type: int) -> bool:
    return index_for(block_type) >= 0 or smelt_index_for(block_type) >= 0


## --- 격자에 놓인 것을 읽는다 ---

## 격자에 놓인 것과 맞는 법. 없으면 -1.
##
## [param reach] 는 쓸 수 있는 한 변의 칸 수다. 손은 2, 작업대는 3.
## 그보다 큰 무늬는 애초에 맞지 않는다 — 그것이 작업대가 하는 일이다.
static func match_grid(grid: Inventory, reach: int) -> int:
    var placed := _read(grid, reach)
    for i in RECIPES.size():
        var size := size_of(i)
        if size.x > reach or size.y > reach:
            continue
        if _fits(placed, i):
            return i
    return -1


## 격자에서 쓸 수 있는 만큼만 읽어 온다. 손이 쓰는 것은 왼쪽 위 네 칸이다.
static func _read(grid: Inventory, reach: int) -> Array:
    var rows: Array = []
    for row in reach:
        var line := PackedInt32Array()
        for col in reach:
            line.append(grid.kind_at(row * GRID_SIZE + col))
        rows.append(line)
    return rows


## 놓인 것이 그 법과 맞는가.
static func _fits(placed: Array, index: int) -> bool:
    if form_of(index) == SHAPELESS:
        return _fits_loose(placed, index)
    var trimmed := _trim(placed)
    return _same(trimmed, _rows_of(index)) or _same(trimmed, _mirror(_rows_of(index)))


## 모양이 없는 법. 무엇을 몇 개 놓았는지만 본다.
static func _fits_loose(placed: Array, index: int) -> bool:
    var want := PackedInt32Array()
    for kind: int in pattern_of(index):
        want.append(kind)

    var got := PackedInt32Array()
    for line: PackedInt32Array in placed:
        for kind in line:
            if kind != BlockType.EMPTY:
                got.append(kind)

    if got.size() != want.size():
        return false
    # 놓인 것 하나하나를 원하는 목록에서 지워 나간다. 다 지워지면 맞다.
    var left := Array(want)
    for kind in got:
        var at := left.find(kind)
        if at < 0:
            return false
        left.remove_at(at)
    return left.is_empty()


## 법의 무늬를 줄의 배열로. 짧은 줄은 빈 칸으로 채워 네모지게 만든다.
static func _rows_of(index: int) -> Array:
    var size := size_of(index)
    var rows: Array = []
    for row: Array in pattern_of(index):
        var line := PackedInt32Array()
        for col in size.x:
            line.append(int(row[col]) if col < row.size() else BlockType.EMPTY)
        rows.append(line)
    return rows


## 빈 테두리를 걷어낸다. 격자 어디에 놓아도 같은 모양이면 같은 것이다.
static func _trim(rows: Array) -> Array:
    var top := -1
    var bottom := -1
    var left := -1
    var right := -1

    for r in rows.size():
        var line: PackedInt32Array = rows[r]
        for c in line.size():
            if line[c] == BlockType.EMPTY:
                continue
            if top < 0:
                top = r
            bottom = r
            left = c if left < 0 else mini(left, c)
            right = c if right < 0 else maxi(right, c)

    if top < 0:
        return []

    var cut: Array = []
    for r in range(top, bottom + 1):
        var line: PackedInt32Array = rows[r]
        var kept := PackedInt32Array()
        for c in range(left, right + 1):
            kept.append(line[c] if c < line.size() else BlockType.EMPTY)
        cut.append(kept)
    return cut


static func _same(left: Array, right: Array) -> bool:
    if left.size() != right.size():
        return false
    for r in left.size():
        var one: PackedInt32Array = left[r]
        var other: PackedInt32Array = right[r]
        if one.size() != other.size():
            return false
        for c in one.size():
            if one[c] != other[c]:
                return false
    return true


## 좌우를 뒤집은 무늬. 도끼는 오른손잡이도 왼손잡이도 도끼다.
static func _mirror(rows: Array) -> Array:
    var flipped: Array = []
    for line: PackedInt32Array in rows:
        var back := PackedInt32Array()
        for c in range(line.size() - 1, -1, -1):
            back.append(line[c])
        flipped.append(back)
    return flipped


## --- 만든다 ---

## 격자에 놓인 것으로 한 번 만든다. 놓인 것에서 칸마다 하나씩 준다.
##
## 만들 것을 받을 자리가 없으면 아무것도 쓰지 않는다.
static func take_once(grid: Inventory, inventory: Inventory, reach: int) -> bool:
    var index := match_grid(grid, reach)
    if index < 0:
        return false
    if not inventory.has_room_for(output_of(index)):
        return false

    _spend(grid, reach)
    inventory.add(output_of(index), yield_of(index))
    return true


## 격자에 놓인 것으로 만들 수 있는 만큼 만든다. 몇 번 만들었는지 돌려준다.
static func take_all(grid: Inventory, inventory: Inventory, reach: int) -> int:
    var made := 0
    while take_once(grid, inventory, reach):
        made += 1
    return made


## 놓인 칸마다 하나씩 덜어낸다.
static func _spend(grid: Inventory, reach: int) -> void:
    for row in reach:
        for col in reach:
            var slot := row * GRID_SIZE + col
            if grid.amount_at(slot) > 0:
                grid.take_from_slot(slot, 1)


## --- 굽는다 ---

static func smelt_count() -> int:
    return SMELTING.size()


static func smelt_output_of(index: int) -> int:
    if index < 0 or index >= SMELTING.size():
        return BlockType.EMPTY
    return int(SMELTING[index][0])


static func smelt_inputs_of(index: int) -> Array:
    if index < 0 or index >= SMELTING.size():
        return []
    return (SMELTING[index][2] as Array).duplicate(true)


static func smelt_index_for(block_type: int) -> int:
    for i in SMELTING.size():
        if int(SMELTING[i][0]) == block_type:
            return i
    return -1


## 손에 든 것으로 구울 수 있는 첫 법. 없으면 -1.
##
## **차례가 곧 우선순위다.** 적어 둔 차례가 고정이므로 언제 돌려도 같은 것이
## 나온다. 화로가 무엇을 구울지 여기서 정해진다.
static func first_smeltable(inventory: Inventory) -> int:
    for i in SMELTING.size():
        if has_smelt_materials(inventory, i) and inventory.has_room_for(smelt_output_of(i)):
            return i
    return -1


static func has_smelt_materials(inventory: Inventory, index: int) -> bool:
    if index < 0 or index >= SMELTING.size():
        return false
    for entry: Array in SMELTING[index][2] as Array:
        if inventory.count_of(int(entry[0])) < int(entry[1]):
            return false
    return true


## 굽는다. 재료가 하나라도 모자라면 **아무것도 쓰지 않고** 실패한다.
static func smelt(inventory: Inventory, index: int) -> bool:
    if not has_smelt_materials(inventory, index):
        return false
    if not inventory.has_room_for(smelt_output_of(index)):
        return false

    for entry: Array in SMELTING[index][2] as Array:
        inventory.take(int(entry[0]), int(entry[1]))
    inventory.add(smelt_output_of(index), int(SMELTING[index][1]))
    return true
