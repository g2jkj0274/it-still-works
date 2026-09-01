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
    BlockType.STONE: "돌",
    BlockType.WOOD: "나무",
    BlockType.DOOR_CLOSED: "문",
    BlockType.FIELD: "밭",
    BlockType.CROP: "작물",
    BlockType.DETECTOR: "감지기",
    BlockType.ACTUATOR: "작동기",
    BlockType.REPEATER: "되풀이",
    BlockType.BOX: "상자",
    BlockType.BRANCH: "갈림길",
}

const _DESCRIPTIONS: Dictionary[int, String] = {
    BlockType.GROUND: "땅을 메우고 길을 낸다",
    BlockType.STONE: "단단하게 쌓는다",
    BlockType.WOOD: "가볍게 쌓는다",
    BlockType.DOOR_CLOSED: "작동기를 옆에 붙이면 여닫힌다",
    BlockType.FIELD: "작물이 자란다. 옆에 붙인 작동기가 거둔다",
    BlockType.CROP: "먹으면 배가 찬다 (F)",
    BlockType.DETECTOR: "정한 것을 본다. 잇기(R)로 다른 부품에 연결",
    BlockType.ACTUATOR: "신호가 오면 맞닿은 문과 밭을 움직인다",
    BlockType.REPEATER: "받은 것을 정한 간격으로 되풀이해 보낸다",
    BlockType.BOX: "값 하나를 담아 둔다. 새로 넣으면 이전 것은 사라진다",
    BlockType.BRANCH: "조건에 맞으면 한쪽, 아니면 다른 쪽으로 보낸다",
}

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


static func branch_setting_name(preset: int) -> String:
    if preset < 0 or preset >= _BRANCH_SETTINGS.size():
        return "?"
    return _BRANCH_SETTINGS[preset]
