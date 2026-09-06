class_name ClearCraftCommand
extends SimCommand

## 제작 격자에 놓아 둔 것을 손으로 돌려받는다.
##
## **놓아 둔 채로 화면을 닫으면 물건이 사라진 것처럼 보인다.** 격자는 상태라
## 실제로 사라지지는 않지만, 화면을 닫은 사람에게는 광석 셋이 없어진 것이다.
## 마인크래프트도 창을 닫으면 놓아 둔 것을 돌려준다.
##
## 손이 모자라면 들어가는 만큼만 돌려받고 나머지는 격자에 남는다. 없애지
## 않는다 — 없애면 손이 찼을 때 재료가 조용히 사라진다.

const TYPE := &"clear_craft"


static func create() -> ClearCraftCommand:
    return ClearCraftCommand.new()


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    for slot in state.craft.slot_count():
        var amount := state.craft.amount_at(slot)
        if amount <= 0:
            continue

        var kind := state.craft.kind_at(slot)
        var variant := state.craft.variant_at(slot)
        var left := state.inventory.add(kind, amount, variant)
        if left >= amount:
            continue
        state.craft.take_from_slot(slot, amount - left)


func write_payload(_data: Dictionary) -> void:
    pass


func read_payload(_data: Dictionary) -> void:
    pass
