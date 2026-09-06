class_name CropField
extends RefCounted

## 밭에 심긴 작물들.
##
## 밭 블록이 놓이면 심기고 부수면 사라진다. 시간이 지나면 자라고, 다 자라면
## 거둘 수 있다. 거두고 나면 다시 처음부터 자란다.
##
## 밭은 항상 자리 순으로 늘어놓는다. 순회 순서가 흔들리면 자라는 차례가 달라진다.

## 다 자라기까지 걸리는 틱. 낮 한나절쯤.
const MATURE_TICKS := 90 * Simulation.TICK_RATE

## 한 번 거둘 때 얻는 작물 수.
const YIELD := 2

## 각 항목은 [칸, 자란 정도] 이다.
var _plots: Array = []


func count() -> int:
    return _plots.size()


func cells() -> Array[Vector3i]:
    var found: Array[Vector3i] = []
    for plot: Array in _plots:
        found.append(plot[0])
    return found


func has_field(cell: Vector3i) -> bool:
    return _index_of(cell) >= 0


func growth_of(cell: Vector3i) -> int:
    var index := _index_of(cell)
    if index < 0:
        return 0
    return _plots[index][1]


func is_mature(cell: Vector3i) -> bool:
    return growth_of(cell) >= MATURE_TICKS


func plant(cell: Vector3i) -> bool:
    if has_field(cell):
        return false
    _plots.append([cell, 0])
    _plots.sort_custom(_plot_before)
    return true


func uproot(cell: Vector3i) -> bool:
    var index := _index_of(cell)
    if index < 0:
        return false
    _plots.remove_at(index)
    return true


## 다 자란 밭을 거둔다. 아직이면 아무 일도 없다.
func harvest(cell: Vector3i) -> bool:
    if not is_mature(cell):
        return false
    _plots[_index_of(cell)][1] = 0
    return true


## 한 틱 자란다.
func advance() -> void:
    for plot: Array in _plots:
        if plot[1] < MATURE_TICKS:
            plot[1] += 1


func to_hash_fields() -> Array:
    var fields: Array = [["crops.count", _plots.size()]]
    for plot: Array in _plots:
        var cell: Vector3i = plot[0]
        fields.append(["crop.%d.%d.%d" % [cell.x, cell.y, cell.z], plot[1]])
    return fields


func _index_of(cell: Vector3i) -> int:
    for i in _plots.size():
        if _plots[i][0] == cell:
            return i
    return -1


func _plot_before(left: Array, right: Array) -> bool:
    var a: Vector3i = left[0]
    var b: Vector3i = right[0]
    if a.x != b.x:
        return a.x < b.x
    if a.y != b.y:
        return a.y < b.y
    return a.z < b.z
