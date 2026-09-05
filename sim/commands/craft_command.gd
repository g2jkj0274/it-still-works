class_name CraftCommand
extends SimCommand

## 재료로 무언가를 만든다.
##
## 만드는 법은 [RecipeBook] 이 들고 있다. 명령은 무엇을 만들지만 지목한다.
## 법 번호가 아니라 만들 것의 종류를 담는다. 번호는 법을 고칠 때 밀려나지만
## 종류는 밀려나지 않는다. 저장해 둔 명령이 나중에 다른 것을 만들면 안 된다.
##
## 재료가 모자라면 아무 일도 일어나지 않는다. 왜 안 되는지는 말하지 않는다.
## 손에 든 것은 핫바에 다 적혀 있다.

const TYPE := &"craft"

var output: int = BlockType.EMPTY


static func create(p_output: int) -> CraftCommand:
    var command := CraftCommand.new()
    command.output = p_output
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    var index := RecipeBook.index_for(output)
    if not _can_reach_the_place(state, index):
        return
    RecipeBook.make(state.inventory, index)


## 그것을 만들 자리에 서 있는가.
##
## **어디서 만들 수 있는가가 곧 테크트리의 마디다**(스펙 §3.6).
## 화로에서 굽는 것은 손으로 만들지 못한다 — 작동기가 때려야 돈다.
## 작업대에서 만드는 것은 작업대 곁에 서야 한다.
##
## 왜 안 되는지는 말하지 않는다. 세상이 그대로면 화면이 알아서 알린다(§1).
func _can_reach_the_place(state: WorldState, index: int) -> bool:
    match RecipeBook.station_of(index):
        RecipeBook.HAND:
            return true
        RecipeBook.BENCH:
            return _stands_by(state, BlockType.BENCH)
    return false


## 그 블록이 손 닿는 거리에 있는가.
static func _stands_by(state: WorldState, block_type: int) -> bool:
    var here := state.character.cell()
    var reach := RecipeBook.BENCH_REACH
    for dz in range(-1, 2):
        for dy in range(-reach, reach + 1):
            for dx in range(-reach, reach + 1):
                if state.grid.get_block(here + Vector3i(dx, dy, dz)) == block_type:
                    return true
    return false


func write_payload(data: Dictionary) -> void:
    data["out"] = output


func read_payload(data: Dictionary) -> void:
    output = int(data.get("out", BlockType.EMPTY))
