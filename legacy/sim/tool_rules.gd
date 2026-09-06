class_name ToolRules
extends RefCounted

## 손에 든 것이 무엇을 캘 수 있는지, 얼마나 빨리 캐는지.
##
## 전부 정수 판정이고 상태를 바꾸지 않는다. 스펙 §3.6 을 따른다.
##
## **맞는 도구가 없으면 부숴지지도 않는다.** 부숴는 지는데 아무것도 안 나오는
## 쪽은 "고장 났나"로 읽힌다. 손이 닿지 않는다는 것이 화면에 보여야 한다(§1).

## 등급. 숫자가 클수록 더 단단한 것을 캔다.
const HAND := 0
const WOOD := 1
const STONE := 2
const IRON := 3

## 도구가 없어도 캘 수 있는 것.
const SOFT := HAND

## 도구가 닳지는 않는다. 고르는 재미는 등급에서 나오지 관리에서 나오지 않는다.


## 손에 든 것의 등급. 도구가 아니면 맨손이다.
static func tier_of(tool: int) -> int:
    match tool:
        BlockType.WOOD_PICK:
            return WOOD
        BlockType.STONE_PICK:
            return STONE
        BlockType.IRON_PICK:
            return IRON
    return HAND


## 그것을 캐는 데 필요한 등급.
##
## 불씨돌이 나무 곡괭이인 까닭은 **첫 굴에 빛이 있어야 하기 때문**이다.
## 등은 광석이 들고 광석은 돌 곡괭이가 있어야 하는데, 파고 내려가기
## 시작하는 것은 나무 곡괭이일 때다.
static func needed_for(block_type: int) -> int:
    match BlockType.material_of(block_type):
        BlockType.ROCK, BlockType.EMBER:
            return WOOD
        BlockType.ORE:
            return STONE
    return SOFT


static func can_break(tool: int, block_type: int) -> bool:
    return tier_of(tool) >= needed_for(block_type)


## 한 번 캐는 데 걸리는 틱.
##
## 도끼는 나무를, 삽은 흙과 모래를 빠르게 한다. 곡괭이는 단단한 것을 빠르게
## 한다. 맞는 도구를 들면 절반이다 — 등급을 올릴 값이 여기서도 붙는다.
const DIG_TICKS := 5
const QUICK_TICKS := 3


static func dig_ticks(tool: int, block_type: int) -> int:
    return QUICK_TICKS if _suits(tool, block_type) else DIG_TICKS


## 그 도구가 그것에 알맞은가. 캘 수 있는가와는 다른 물음이다.
static func _suits(tool: int, block_type: int) -> bool:
    var material := BlockType.material_of(block_type)
    match tool:
        BlockType.STONE_AXE, BlockType.IRON_AXE:
            return material == BlockType.WOOD or material == BlockType.PLANK
        BlockType.STONE_SHOVEL:
            return material == BlockType.GROUND or material == BlockType.SAND
        BlockType.WOOD_PICK, BlockType.STONE_PICK, BlockType.IRON_PICK:
            return needed_for(material) > SOFT
    return false
