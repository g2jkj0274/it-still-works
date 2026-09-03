class_name BundlePartsCommand
extends SimCommand

## 놓여 있는 부품 여럿을 하나의 묶음으로 압축한다.
##
## 고른 칸의 부품과 그 사이의 배선이 통째로 설계도가 되어 손에 들어온다.
## 세상에서는 사라진다. 압축한 것을 다시 놓으면 한 칸짜리 부품이 된다.
##
## 고른 칸 밖으로 나가거나 밖에서 들어오던 배선은 함께 가지 않는다.
## 부품이 사라지면 그 배선도 사라지기 때문이다.
##
## 값이 드나드는 자리는 미리 정해 둔다. 정하지 않아도 묶을 수 있고, 그러면
## 스스로 도는 장치가 된다.

const TYPE := &"bundle_parts"

var cells: Array[Vector3i] = []
var inputs: Array[Vector3i] = []
var outputs: Array[Vector3i] = []


static func create(
    p_cells: Array[Vector3i],
    p_inputs: Array[Vector3i] = [] as Array[Vector3i],
    p_outputs: Array[Vector3i] = [] as Array[Vector3i],
) -> BundlePartsCommand:
    var command := BundlePartsCommand.new()
    command.cells = p_cells.duplicate()
    command.inputs = p_inputs.duplicate()
    command.outputs = p_outputs.duplicate()
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    var blueprint := BundleBlueprint.capture(state.circuit, cells, inputs, outputs)
    if blueprint == null:
        return

    var bundle_id := state.bundles.define(blueprint)
    if bundle_id < 0:
        return

    for cell in cells:
        state.circuit.remove_part(cell)
        state.grid.set_block(cell, BlockType.EMPTY)

    state.inventory.add_bundle(bundle_id, 1)


func write_payload(data: Dictionary) -> void:
    data["cells"] = _flatten(cells)
    data["in"] = _flatten(inputs)
    data["out"] = _flatten(outputs)


func read_payload(data: Dictionary) -> void:
    cells = _unflatten(data.get("cells", []))
    inputs = _unflatten(data.get("in", []))
    outputs = _unflatten(data.get("out", []))


static func _flatten(source: Array[Vector3i]) -> Array:
    var raw: Array = []
    for cell in source:
        raw.append_array([cell.x, cell.y, cell.z])
    return raw


static func _unflatten(raw: Variant) -> Array[Vector3i]:
    var values: Array = raw
    var restored: Array[Vector3i] = []
    var i := 0
    while i + 2 < values.size():
        restored.append(Vector3i(int(values[i]), int(values[i + 1]), int(values[i + 2])))
        i += 3
    return restored
