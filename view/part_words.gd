class_name PartWords
extends RefCounted

## 화면에 보일 부품 이름과 한 줄 설명.
##
## 전부 게임 말로만 적는다. 프로그래밍 용어는 화면에 나오지 않는다.
##
## 설명은 **무엇을 하는 물건인지와 어떻게 다루는지**만 적는다.
## 왜 안 되는지, 무엇이 잘못됐는지는 적지 않는다. 그건 만든 사람이 알아낼 몫이다.

const _NAMES: Dictionary[int, String] = {
    BlockType.GROUND: "흙",
    BlockType.ORE: "광석",
    BlockType.ROCK: "돌",
    BlockType.WOOD: "나무",
    BlockType.DOOR_CLOSED: "문",
    BlockType.FIELD: "밭",
    BlockType.CROP: "작물",
    BlockType.LAMP_DARK: "등",
    BlockType.LAMP_LIT: "등",
    BlockType.CHEST: "궤짝",
    BlockType.DETECTOR: "감지기",
    BlockType.ACTUATOR: "작동기",
    BlockType.REPEATER: "되풀이",
    BlockType.BOX: "상자",
    BlockType.BRANCH: "갈림길",
    BlockType.SAND: "모래",
    BlockType.EMBER: "불씨돌",
    BlockType.PLANK: "판자",
    BlockType.TORCH: "관솔불",
    BlockType.WOOD_PICK: "나무 곡괭이",
    BlockType.STONE_PICK: "돌 곡괭이",
    BlockType.STONE_AXE: "돌 도끼",
    BlockType.STONE_SHOVEL: "돌 삽",
}

const _DESCRIPTIONS: Dictionary[int, String] = {
    BlockType.GROUND: "땅을 메우고 길을 낸다",
    BlockType.ORE: "부품을 만드는 데 든다. 자원지와 땅속 깊은 곳에 있다",
    BlockType.ROCK: "땅속을 이루는 돌. 단단하게 쌓는다",
    BlockType.WOOD: "가볍게 쌓는다. 켜면 판자가 넷 나온다",
    BlockType.SAND: "물가에 깔린 모래",
    BlockType.EMBER: "불씨가 든 돌. 관솔불이 된다",
    BlockType.PLANK: "나무를 켠 것. 거의 모든 것에 든다",
    BlockType.TORCH: "놓으면 둘레를 밝힌다. 늘 켜져 있다",
    BlockType.WOOD_PICK: "돌과 불씨돌을 캔다",
    BlockType.STONE_PICK: "광석까지 캔다",
    BlockType.STONE_AXE: "나무를 빨리 벤다",
    BlockType.STONE_SHOVEL: "흙과 모래를 빨리 판다",
    BlockType.DOOR_CLOSED: "작동기를 옆에 붙이면 여닫힌다",
    BlockType.FIELD: "작물이 자란다. 옆에 붙인 작동기가 거둔다",
    BlockType.CROP: "먹으면 배가 찬다 (F). 땅에 난 것은 부숴서 얻는다",
    BlockType.LAMP_DARK: "작동기를 옆에 붙이면 켜진다. 땅속을 밝힌다",
    BlockType.LAMP_LIT: "작동기를 옆에 붙이면 켜진다. 땅속을 밝힌다",
    BlockType.CHEST: "물건을 넣어 둔다. 겨냥하고 E 로 연다",
    BlockType.DETECTOR: "정한 것을 본다. 잇기(R)로 다른 부품에 연결",
    BlockType.ACTUATOR: "신호가 오면 맞닿은 문과 밭을 움직인다",
    BlockType.REPEATER: "받은 것을 정한 간격으로 되풀이해 보낸다",
    BlockType.BOX: "값 하나를 담아 둔다. 새로 넣으면 이전 것은 사라진다",
    BlockType.BRANCH: "조건에 맞으면 한쪽, 아니면 다른 쪽으로 보낸다",
}

## 그것을 캐는 데 무엇이 드는가.
##
## **규칙을 여기에 옮겨 적지 않는다.** [ToolRules] 에 물어서 이름만 붙인다.
## 옮겨 적으면 도구 등급이 늘 때마다 두 곳을 고쳐야 하고, 언젠가 어긋난다.
##
## 이것은 오류 메시지가 아니라 **라벨**이다(§4.2). 왜 안 되는지가 아니라
## 무엇으로 하는지를 말한다. 처음 켠 사람은 "곡괭이"라는 말을 화면 어디서도
## 본 적이 없어서, 돌이 안 캐지는 것을 고장으로 읽었다.
static func gathering_of(block_type: int) -> String:
    match ToolRules.needed_for(block_type):
        ToolRules.WOOD:
            return "나무 곡괭이로 캔다"
        ToolRules.STONE:
            return "돌 곡괭이로 캔다"
    return "맨손으로 캔다"

const _TARGETS: Dictionary[int, String] = {
    DetectorPart.TARGET_PLAYER: "사람",
    DetectorPart.TARGET_THREAT: "밤에 오는 것",
    DetectorPart.TARGET_TIME: "밤",
    DetectorPart.TARGET_CROP: "다 자란 작물",
    DetectorPart.TARGET_ITEM: "손에 든 것",
}

const _SHAPES: Dictionary[int, String] = {
    BoxPart.SHAPE_SQUARE: "네모",
    BoxPart.SHAPE_ROUND: "둥근",
    BoxPart.SHAPE_SMALL: "작은",
}

const _REPEATER_SETTINGS: PackedStringArray = ["세 번", "열 번", "조건이 맞는 동안", "끝없이"]

const _BRANCH_SETTINGS: PackedStringArray = [
    "온 대로", "1 이상", "10 이상", "3 미만", "둘 다 오면", "하나라도 오면",
]

## 되풀이가 도는 방식을 말로.
const _REPEATER_MODES: Dictionary[int, String] = {
    RepeaterPart.MODE_WHILE: "조건이 맞는 동안",
    RepeaterPart.MODE_FOREVER: "끝없이",
}

## 갈림길이 무엇을 보는지 말로. 견줄 수가 있는 것은 따로 채운다.
const _BRANCH_MODES: Dictionary[int, String] = {
    BranchPart.MODE_TRUTH: "온 대로",
    BranchPart.MODE_AND: "둘 다 오면",
    BranchPart.MODE_OR: "하나라도 오면",
}


static func name_of(block_type: int) -> String:
    return _NAMES.get(block_type, "?")


static func description_of(block_type: int) -> String:
    return _DESCRIPTIONS.get(block_type, "")


static func target_name(target: int) -> String:
    return _TARGETS.get(target, "?")


static func shape_name(shape: int) -> String:
    return _SHAPES.get(shape, "?")


static func repeater_setting_name(preset: int) -> String:
    if preset < 0 or preset >= _REPEATER_SETTINGS.size():
        return "?"
    return _REPEATER_SETTINGS[preset]


## 그것을 만드는 데 드는 재료. 만들 수 없는 것이면 빈 글.
##
## 재료가 모자란지는 말하지 않는다. 손에 든 것은 핫바에 다 적혀 있다.
static func recipe_line(block_type: int) -> String:
    var index := RecipeBook.index_for(block_type)
    if index < 0:
        return ""

    var parts := PackedStringArray()
    for entry: Array in RecipeBook.inputs_of(index):
        parts.append("%s %d" % [name_of(int(entry[0])), int(entry[1])])
    return ", ".join(parts)


static func branch_setting_name(preset: int) -> String:
    if preset < 0 or preset >= _BRANCH_SETTINGS.size():
        return "?"
    return _BRANCH_SETTINGS[preset]


## 이미 놓인 부품이 무엇으로 맞춰져 있는지.
##
## 놓고 나면 알 길이 없었다. 설정이 다른 부품이 전부 똑같이 생겼기 때문이다.
## 이것은 오류를 말해 주는 것이 아니라 **눈에 안 보이는 사실을 읽어 주는 것**
## 이다. 왜 안 도는지는 여전히 말하지 않는다.
static func setting_of(part: CircuitPart) -> String:
    if part == null:
        return ""
    match part.kind():
        BlockType.DETECTOR:
            return target_name((part as DetectorPart).target)
        BlockType.BOX:
            return shape_name((part as BoxPart).shape)
        BlockType.REPEATER:
            var repeater := part as RepeaterPart
            if repeater.is_burnt():
                return "타 버렸다"
            return _REPEATER_MODES.get(repeater.mode, "%d번" % repeater.limit)
        BlockType.BRANCH:
            var branch := part as BranchPart
            if _BRANCH_MODES.has(branch.mode):
                return _BRANCH_MODES[branch.mode]
            if branch.mode == BranchPart.MODE_LESS:
                return "%d 미만" % branch.threshold
            if branch.mode == BranchPart.MODE_EQUAL:
                return "%d 일 때" % branch.threshold
            return "%d 이상" % branch.threshold
        _:
            return ""
