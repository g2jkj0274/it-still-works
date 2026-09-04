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
    RecipeBook.make(state.inventory, RecipeBook.index_for(output))


func write_payload(data: Dictionary) -> void:
    data["out"] = output


func read_payload(data: Dictionary) -> void:
    output = int(data.get("out", BlockType.EMPTY))
