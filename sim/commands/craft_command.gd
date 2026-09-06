class_name CraftCommand
extends SimCommand

## 제작 격자에 놓인 것을 가져간다.
##
## **무엇을 만들지 지목하지 않는다.** 놓인 모양이 곧 무엇을 만들지를 정한다
## (스펙 §3.6). 예전에는 목록에서 고른 번호를 명령이 들고 다녔는데, 그러면
## 만드는 일이 "스물넉 줄에서 하나 찾기"가 되어 제작법이 늘수록 나빠졌다.
##
## [member all] 이면 놓인 재료가 다할 때까지 만든다. 마인크래프트의 시프트
## 누르고 가져가기다. 판자 스무 장을 스무 번 눌러 만들던 것이 한 번이 된다.
##
## **닿는 넓이는 세상이 정한다.** 작업대 곁에 서 있으면 세 칸, 아니면 두 칸이다.
## 화면이 정하게 두면 화면을 속여 세 칸짜리를 손으로 만들 수 있다.
##
## 재료가 모양에 맞지 않으면 아무 일도 일어나지 않는다. 왜 안 되는지는 말하지
## 않는다(§1). 놓인 것은 격자에 그대로 보인다.

const TYPE := &"craft"

## 만들 수 있는 만큼 다 만드는가.
var all: bool = false


static func create(p_all: bool = false) -> CraftCommand:
    var command := CraftCommand.new()
    command.all = p_all
    return command


## 놓인 재료가 다할 때까지 만든다.
static func every() -> CraftCommand:
    return create(true)


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    var reach := reach_of(state)
    if all:
        RecipeBook.take_all(state.craft, state.inventory, reach)
    else:
        RecipeBook.take_once(state.craft, state.inventory, reach)


## 지금 쓸 수 있는 격자 한 변의 칸 수.
##
## **어디서 만들 수 있는가가 곧 테크트리의 마디다**(스펙 §3.6). 작업대가
## 곁에 있으면 세 칸이 열린다. 그것이 작업대가 하는 일의 전부다.
static func reach_of(state: WorldState) -> int:
    if stands_by(state, BlockType.BENCH):
        return RecipeBook.GRID_SIZE
    return RecipeBook.HAND_SIZE


## 그 블록이 손 닿는 거리에 있는가.
static func stands_by(state: WorldState, block_type: int) -> bool:
    var here := state.character.cell()
    var reach := RecipeBook.BENCH_REACH
    for dz in range(-1, 2):
        for dy in range(-reach, reach + 1):
            for dx in range(-reach, reach + 1):
                if state.grid.get_block(here + Vector3i(dx, dy, dz)) == block_type:
                    return true
    return false


func write_payload(data: Dictionary) -> void:
    data["all"] = all


func read_payload(data: Dictionary) -> void:
    all = bool(data.get("all", false))
